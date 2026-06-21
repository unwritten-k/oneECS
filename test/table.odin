package tests

import "core:log"
import "core:testing"
import e ".."

Some_Data :: struct {
    x: f32,
    y: f32
}

@test
table_test :: proc (_: ^testing.T) {

    table : e.Table (Some_Data)
    e.table_init(&table)
    defer e.free_table(&table)

    entity: e.Entity = 0
    
    ok: bool
    component: ^Some_Data

    component, ok = e.table_add_component(&table, entity)

    component.x = 23.5
    component.y = 14.15
    
    log.info(component, table.size)

    ok = e.table_remove_component(&table, entity)

    log.info(component, table.size)
}
