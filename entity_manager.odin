package main

import "base:runtime"

MAX_ENTITIES :: #config(MAX_ENTITIES, 1024)

ERROR_ENTITY :: -1

Entity :: i32

Entity_Manager :: struct {
    allocator: runtime.Allocator,

    maximum_entities: i32,
    available_entities: [dynamic]Entity,
    alive_entities: uint,

    signatures: []Component_Signature,

}

entity_manager_init :: proc (mng: ^Entity_Manager, max_entities:=i32(MAX_ENTITIES), allocator:=context.allocator, loc:=#caller_location) {
    mng.alive_entities = 0
    
    mng.maximum_entities = max_entities

    mng.signatures = make([]Component_Signature, max_entities, allocator, loc)

    mng.available_entities = make([dynamic]Entity, 0, max_entities, allocator, loc)

    for i in 0..<Entity(max_entities) {
        append(&mng.available_entities, i)
    }
}

entity_create :: proc (mng: ^Entity_Manager) -> Entity {

    if len(mng.available_entities) == 0 do return ERROR_ENTITY

    ent := pop_front(&mng.available_entities)
    mng.alive_entities += 1

    return ent
}

entity_destroy :: proc (mng: ^Entity_Manager, ent: Entity) -> bool {

    if !entity_is_valid(mng, ent) || len(mng.available_entities) == 0 do return false

    mng.alive_entities -= 1
    // unlikely to happen
    if (len(mng.available_entities)+1 < cap(mng.available_entities)) do return false
    
    append(&mng.available_entities, ent)

    return true
}

entity_set_signature :: proc (mng: ^Entity_Manager, ent: Entity, signature: Component_Signature) -> bool {

    if !entity_is_valid(mng, ent) do return false

    mng.signatures[ent] = signature

    return true
}

entity_get_signature :: proc (mng: ^Entity_Manager, ent: Entity) -> Component_Signature {
    
    if !entity_is_valid(mng, ent) do return nil

    return mng.signatures[ent]
}

entity_is_valid :: proc (mng: ^Entity_Manager, ent: Entity) -> bool {
    return ent >= 0 && ent < mng.maximum_entities
}

