package one_ecs

//// FUNCTION ALIASES


create_entity :: database_create_entity
destroy_entity :: database_destroy_entity
entity_is_valid :: database_entity_is_valid

register_component :: database_register

add_component :: database_add_component
remove_component :: database_remove_component
get_component :: database_get_component
has_component :: database_has_component

get_signature :: database_get_signature
make_signature :: database_make_signature

query :: database_query

////////////////// HELPERS


handle :: proc {
    handle_err,
    handle_err_result
}

// Asserts that error is NONE
handle_err :: #force_inline proc (err: Error) {
    assert(err == ERROR_NONE, error_to_str(err))
}

// Asserts that error is NONE and returns res
handle_err_result :: #force_inline proc (res: $T, err: Error) -> T {
    assert(err == ERROR_NONE, error_to_str(err))
    return res
}

