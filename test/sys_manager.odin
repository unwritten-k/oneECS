package tests

import "core:log"
import "core:testing"
import ecs ".."

fall_system :: proc (data: ^ecs.System_Data) -> (ecs.System_Result, ecs.Error) {

    for ent in data.entities {
        some_data_comp, err := ecs.coordinator_get_component(data.coordinator, ent, Some_Data)
        
        some_data_comp.y -= 1.5

        log.info("Entity", ent, "now has Some_Data:", some_data_comp)
    }

    return .Continue, ecs.ERROR_NONE
}

failure_proc :: proc (err: ecs.Error, system: ^ecs.System) {
    log.info("System failed with error:", err)
    assert(false, "System failed")
}

@test
sys_mng_test :: proc (_: ^testing.T) {

    err: ecs.Error

    coordinator: ecs.Coordinator
    ecs.coordinator_init(&coordinator, context.allocator)
    assert_err(err)
    defer ecs.free_coordinator(&coordinator)

    ecs.coordinator_set_system_failure_fn(&coordinator, failure_proc)

    ent: ecs.Entity
    ent, err = ecs.coordinator_entity_create_entity(&coordinator)
    assert_err(err)

    assert_err(ecs.coordinator_reg_component(&coordinator, Some_Data))

    some_data: ^Some_Data
    some_data, err = ecs.coordinator_add_component(&coordinator, ent, Some_Data)
    assert_err(err)
    
    some_data.x = 3.14
    some_data.y = 6.28

    sign : ecs.Component_Signature
    sign, err = ecs.coordinator_make_signature(&coordinator, {Some_Data})
    assert_err(err)

    // test registering system after creating entity and assigning component
    err = ecs.coordinator_reg_system(&coordinator, fall_system, sign)
    assert_err(err)

    for _ in 0..<10 {
        ecs.coordinator_run_systems(&coordinator)
    }
}
