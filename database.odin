package one_ecs

import "core:testing"
import "base:runtime"
import core "core"

////////////////// DEFINITIONS


Entity_Id :: core.Entity_Id
INVALID_ENTITY_IDX :: core.INVALID_IDX

COMPONENT_SIGNATURES_MAX :: #config(COMPONENT_SIGNATURES_MAX, 32)

Component_Signature :: bit_set[0..<COMPONENT_SIGNATURES_MAX; u64]

DEFAULT_MAX_ENTITIES :: 1024

// Stores entities and attached tables. It is main data storage of OneECS
Database :: struct {
    allocator: runtime.Allocator,
    
    max_entities: int,
    entity_factory: core.Entity_Factory,
    
    signatures: [/*Entity ID*/]Component_Signature,

    table_capacity: int,
    attached_tables_count: int,
    typeid_to_tid: map[typeid]int,
    tid_to_table: [COMPONENT_SIGNATURES_MAX]Basic_Table,

    queried_entities: []Entity_Id,
}

// Initializes database with given allocator
database_init :: proc (self: ^Database, allocator: runtime.Allocator, table_capacity:=DEFAULT_MAX_ENTITIES, max_entities:=DEFAULT_MAX_ENTITIES, loc:=#caller_location) -> Error {

    self.allocator = allocator
    self.max_entities = max_entities
    self.table_capacity = table_capacity

    core.entity_factory_init(&self.entity_factory, max_entities, allocator, loc) or_return

    self.signatures = make([]Component_Signature, max_entities, allocator, loc) or_return
    self.typeid_to_tid = make(map[typeid]int, COMPONENT_SIGNATURES_MAX, allocator, loc) or_return

    self.queried_entities = make([]Entity_Id, max_entities, allocator, loc) or_return

    return ERROR_NONE
}

////////////////// REGISTRY


// Allocates new table and registers it under the given type. Can fail if given type is already registered
database_register_component :: proc (self: ^Database, type_id: typeid, loc:=#caller_location) -> Error {
    if type_id in self.typeid_to_tid do return Registry_Error.Already_Registered
    if self.attached_tables_count >= len(self.tid_to_table) do return Collection_Error.Exceeded_Capacity

    basic_table := Basic_Table{variant=Table{}}
    table := &basic_table.variant.(Table)
    table_init(table, self, self.table_capacity, type_id, loc) or_return

    basic_table.type_info = table.type_info

    // attach the table
    tid := self.attached_tables_count
    table.t_id = tid

    self.tid_to_table[tid] = basic_table
    self.typeid_to_tid[table.type_info.id] = tid
    self.attached_tables_count += 1

    return ERROR_NONE
}

// Allocates new tag table, that only stores boolean if entity has component or not,
// and registers it under the given type. Can fail if given type is already registered
database_register_tag_component :: proc (self: ^Database, type_id: typeid, loc:=#caller_location) -> Error {
    if type_id in self.typeid_to_tid do return Registry_Error.Already_Registered
    if self.attached_tables_count >= len(self.tid_to_table) do return Collection_Error.Exceeded_Capacity

    basic_table := Basic_Table{variant=Tag_Table{}}
    tag_table := &basic_table.variant.(Tag_Table)
    tag_table_init(tag_table, self, type_id, loc) or_return

    basic_table.type_info = tag_table.type_info

    tid := self.attached_tables_count
    tag_table.t_id = tid

    self.tid_to_table[tid] = basic_table
    self.typeid_to_tid[tag_table.type_info.id] = tid
    self.attached_tables_count += 1

    return ERROR_NONE
}

// Checks size of given typeid,
// and if it's 0 then type is registered as tag component.
// Otherwise it is registered as regular component
database_register :: proc (self: ^Database, type_id: typeid, loc:=#caller_location) -> Error {
    type_info := type_info_of(type_id)
    if type_info.size == 0 do return database_register_tag_component(self, type_id, loc)
    else do return database_register_component(self, type_id, loc)
}

////////////////// ENTITY OPERATIONS


// Creates new entity id. Can fail if there's an internal error
database_create_entity :: #force_inline proc (self: ^Database) -> (ent: Entity_Id, err: Error) {
    return core.entity_factory_create_id(&self.entity_factory) 
}

// Destroys entity id, and clears it's components and signature. Can fail if there's an internal error
database_destroy_entity :: #force_inline proc (self: ^Database, ent: Entity_Id) -> Error {
    signature := self.signatures[ent.idx]
    for bit in signature {
        table := self.tid_to_table[bit]
        basic_table_remove(&table, ent)
    }

    err := core.entity_factory_free_id(&self.entity_factory, ent)
    if err != core.ERROR_NONE do return err

    self.signatures[ent.idx] = nil

    return ERROR_NONE
}

