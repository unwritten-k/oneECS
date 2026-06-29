package tests

import "core:testing"
import ecs ".."

@test
coord_test :: proc (_: ^testing.T) {

    err : ecs.Error

    coordinator: ecs.Coordinator
    err = ecs.coordinator_init(&coordinator, context.allocator)
    assert_err(err)
    defer ecs.free_coordinator(&coordinator)

    entity: ecs.Entity
    entity, err = ecs.coordinator_create_entity(&coordinator)
    assert_err(err)

    err = ecs.coordinator_reg_component(&coordinator, Some_Data)
    assert_err(err)
    
    component : ^Some_Data
    component, err = ecs.coordinator_add_component(&coordinator, entity, Some_Data)
    assert_err(err)
    
    component.x = 1.43
    component.y = 6.28

    retrived_component : ^Some_Data
    retrived_component, err = ecs.coordinator_get_component(&coordinator, entity, Some_Data)
    assert_err(err)

    retrived_entity : ecs.Entity
    retrived_entity, err = ecs.coordinator_get_entity(&coordinator, retrived_component)
    assert_err(err)

    err = ecs.coordinator_remove_component(&coordinator, entity, Some_Data)
    assert_err(err)
}
