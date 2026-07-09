package main

import "core:fmt"
import "core:math/rand"
import ecs "../../"

Position :: struct {
    x, y: f32
}

move_entities :: proc (db: ^ecs.Database) {
    
    signature := ecs.make_signature(db, Position)
    query := ecs.query(db, signature)

    pos: ^Position
    offset_x: f32
    offset_y: f32
    for entity in query {
        offset_x = rand.float32_range(-5, 5)
        offset_y = rand.float32_range(-5, 5)

        pos, _ = ecs.get_component(db, entity, Position)
        pos.x += offset_x
        pos.y += offset_y
    }

}

print_entity_positions :: proc (db: ^ecs.Database) {
    
    signature := ecs.make_signature(db, Position)
    query := ecs.query(db, signature)

    pos: ^Position
    for entity in query {
        pos, _ = ecs.get_component(db, entity, Position)
        fmt.println("Entity", entity.idx, "is now at (x,y)", pos.x, pos.y)
    }
}

main :: proc () {
    
    db: ecs.Database
    ecs.database_init(&db, context.allocator)
    defer ecs.database_free(&db)

    ecs.register_component(&db, Position)

    for i in 0..<10 {
        entity, _ := ecs.create_entity(&db)
        ecs.add_component(&db, entity, Position)
    }

    fmt.println("=============== BEFORE MOVE =================")
    print_entity_positions(&db)

    for i in 0..<5 {
        move_entities(&db)
    }

    fmt.println("===============  AFTER MOVE =================")
    print_entity_positions(&db)

}

