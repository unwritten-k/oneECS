#+private
package one_ecs

import "core:testing"
import "core:mem"
import "base:runtime"
import core "core"

@(private="file")
INVALID_ID :: -1

Table :: struct {
    using basic: Basic_Table,

    capacity: int,
    entity_to_id: [/*Entity*/]int,

    components_count: int,
    bytes: []byte,

    type_info: ^runtime.Type_Info,

    t_id: int,
}

table_init :: proc (self: ^Table, db: ^Database, capacity: int, type: typeid, loc:=#caller_location) -> Error {
    self.table_type = .Table
    self.db = db
    self.capacity = capacity
    
    self.type_info = type_info_of(type)
    
    self.entity_to_id = make([]int, db.max_entities, db.allocator, loc) or_return
    self.bytes = make([]byte, capacity*self.type_info.size, db.allocator, loc) or_return

    self.t_id = database_attach_table(self.db, (^Basic_Table)(self)) or_return

    table_clear(self)

    return ERROR_NONE
}

table_add_component :: proc (self: ^Table, ent: Entity_Id) -> (rawptr, Error) {
    if !database_entity_is_valid(self.db, ent) do return nil, Collection_Error.Invalid_Entity
    if table_has_entity(self, ent) do return nil, Collection_Error.Already_Added

    id := self.components_count
    self.entity_to_id[ent.idx] = id

    slice := self.bytes[id : id+self.type_info.size]

    err := database_signature_add_component(self.db, ent, self.t_id)
    if err != ERROR_NONE {
        self.entity_to_id[ent.idx] = INVALID_ID
        return nil, err
    }

    self.components_count += 1
    
    return raw_data(slice), ERROR_NONE
}

table_remove_component :: proc (self: ^Table, ent: Entity_Id) -> Error {
    if !database_entity_is_valid(self.db, ent) do return Collection_Error.Invalid_Entity
    if !table_has_entity(self, ent) do return Collection_Error.Entity_Not_Found

    database_signature_remove_component(self.db, ent, self.t_id) or_return

    id := self.entity_to_id[ent.idx]
    self.entity_to_id[ent.idx] = INVALID_ID

    slice := self.bytes[id : id+self.type_info.size]
    mem.zero(raw_data( slice ), self.type_info.size)

    return ERROR_NONE
}

table_get_component :: proc (self: ^Table, ent: Entity_Id) -> (rawptr, Error) {
    if !database_entity_is_valid(self.db, ent) do return nil, Collection_Error.Invalid_Entity
    if !table_has_entity(self, ent) do return nil, Collection_Error.Entity_Not_Found

    id := self.entity_to_id[ent.idx]
    slice := self.bytes[id : id+self.type_info.size]
    return raw_data(slice), ERROR_NONE
}

table_clear :: proc (self: ^Table) {
    for &id in self.entity_to_id {
        id = INVALID_ID
    }

    self.components_count = 0
    mem.zero(raw_data(self.bytes), len(self.bytes))
}

table_has_entity :: proc (self: ^Table, ent: Entity_Id) -> bool {
    return self.entity_to_id[ent.idx] != INVALID_ID
}

table_free :: proc (self: ^Table, loc:=#caller_location) -> Error {

    delete(self.entity_to_id, self.db.allocator, loc)

    mem.free_with_size(raw_data(self.bytes), self.capacity*self.type_info.size, self.db.allocator, loc) or_return

    self.capacity = 0
    self.components_count = 0

    return ERROR_NONE
}

@test
table_test :: proc (_: ^testing.T) {

    db: Database
    database_init(&db, context.allocator)
    defer database_free(&db)

    err: Error

    table: Table
    err = table_init(&table, &db, 32, int)
    assert(err == ERROR_NONE, error_to_str(err))

    context.allocator = runtime.panic_allocator()

    entity, _ := database_create_entity(&db)

    comp_ptr: rawptr
    comp_ptr, err = table_add_component(&table, entity)
    assert(err == ERROR_NONE, error_to_str(err))

    component := cast(^int)comp_ptr
    assert(component^ == 0)

    component^ = 15

    comp_ptr, err = table_get_component(&table, entity)
    assert(err == ERROR_NONE, error_to_str(err))
    component = cast(^int)comp_ptr
    assert(component^ == 15)

    err = table_remove_component(&table, entity)
    assert(err == ERROR_NONE, error_to_str(err))
    assert(component^ == 0)
}
