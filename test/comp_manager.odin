package tests

import "core:log"
import "core:testing"

import ecs ".."

@test
comp_mng_test :: proc (_: ^testing.T) {
    
    err: ecs.Error

    entity_mng: ecs.Entity_Manager
    err = ecs.entity_manager_init(&entity_mng, context.allocator)
    assert_err(err)
    defer ecs.free_entity_manager(&entity_mng)

    comp_mng: ecs.Component_Manager
    ecs.component_manager_init(&comp_mng, context.allocator)
    assert_err(err)
    defer ecs.free_component_manager(&comp_mng)

    err = ecs.component_manager_register_type(&comp_mng, Some_Data)
    assert_err(err)

    entity: ecs.Entity

    entity, err = ecs.entity_create(&entity_mng)
    assert_err(err)

    some_data: ^Some_Data
    some_data, err = ecs.component_manager_add_component(&comp_mng, Some_Data, entity)
    assert_err(err)

    some_data.x = 3.14
    some_data.y = 123.5

    table : ^ecs.Table(Some_Data)
    table, err = ecs.component_manager_get_table(&comp_mng, Some_Data)
    assert_err(err)
    
    iter_ent: ecs.Entity
    for &comp in table.components {
        iter_ent, err = ecs.component_manager_get_entity(&comp_mng, &comp)
        log.info("Iterating over", comp, "which is component of entity", iter_ent)
    }

    err = ecs.component_manager_remove_component(&comp_mng, Some_Data, entity)
    assert_err(err)

    log.info("Pointer to invalid Some_Data:", some_data)
}
