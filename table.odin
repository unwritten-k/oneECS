package one_ecs

import "core:testing"
import "core:mem"
import "base:runtime"
import core "core"

@(private="file")
INVALID_ID :: -1

@private
Table_Base :: struct {
    using basic: Basic_Table,

    capacity: int,
    entity_to_id: [/*Entity*/]int,
    components_count: int,

    type_info: ^runtime.Type_Info,

    t_id: int,
}

@private
table_base_init :: proc (self: ^Table_Base, db: ^Database, capacity: int, loc:=#caller_location) -> Error {
    self.db = db
    self.capacity = capacity

    self.components_count = 0

    self.entity_to_id = make([]int, db.max_entities, db.allocator, loc) or_return

    for &id in self.entity_to_id {
        id = INVALID_ID
    }

    return ERROR_NONE
}

@private
table_base_has_entity :: proc (self: ^Table_Base, ent: Entity_Id) -> bool {
    return self.entity_to_id[ent.idx] != INVALID_ID
}

@private
table_base_free :: proc (self: ^Table_Base, loc:=#caller_location) -> Error {
    delete(self.entity_to_id, self.db.allocator, loc) or_return

    self.capacity = 0

    return ERROR_NONE
}


Table_Bytes :: struct {
    using base: Table_Base,
    bytes: []byte,
}

@private
table_bytes_init :: proc (self: ^Table_Bytes, db: ^Database, capacity: int, type_info: ^runtime.Type_Info, loc:=#caller_location) -> Error {
    table_base_init(&self.base, db, capacity, loc) or_return
    
    self.bytes = make([]byte, capacity*type_info.size, db.allocator, loc) or_return
    raw_bytes := (^runtime.Raw_Slice)(&self.bytes)
    raw_bytes.len = capacity

    self.type_info = type_info

    t_id := database_register_type(db, type_info.id) or_return
    self.t_id = t_id

    return ERROR_NONE
}

@private
table_bytes_remove_component :: proc (self: ^Table_Bytes, ent: Entity_Id) -> Error {
    if !database_entity_is_valid(self.db, ent) do return Collection_Error.Invalid_Entity
    if !table_base_has_entity(&self.base, ent) do return Collection_Error.Entity_Not_Found

    database_signature_remove_component(self.db, ent, self.t_id) or_return

    id := self.entity_to_id[ent.idx]
    self.entity_to_id[ent.idx] = INVALID_ID

    bytes_start := id
    bytes_end := id + self.type_info.size
    #no_bounds_check {
        slice := self.bytes[bytes_start:bytes_end]
        mem.zero(raw_data( slice ), self.type_info.size)
    }

    return ERROR_NONE
}

table_bytes_clear :: proc (self: ^Table_Bytes) {
    for &id in self.entity_to_id {
        id = INVALID_ID
    }

    self.components_count = 0
    raw := (^runtime.Raw_Slice)(&self.bytes)
    mem.zero(raw.data, raw.len)
}

@private
table_bytes_free :: proc (self: ^Table_Bytes, loc:=#caller_location) -> Error {
    table_base_free(&self.base, loc) or_return

    mem.free_with_size(raw_data(self.bytes), self.capacity*self.type_info.size, self.db.allocator, loc) or_return

    return ERROR_NONE
}


Table :: struct ($T: typeid) {
    using base: Table_Base,
    components: []T
}

table_init :: proc (self: ^Table($T), db: ^Database, capacity: int, loc:=#caller_location) -> Error {
    table_base_init(&self.base, db, capacity, loc) or_return
    self.type_info = type_info_of(T)

    self.components = make([]T, capacity, db.allocator, loc) or_return

    t_id := database_register_type(db, T) or_return
    self.t_id = t_id

    return ERROR_NONE
}

table_add_component :: proc (self: ^Table($T), ent: Entity_Id) -> (^T, Error) {
    if !database_entity_is_valid(self.db, ent) do return nil, Collection_Error.Invalid_Entity
    if table_base_has_entity(&self.base, ent) do return nil, Collection_Error.Already_Added

    id := self.components_count
    self.entity_to_id[ent.idx] = id

    component := &self.components[id]
    self.components_count += 1

    err := database_signature_add_component(self.db, ent, self.t_id)
    if err != ERROR_NONE {
        // revert changes in case of error
        self.entity_to_id[ent.idx] = INVALID_ID
        self.components_count -= 1
        return nil, err
    }

    return component, ERROR_NONE
}

table_get_component :: proc (self: ^Table($T), ent: Entity_Id) -> (^T, Error) {
    if !database_entity_is_valid(self.db, ent) do return nil, Collection_Error.Invalid_Entity
    if !table_base_has_entity(&self.base, ent) do return nil, Collection_Error.Entity_Not_Found

    id := self.entity_to_id[ent.idx]
    
    return &self.components[id], ERROR_NONE
}

table_remove_component :: proc (self: ^Table($T), ent: Entity_Id) -> Error {
    return table_bytes_remove_component( (^Table_Bytes)(self), ent )
}

table_clear :: proc (self: ^Table($T)) {
    table_bytes_clear( (^Table_Bytes)(self) )
}

// When table is attached to database, there's no need
// for freeing it manually, since database will do it automatically
table_free :: proc (self: ^Table($T), loc:=#caller_location) -> Error {
    table_base_free(&self.base, loc)

    delete(self.components, self.db.allocator, loc) or_return
    
    return ERROR_NONE
}

@test
table_test :: proc (_: ^testing.T) {
    
    db: Database
    database_init(&db, context.allocator)
    defer database_free(&db)

    err: Error

    table: Table(int)
    err = table_init(&table, &db, 32)
    assert(err == ERROR_NONE, error_to_str(err))
    defer assert( table_free(&table) == ERROR_NONE )

    context.allocator = runtime.panic_allocator()

    entity, _ := database_create_entity(&db)

    component: ^int
    component, err = table_add_component(&table, entity)
    assert(err == ERROR_NONE, error_to_str(err))

    component^ = 15

    component, err = table_get_component(&table, entity)
    assert(err == ERROR_NONE, error_to_str(err))
    assert(component^ == 15)

    err = table_remove_component(&table, entity)
    assert(err == ERROR_NONE, error_to_str(err))
    assert(component^ == 0) // component should be zeroed out
}
