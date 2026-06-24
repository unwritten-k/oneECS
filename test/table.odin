package tests

import "core:log"
import "core:testing"
import ecs ".."

Some_Data :: struct {
    x: f32,
    y: f32
}

@test
table_test :: proc (_: ^testing.T) {

    table : ecs.Table (Some_Data)
    ecs.table_init(&table, context.allocator)
    defer ecs.free_table(&table)

    entity: ecs.Entity = 1023
    
    err: ecs.Error
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