// Returns if given entity id is in database's bounds, not freed, and not expired.
database_entity_is_valid :: #force_inline proc (self: ^Database, ent: Entity_Id) -> bool {
    return (ent.idx >= 0 && ent.idx < self.max_entities) \ 
        && !core.entity_factory_is_freed(&self.entity_factory, ent) \
        && !core.entity_factory_is_expired(&self.entity_factory, ent)
}

////////////////// SIGNATURE OPERATIONS


// Returns signature of entity. Can fail if entity is invalid
database_get_signature :: #force_inline proc (self: ^Database, ent: Entity_Id) -> (Component_Signature, Error) {
    if !database_entity_is_valid(self, ent) do return nil, Collection_Error.Invalid_Entity

    return self.signatures[ent.idx], ERROR_NONE
}

// Constructs signature from given type ids. This function asserts that typeid is registered
database_make_signature :: #force_inline proc (self: ^Database, types: ..typeid) -> Component_Signature {
    sign: Component_Signature
    for t in types {
        assert(t in self.typeid_to_tid) // sanity check
        sign += {self.typeid_to_tid[t]}
    }
    return sign
}

@private
database_signature_add_component :: proc (self: ^Database, ent: Entity_Id, type_id: int) -> Error {
    if !database_entity_is_valid(self, ent) do return Collection_Error.Invalid_Entity

    self.signatures[ent.idx] += {type_id}

    return ERROR_NONE
}

@private
database_signature_remove_component :: proc (self: ^Database, ent: Entity_Id, type_id: int) -> Error {
    if !database_entity_is_valid(self, ent) do return Collection_Error.Invalid_Entity

    self.signatures[ent.idx] -= {type_id}

    return ERROR_NONE
}

@private
database_signature_clear :: proc (self: ^Database, ent: Entity_Id) -> Error {
    if !database_entity_is_valid(self, ent) do return Collection_Error.Invalid_Entity

    self.signatures[ent.idx] = nil

    return ERROR_NONE
}

////////////////// COMPONENT OPERATIONS


// Adds component to given entity. Can fail if entity is invalid or given type is not registered
database_add_component :: proc (self: ^Database, entity: Entity_Id, $T: typeid) -> (^T, Error) {
    if !database_entity_is_valid(self, entity) do return nil, Collection_Error.Invalid_Entity
    if T not_in self.typeid_to_tid do return nil, Registry_Error.Not_Registered

    basic_table := &self.tid_to_table[self.typeid_to_tid[T]]

    component, err := basic_table_add(basic_table, entity)
    if err != ERROR_NONE do return nil, err

    return cast(^T)component, ERROR_NONE
}

// Removes component from given entity. Can fail if entity is invalid or given type is not registered
database_remove_component :: proc (self: ^Database, entity: Entity_Id, T: typeid) -> Error {
    if !database_entity_is_valid(self, entity) do return Collection_Error.Invalid_Entity
    if T not_in self.typeid_to_tid do return Registry_Error.Not_Registered

    basic_table := &self.tid_to_table[self.typeid_to_tid[T]]

    return basic_table_remove(basic_table, entity)
}

// Returns component of given entity. Can fail if entity is invalid or given type is not registered
database_get_component :: proc (self: ^Database, entity: Entity_Id, $T: typeid) -> (^T, Error) {
    if !database_entity_is_valid(self, entity) do return nil, Collection_Error.Invalid_Entity
    if T not_in self.typeid_to_tid do return nil, Registry_Error.Not_Registered

    basic_table := &self.tid_to_table[self.typeid_to_tid[T]]

    component, err := basic_table_get(basic_table, entity)
    if err != ERROR_NONE do return nil, err

    return cast(^T)component, ERROR_NONE
}

database_has_component :: proc (self: ^Database, entity: Entity_Id, T: typeid) -> bool {
    if !database_entity_is_valid(self, entity) do return false
    if T not_in self.typeid_to_tid do return false

    basic_table := &self.tid_to_table[self.typeid_to_tid[T]]

    return basic_table_has(basic_table, entity)
}

////////////////// QUERYING


database_query :: proc (self: ^Database, include: Component_Signature, exclude:=[]typeid{}) -> []Entity_Id {

    entities_n := 0
    for ent in self.entity_factory.alive_ids {
        if !database_entity_is_valid(self, ent) do continue

        sign := self.signatures[ent.idx]
        if sign >= include {
            skip := false
            for t in exclude {
                assert(t in self.typeid_to_tid) // sanity check
                tid := self.typeid_to_tid[t]
                if tid in sign {
                    skip = true
                    break
                }
            }
            if skip do continue

            self.queried_entities[entities_n] = ent     
            entities_n += 1
        }
    }

    queried := self.queried_entities
    queried_raw := (^runtime.Raw_Slice)(&queried)
    queried_raw.len = entities_n

    return queried
}

