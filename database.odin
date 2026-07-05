package one_ecs

import "core:testing"
import "base:runtime"
import core "core"

Entity_Id :: core.Entity_Id
INVALID_ENTITY_IDX :: core.INVALID_IDX

COMPONENT_SIGNATURES_MAX :: #config(COMPONENT_SIGNATURES_MAX, 32)

Component_Signature :: bit_set[0..<COMPONENT_SIGNATURES_MAX; u64]

DEFAULT_MAX_ENTITIES :: 1024

Database :: struct {
    allocator: runtime.Allocator,
    
    max_entities: int,
    entity_factory: core.Entity_Factory,
    
    signatures: [/*Entity ID*/]Component_Signature,

    component_types_count: int,
    idx_to_type: [COMPONENT_SIGNATURES_MAX]typeid // no need for allocation, since length will always be constant
}

database_init :: proc (self: ^Database, allocator: runtime.Allocator, max_entities:=DEFAULT_MAX_ENTITIES, loc:=#caller_location) -> Error {

    self.allocator = allocator
    self.max_entities = max_entities

    core.entity_factory_init(&self.entity_factory, max_entities, allocator, loc) or_return

    self.signatures = make([]Component_Signature, max_entities, allocator, loc) or_return

    return ERROR_NONE
}

database_create_entity :: #force_inline proc (self: ^Database) -> (ent: Entity_Id, err: Error) {
    return core.entity_factory_create_id(&self.entity_factory) 
}

database_destroy_entity :: #force_inline proc (self: ^Database, ent: Entity_Id) -> Error {
    err := core.entity_factory_free_id(&self.entity_factory, ent)
    if err != core.ERROR_NONE do return err

    self.signatures[ent.idx] = nil

    return ERROR_NONE
}

database_entity_is_valid :: #force_inline proc (self: ^Database, ent: Entity_Id) -> bool {
    return (ent.idx >= 0 && ent.idx < self.max_entities) \ 
        && !core.entity_factory_is_freed(&self.entity_factory, ent) \
        && !core.entity_factory_is_expired(&self.entity_factory, ent)
}

database_get_signature :: #force_inline proc (self: ^Database, ent: Entity_Id) -> (Component_Signature, Error) {
    if !database_entity_is_valid(self, ent) do return nil, Collection_Error.Invalid_Entity

    return self.signatures[ent.idx], ERROR_NONE
} 

@private
database_register_type :: proc (self: ^Database, T: typeid) -> (int, Error) {
    if self.component_types_count >= len(self.idx_to_type) do return -1, Collection_Error.Exceeded_Capacity

    t_id := self.component_types_count
    self.idx_to_type[t_id] = T

    return t_id, ERROR_NONE
}

database_signature_add_component :: proc (self: ^Database, ent: Entity_Id, type_id: int) -> Error {
    if !database_entity_is_valid(self, ent) do return Collection_Error.Invalid_Entity

    self.signatures[ent.idx] += {type_id}

    return ERROR_NONE
}

database_signature_remove_component :: proc (self: ^Database, ent: Entity_Id, type_id: int) -> Error {
    if !database_entity_is_valid(self, ent) do return Collection_Error.Invalid_Entity

    self.signatures[ent.idx] -= {type_id}

    return ERROR_NONE
}

database_signature_clear :: proc (self: ^Database, ent: Entity_Id) -> Error {
    if !database_entity_is_valid(self, ent) do return Collection_Error.Invalid_Entity

    self.signatures[ent.idx] = nil

    return ERROR_NONE
}

database_free :: proc (self: ^Database, loc:=#caller_location) -> Error {
    core.entity_factory_free(&self.entity_factory, loc) or_return
    
    delete(self.signatures, self.allocator, loc) or_return

    return ERROR_NONE
}

@test
database_test :: proc (_: ^testing.T) {
    err: Error

    db: Database
    err = database_init(&db, context.allocator)
    assert(err == ERROR_NONE, error_to_str(err))
    defer assert(database_free(&db) == ERROR_NONE, error_to_str(err))

    entity: Entity_Id

    entity, err = database_create_entity(&db)
    assert(err == ERROR_NONE, error_to_str(err))
    assert(entity.idx == 0 && entity.gen == 0)
    
    Some_Type :: 0
    Some_Other_Type :: 1

    err = database_signature_add_component(&db, entity, Some_Type)
    assert(err == ERROR_NONE, error_to_str(err))

    err = database_signature_add_component(&db, entity, Some_Other_Type)
    assert(err == ERROR_NONE, error_to_str(err))

    sign: Component_Signature
    sign, err = database_get_signature(&db, entity)
    assert(err == ERROR_NONE, error_to_str(err))
    assert(sign == {0, 1})

    err = database_destroy_entity(&db, entity)
    assert(err == ERROR_NONE, error_to_str(err))

    assert(db.signatures[entity.idx] == nil)

    for i in 0..<db.max_entities {
        database_create_entity(&db)
    }

    invalid_entity: Entity_Id
    invalid_entity, err = database_create_entity(&db)
    assert(err != ERROR_NONE, "No error after exceeding entity capacity")
}
