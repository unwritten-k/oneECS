package main

import "base:runtime"

Entity_Manager :: struct {
    allocator: runtime.Allocator,

    // Describes how many entities can there be
    // (if biggest entity is 1024, then there can be 1024 entities)
    biggest_entity: i32,
    available_entities: [dynamic]Entity,
    alive_entities: uint,

    signatures: []Component_Signature,

}

entity_manager_init :: proc (mng: ^Entity_Manager, allocator: runtime.Allocator, max_entities:=i32(DEFAULT_MAX_ENTITIES), loc:=#caller_location) -> Error {
    mng.allocator = allocator

    mng.alive_entities = 0
    
    mng.biggest_entity = max_entities

    mng.signatures = make([]Component_Signature, max_entities, allocator, loc) or_return

    mng.available_entities = make([dynamic]Entity, 0, max_entities, allocator, loc) or_return

    for i in 0..<Entity(max_entities) {
        append(&mng.available_entities, i)
    }

    return ERROR_NONE
}

entity_create :: proc (mng: ^Entity_Manager) -> (ent: Entity, err: Error) {

    if len(mng.available_entities) == 0 do return ERROR_ENTITY, .No_Available_Entities

    ent = pop_front(&mng.available_entities)
    mng.alive_entities += 1

    return
}

entity_destroy :: proc (mng: ^Entity_Manager, ent: Entity) -> Error {

    if !entity_is_valid(mng, ent) || len(mng.available_entities) == 0 do return .Invalid_Entity

    mng.alive_entities -= 1
    // unlikely to happen
    if (len(mng.available_entities)+1 > cap(mng.available_entities)) do return .Too_Much_Entites
    
    append(&mng.available_entities, ent)

    return ERROR_NONE
}

entity_get_signature :: proc (mng: ^Entity_Manager, ent: Entity) -> Component_Signature {
    
    if !entity_is_valid(mng, ent) do return nil

    return mng.signatures[ent]
}

entity_manager_sign_add_component :: proc (mng: ^Entity_Manager, ent: Entity, id: Component_Type) -> Error {
    if !entity_is_valid(mng, ent) do return .Invalid_Entity

    mng.signatures[ent] += {id}

    return ERROR_NONE
}

entity_manager_sign_remove_component :: proc(mng: ^Entity_Manager, ent: Entity, id: Component_Type) -> Error {
    if !entity_is_valid(mng, ent) do return .Invalid_Entity

    mng.signatures[ent] -= {id}

    return ERROR_NONE
}

entity_manager_sign_has_component :: #force_inline proc "contextless" (mng: ^Entity_Manager, ent: Entity, id: Component_Type) -> bool {
    return id in mng.signatures[ent]
}

free_entity_manager :: proc (mng: ^Entity_Manager, loc:=#caller_location) -> Error {
    delete(mng.available_entities, loc) or_return
    delete(mng.signatures, mng.allocator, loc) or_return

    mng.alive_entities = 0
    mng.biggest_entity = 0

    return ERROR_NONE
}

entity_is_valid :: proc (mng: ^Entity_Manager, ent: Entity) -> bool {
    return ent >= 0 && ent < mng.biggest_entity
}

