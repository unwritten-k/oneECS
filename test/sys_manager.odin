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

Some_Health :: struct {
    health: int,
    max_health: int,
}

Some_Died_Flag :: struct {
    died: bool,
}

damage_system :: proc (data: ^ecs.System_Data) -> (res: ecs.System_Result, err: ecs.Error) {

    res = .Continue
    
    health: ^Some_Health
    died_flag: ^Some_Died_Flag
    for ent in data.entities {
        died_flag, err = ecs.coordinator_get_component(data.coordinator, ent, Some_Died_Flag)
        if err != ecs.ERROR_NONE { res=.Error ; break }

        if died_flag.died do continue

        health, err = ecs.coordinator_get_component(data.coordinator, ent, Some_Health)
        if err != ecs.ERROR_NONE { res=.Error ; break }
    
        if health.health > 0 {
            health.health -= 1
        }
        else {
            died_flag.died = true
            log.info("Entity", ent, "has died")
        }
    }
    
    return
}

@test
sys_mng_many_entities_test :: proc (_: ^testing.T) {

    coordinator: ecs.Coordinator
    err := ecs.coordinator_init(&coordinator, context.allocator)
    assert_err(err)
    defer ecs.free_coordinator(&coordinator)

    ecs.coordinator_set_system_failure_fn(&coordinator, failure_proc)

    err = ecs.coordinator_reg_component(&coordinator, Some_Health)
    assert_err(err)
    err = ecs.coordinator_reg_component(&coordinator, Some_Died_Flag)
    assert_err(err)
    err = ecs.coordinator_reg_component(&coordinator, Some_Data)
    assert_err(err)

    sign: ecs.Component_Signature
    sign, err = ecs.coordinator_make_signature(&coordinator, {Some_Health, Some_Died_Flag})
    assert_err(err)

    err = ecs.coordinator_reg_system(&coordinator, damage_system, sign)
    assert_err(err)

    sign, err = ecs.coordinator_make_signature(&coordinator, {Some_Data})
    assert_err(err)

    err = ecs.coordinator_reg_system(&coordinator, fall_system, sign)
    assert_err(err)

    ent: ecs.Entity
    health: ^Some_Health
    died_flag: ^Some_Died_Flag
    some_data: ^Some_Data
    for i in 0..<10 {
        
        ent, err = ecs.coordinator_entity_create_entity(&coordinator)
        assert_err(err)

        health, err = ecs.coordinator_add_component(&coordinator, ent, Some_Health)
        assert_err(err)
        health.max_health = 5
        health.health = health.max_health

        died_flag, err = ecs.coordinator_add_component(&coordinator, ent, Some_Died_Flag)
        assert_err(err)
        died_flag.died = false

        if i % 3 == 0 {
            some_data, err = ecs.coordinator_add_component(&coordinator, ent, Some_Data)
            some_data.x = 10.3
            some_data.y = 23.5
        }
    }

    for i in 0..<20 {
        ecs.coordinator_run_systems(&coordinator)
    }

}
