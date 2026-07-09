Implementation of ECS in Odin.

### Structure
Components are divided into two categories: regular components and tags. Tag components are components that are zero in size.

Regular components support all operations: adding, removing and getting. And tag components support only adding and removing.

### Querying
To query, use function 'query':
```odin
query :: proc (db: ^Database, include:Component_Signature, exclude:=[]typeid{}) -> []Entity_Id
```

Querying is done by iterating over every alive entity and comparing required signature with entity's signature. Then it checks if entity's signature contains any of components that should be excluded, and if it does not, entity is added to query result.

### Example
```odin
import "core:fmt"
import ecs "one_ecs"

db: ecs.Database
ecs.database_init(&db, context.allocator)
defer ecs.database_free(&db)

// second value is an error code
entity, _ := ecs.create_entity(&db)

// regular component
Health :: struct { points: int, max_points: int }
// tag component
Dead :: struct {}

ecs.register_component(&db, Health)
ecs.register_component(&db, Dead)

ecs.add_component(&db, entity, Health)

health, _ := ecs.get_component(&db, entity, Health)
health.max_points = 100
health.points = health.max_points

health_signatrue := ecs.make_signature(&db, Health)
damage_system :: proc (db: ^ecs.Database) {
    result := ecs.query(db, health_signature, exclude={Dead})

    DAMAGE :: 5 
    health: ^Health
    for entity in query {
        health, _ = ecs.get_component(db, entity, Health)
        
        if health.points > 0 do health.points -= DAMAGE
        else do ecs.add_component(db, entity, Dead)
    }
}

for i in 0..<20 {
    damage_system(&db)
}

if ecs.has_component(db, entity, Dead) {
    fmt.println("Entity", entity.idx, "is dead")
}

```