////////////////// DATABASE FREEING


// Frees database and it's attached tables
database_free :: proc (self: ^Database, loc:=#caller_location) -> Error {
    for i in 0..<self.attached_tables_count {
        table := self.tid_to_table[i]
        basic_table_free(&table, loc) or_return
    }

    core.entity_factory_free(&self.entity_factory, loc) or_return
    
    delete(self.signatures, self.allocator, loc) or_return
    delete(self.typeid_to_tid, loc) or_return
    delete(self.queried_entities, self.allocator, loc) or_return

    return ERROR_NONE
}

////////////////// TESTS


@test
database_test :: proc (_: ^testing.T) {
    err: Error

    // init database
    db: Database
    err = database_init(&db, context.allocator)
    assert(err == ERROR_NONE, error_to_str(err))
    defer assert(database_free(&db) == ERROR_NONE, error_to_str(err))

    // create entity
    entity: Entity_Id

    entity, err = database_create_entity(&db)
    assert(err == ERROR_NONE, error_to_str(err))
    assert(entity.idx == 0 && entity.gen == 0)
    
    // register two component types
    Some_Type :: struct { num: int }
    Some_Other_Type :: struct { str: string }

    // --   first
    err = database_register_component(&db, Some_Type)
    assert(err == ERROR_NONE, error_to_str(err))

    assert(db.typeid_to_tid[Some_Type] == 0, "Typeid 'Some_Type' points to wrong table id")

    // --   second
    err = database_register_component(&db, Some_Other_Type)
    assert(err == ERROR_NONE, error_to_str(err))

    assert(db.typeid_to_tid[Some_Other_Type] == 1, "Typeid 'Some_Other_Type' points to wrong table id")

    // add first component to the entity
    some_data: ^Some_Type
    some_data, err = database_add_component(&db, entity, Some_Type)
    assert(err == ERROR_NONE, error_to_str(err))

    some_data.num = 120

    // add second component to the entity
    some_other_data: ^Some_Other_Type
    some_other_data, err = database_add_component(&db, entity, Some_Other_Type)
    assert(err == ERROR_NONE, error_to_str(err))

    some_other_data.str = "hello world"

    // check validity of signature
    sign: Component_Signature
    sign, err = database_get_signature(&db, entity)
    assert(err == ERROR_NONE, error_to_str(err))
    assert(sign == {0, 1}) // it should contain two components, with IDs 0 and 1

    // destroy entity
    err = database_destroy_entity(&db, entity)
    assert(err == ERROR_NONE, error_to_str(err))

    // check that destroyed entity's data became invalid 
    assert(db.signatures[entity.idx] == nil)
    assert(some_data^ == Some_Type{})
    assert(some_other_data^ == Some_Other_Type{})

    // test database limits
    for i in 0..<db.max_entities {
        database_create_entity(&db)
    }

    // try creating id, when there are max entities used
    invalid_entity: Entity_Id
    invalid_entity, err = database_create_entity(&db)
    assert(err != ERROR_NONE, "No error after exceeding entity capacity")

    db.entity_factory.alive_ids[0].gen = 0 // for testing purposes, do not do that in production code
    for i in 0..<db.max_entities {
        database_destroy_entity(&db, Entity_Id{idx=i})
    }

    // try creating id (which should be reused)
    entity, err = database_create_entity(&db)
    assert(err == ERROR_NONE, error_to_str(err))
    assert(entity.gen == 1, "Entity generation is not equal to 1, even if it was reused.")

    // test querying
    for i in 1..=10 {
        entity, err = database_create_entity(&db)
        assert(err == ERROR_NONE, error_to_str(err))

        some_data, err = database_add_component(&db, entity, Some_Type)
        assert(err == ERROR_NONE, error_to_str(err))

        some_data.num = entity.idx
        if i % 3 == 0 { // add Some_Other_Type to only some entities
            some_other_data, err = database_add_component(&db, entity, Some_Other_Type)
            assert(err == ERROR_NONE, error_to_str(err))
            some_other_data.str = "this entity is divisible by 3"
        }
    }

    entities := database_query(&db, database_make_signature(&db, Some_Type), exclude={Some_Other_Type})
    assert(len(entities) == 7)
    for entity in entities {
        some_data, err = database_get_component(&db, entity, Some_Type)
        assert(err == ERROR_NONE, error_to_str(err))
        assert(some_data.num == entity.idx)
    }

    entities = database_query(&db, database_make_signature(&db, Some_Other_Type))
    for entity in entities {
        some_other_data, err = database_get_component(&db, entity, Some_Other_Type)
        assert(err == ERROR_NONE, error_to_str(err))
        assert(some_other_data.str == "this entity is divisible by 3")
    }
}
