package main

MAX_COMPONENTS :: #config(MAX_COMPONENTS, 32)
DEFAULT_MAX_ENTITIES :: #config(DEFAULT_MAX_ENTITIES, 1024)

ERROR_ENTITY :: -1
Entity :: i32

ERROR_COMPONENT :: -1
Component_Type :: int
Component_Signature :: bit_set[0..<MAX_COMPONENTS; u32]

// Compares if sign is a superset of to_match
// (sign is signature to check, and to_match is the reference signature)
do_signatures_match :: proc (sign: Component_Signature, to_match: Component_Signature) -> bool {
    return sign >= to_match
}

create_entity :: proc {
    coordinator_create_entity,
    entity_manager_create_entity,
}

destroy_entity :: proc {
    coordinator_destroy_entity,
    entity_manager_destroy_entity,
}

register_component :: proc {
    coordinator_reg_component,
    component_manager_register_type,
}

add_component :: proc {
    coordinator_add_component,
    component_manager_add_component,
    table_add_component,
}

remove_component :: proc {
    coordinator_remove_component,
    component_manager_remove_component,
    table_remove_component,
    table_bytes_remove_component,
}

clear_components :: proc {
    coordinator_clear_components,
    component_manager_clear_components,
}

get_component :: proc {
    coordinator_get_component,
    component_manager_get_component,
    table_get_component,
}

get_entity :: proc {
    coordinator_get_entity,
    component_manager_get_entity,
    table_get_entity,
}

register_system :: proc {
    coordinator_reg_system,
    system_manager_reg_system,
}

run_systems :: proc {
    coordinator_run_systems,
    system_manager_run,
}

set_failure_fn :: coordinator_set_system_failure_fn

make_signature :: coordinator_make_signature

free_ecs :: proc {
    free_coordinator,
    free_entity_manager,
    free_component_manager,
    free_system_manager,
    free_table_base,
    free_table_bytes,
    free_table,
}
