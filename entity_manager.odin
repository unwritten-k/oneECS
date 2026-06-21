package main

MAX_ENTITIES :: #config(MAX_ENTITIES, 1024)

ERROR_ENTITY :: -1

Entity :: i32

Entity_Manager :: struct {

    available_entities: [dynamic; MAX_ENTITIES]Entity,
    alive_entities: uint,

}

entity_mng_init :: proc (mng: ^Entity_Manager) {
    mng.alive_entities = 0

    for i in 0..<i32(MAX_ENTITIES) {
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

    if !entity_is_valid(ent) || len(mng.available_entities) == 0 do return false

    mng.alive_entities -= 1
    append(&mng.available_entities, ent)

    return true
}

entity_is_valid :: proc (ent: Entity) -> bool {
    return ent >= 0 && ent < MAX_ENTITIES
}

