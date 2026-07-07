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
    tid_to_table: [COMPONENT_SIGNATURES_MAX]^Basic_Table,
}

// Initializes database with given allocator
database_init :: proc (self: ^Database, allocator: runtime.Allocator, table_capacity:=DEFAULT_MAX_ENTITIES, max_entities:=DEFAULT_MAX_ENTITIES, loc:=#caller_location) -> Error {

    self.allocator = allocator
    self.max_entities = max_entities
    self.table_capacity = table_capacity

    core.entity_factory_init(&self.entity_factory, max_entities, allocator, loc) or_return

    self.signatures = make([]Component_Signature, max_entities, allocator, loc) or_return
    self.typeid_to_tid = make(map[typeid]int, COMPONENT_SIGNATURES_MAX, allocator, loc) or_return

    return ERROR_NONE
}

////////////////// REGISTRY


// Attaches table to database, this function is called
// from tables themselves after they are initialized
@private
database_attach_table :: proc (self: ^Database, table: ^Basic_Table) -> (int, Error) {
    if self.attached_tables_count >= len(self.tid_to_table) do return 0, Collection_Error.Exceeded_Capacity

    tid := self.attached_tables_count
    self.tid_to_table[tid] = table
    self.typeid_to_tid[table.type_info.id] = tid
    self.attached_tables_count += 1

    return tid, ERROR_NONE
}

// Allocates new table and registers it under the given type. Can fail if given type is already registered
database_register_component :: proc (self: ^Database, type_id: typeid, loc:=#caller_location) -> Error {
    if type_id in self.typeid_to_tid do return Registry_Error.Already_Registered

    table: ^Table = new(Table, self.allocator, loc) or_return
    // automatically attached
    table_init(table, self, self.table_capacity, type_id, loc) or_return

    return ERROR_NONE
}

// Allocates new tag table, that only stores boolean if entity has component or not,
// and registers it under the given type. Can fail if given type is already registered
database_register_tag :: proc (self: ^Database, type_id: typeid, loc:=#caller_location) -> Error {
    unimplemented("Tag table are not implemented yet")
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
        basic_table_remove(table, ent)
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

    table := self.tid_to_table[self.typeid_to_tid[T]]
    assert(table != nil) // sanity check
    
    component, err := basic_table_add(table, entity)
    if err != ERROR_NONE do return nil, err

    return cast(^T)component, ERROR_NONE
}

// Removes component from given entity. Can fail if entity is invalid or given type is not registered
database_remove_component :: proc (self: ^Database, entity: Entity_Id, T: typeid) -> Error {
    if !database_entity_is_valid(self, entity) do return Collection_Error.Invalid_Entity
    if T not_in self.typeid_to_tid do return Registry_Error.Not_Registered

    table := self.tid_to_table[self.typeid_to_tid[T]]
    assert(table != nil) // sanity check
    return basic_table_remove(table, entity)
}

// Returns component of given entity. Can fail if entity is invalid or given type is not registered
database_get_component :: proc (self: ^Database, entity: Entity_Id, $T: typeid) -> (rawptr, Error) {
    if !database_entity_is_valid(self, entity) do return nil, Collection_Error.Invalid_Entity
    if T not_in self.typeid_to_tid do return nil, Registry_Error.Not_Registered

    table := self.tid_to_table[self.typeid_to_tid[T]]
    assert(table != nil) // sanity check

    component, err := basic_table_get(table, entity)
    if err != ERROR_NONE do return nil, err

    return cast(^T)component, ERROR_NONE
}

////////////////// DATABASE FREEING


// Frees database and it's attached tables
database_free :: proc (self: ^Database, loc:=#caller_location) -> Error {
    for i in 0..<self.attached_tables_count {
        table := self.tid_to_table[i]
        assert(table != nil) // sanity check
        basic_table_free(table, loc) or_return
        free(table, self.allocator, loc) or_return
    }

    core.entity_factory_free(&self.entity_factory, loc) or_return
    
    delete(self.signatures, self.allocator, loc) or_return
    delete(self.typeid_to_tid, loc) or_return

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

    assert(db.tid_to_table[0] != nil, "Registered table shows as nil in array")
    assert(db.typeid_to_tid[Some_Type] == 0, "Typeid 'Some_Type' points to wrong table id")

    // --   second
    err = database_register_component(&db, Some_Other_Type)
    assert(err == ERROR_NONE, error_to_str(err))

    assert(db.tid_to_table[1] != nil, "Second registered table shows as nil in array")
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
}
