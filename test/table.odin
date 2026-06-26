package tests

import "core:log"
import "core:testing"
import ecs ".."

Some_Data :: struct {
    x: f32,
    y: f32
}

Some_Other_Data :: struct {
    name: string,
    group_n: int,
}

@test
table_test :: proc (_: ^testing.T) {

    err: ecs.Error

    table : ecs.Table (Some_Data)
    err = ecs.table_init(&table, context.allocator)
    assert(err == ecs.ERROR_NONE, "Could not init table")
    defer ecs.free_table(&table)

    entity: ecs.Entity = 1023

    component: ^Some_Data

    component, err = ecs.table_add_component(&table, entity)
    assert(err == ecs.ERROR_NONE, "Failed adding component")

    component.x = 23.5
    component.y = 14.15
    
    log.info(component, table.size)

    err = ecs.table_remove_component(&table, entity)
    assert(err == ecs.ERROR_NONE, "Failed removing component")

    log.info(component, table.size)
}

@test
table_test2 :: proc (_: ^testing.T) {

    tables := make([]^ecs.Table_Base, ecs.MAX_COMPONENTS)

    table : ecs.Table (Some_Data)
    err := ecs.table_init(&table, context.allocator)
    assert(err == ecs.ERROR_NONE, ecs.error_to_str(err))
    defer ecs.free_table(&table)

    tables[0] = &table

    other_table : ecs.Table (Some_Other_Data)
    err = ecs.table_init(&other_table, context.allocator)
    assert(err == ecs.ERROR_NONE, ecs.error_to_str(err))
    defer ecs.free_table(&other_table)
    
    tables[1] = &other_table

    
    table_ptr := (^ecs.Table(Some_Data))(tables[0])

    comp: ^Some_Data
    comp, err = ecs.table_add_component(table_ptr, 0)
    assert(err == ecs.ERROR_NONE, ecs.error_to_str(err))

    comp.x = 0
    comp.y = 12

    table_ptr2 := (^ecs.Table(Some_Other_Data))(tables[1])
    
    comp2 : ^Some_Other_Data
    comp2, err = ecs.table_add_component(table_ptr2, 1)
    assert(err == ecs.ERROR_NONE, ecs.error_to_str(err))

    comp2.group_n = 123224
    comp2.name = "Name"
}

@test
table_iter :: proc (_: ^testing.T) {
    err: ecs.Error

    table : ecs.Table (Some_Data)
    err = ecs.table_init(&table, context.allocator)
    assert(err == ecs.ERROR_NONE, ecs.error_to_str(err))
    defer ecs.free_table(&table)

    // add component for 10 entities (from 0 to 9)
    for entity in 0..<ecs.Entity(10) {
        comp: ^Some_Data
        comp, err = ecs.table_add_component(&table, entity)
        assert(err == ecs.ERROR_NONE, ecs.error_to_str(err))

        // change the data
        comp.x = cast(f32) entity
        comp.y = cast(f32) entity / 2
    }

    // iterate over table
    for &comp in table.components {
        
        log.info("Iterating over component", comp)
    }
}
