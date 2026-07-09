package main

import "core:math"
import "core:time"
import "core:fmt"
import "core:math/rand"
import ecs "../../"

Health :: struct {
    max_points: int,
    points: int,
}

// A tag component
Dead :: struct {}

damage_entities :: proc (db: ^ecs.Database) {
    sign := ecs.make_signature(db, Health)
    query := ecs.query(db, sign, exclude={Dead})

    health: ^Health
    rand_damage: int
    for entity in query {
        health, _ = ecs.get_component(db, entity, Health)

        rand_damage = cast(int) rand.int64_range(3, 5)
        
        if health.points > 0 do health.points -= rand_damage
        else do ecs.add_component(db, entity, Dead)
    }
}

print_num_of_dead :: proc (db: ^ecs.Database) {
    sign := ecs.make_signature(db, Dead)
    query := ecs.query(db, sign)

    fmt.println("Number of dead entities:", len(query), "/", ecs.database_entity_len(db))
}

main :: proc () {
    db: ecs.Database
    ecs.database_init(&db, context.allocator)
    defer ecs.database_free(&db)

    ecs.register_component(&db, Health)
    ecs.register_component(&db, Dead)

    for i in 0..<1024 {
        entity, _ := ecs.create_entity(&db)
        ecs.add_component(&db, entity, Health)

        health, _ := ecs.get_component(&db, entity, Health)
        health.max_points = 15
        health.points = health.max_points
    }

    for i in 0..<5 {
        damage_entities(&db)
        suf := "st" if i == 0 else "nd" if i == 1 else "rd" if i == 2 else "th" 
        fmt.println("Damaged ", i+1, suf, " time", sep="")
    }
    
    print_num_of_dead(&db)
}
