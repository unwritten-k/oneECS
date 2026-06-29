package main

import "core:log"
import "base:runtime"

Coordinator :: struct {
    // Describes how many entities can there be
    // (if biggest entity is 1024, then there can be 1024 entities)
    biggest_entity: int,

    entity_mng: Entity_Manager,
    component_mng: Component_Manager,
    system_mng: System_Manager,

    allocator: runtime.Allocator
}

coordinator_init :: proc (
    self: ^Coordinator, 
    allocator: runtime.Allocator, 

    biggest_entity:=DEFAULT_MAX_ENTITIES, 

    start_capacity_of_system_arr:=16, 
    loc:=#caller_location
) -> Error {

    self.biggest_entity = biggest_entity
    self.allocator = allocator

    entity_manager_init(&self.entity_mng, allocator, i32(biggest_entity), loc) or_return
    component_manager_init(&self.component_mng, allocator, biggest_entity, biggest_entity, loc) or_return
    system_manager_init(&self.system_mng, allocator, biggest_entity, biggest_entity, start_capacity_of_system_arr, loc)

    return ERROR_NONE
}

coordinator_entity_create_entity :: proc (self: ^Coordinator) -> (ent: Entity, err: Error) {
    return entity_manager_create_entity(&self.entity_mng)
}

coordinator_entity_destroy_entity :: proc (self: ^Coordinator, ent: Entity) -> Error {
    sign := entity_manager_get_signature(&self.entity_mng, ent)
    component_manager_clear_components(&self.component_mng, ent, sign)
    system_manager_entity_destroyed(&self.system_mng, ent)
    return entity_manager_destroy_entity(&self.entity_mng, ent)
}

coordinator_reg_component :: proc (self: ^Coordinator, $T: typeid, loc:=#caller_location) -> Error {
    return component_manager_register_type(&self.component_mng, T, loc)
}

coordinator_add_component :: proc (self: ^Coordinator, ent: Entity, $T: typeid) -> (component: ^T, err: Error) {

    component = component_manager_add_component(&self.component_mng, T, ent) or_return

    comp_type: Component_Type
    comp_type, err = component_manager_get_type(&self.component_mng, T)
    if err != ERROR_NONE {
        component = nil
        return
    }

    err = entity_manager_sign_add_component(&self.entity_mng, ent, comp_type)
    if err != ERROR_NONE {
        component = nil
        return
    }

    sign := entity_manager_get_signature(&self.entity_mng, ent)
    system_manager_entity_sign_changed(&self.system_mng, ent, sign)

    return
}

coordinator_remove_component :: proc (self: ^Coordinator, ent: Entity, T: typeid) -> Error {

    component_manager_remove_component(&self.component_mng, T, ent) or_return

    comp_id := component_manager_get_type(&self.component_mng, T) or_return

    entity_manager_sign_remove_component(&self.entity_mng, ent, comp_id) or_return

    sign := entity_manager_get_signature(&self.entity_mng, ent)
    system_manager_entity_sign_changed(&self.system_mng, ent, sign)
    
    return ERROR_NONE
}

coordinator_get_component :: proc (self: ^Coordinator, ent: Entity, $T: typeid) -> (component: ^T, err: Error) {

    return component_manager_get_component(&self.component_mng, T, ent)
}

coordinator_get_entity :: proc (self: ^Coordinator, component: ^$T) -> (ent: Entity, err: Error) {

    return component_manager_get_entity(&self.component_mng, component)
}

coordinator_reg_system :: proc (self: ^Coordinator, fn: System_Proc, signature: Component_Signature, loc:=#caller_location) -> Error {
    return system_manager_reg_system(&self.system_mng, self, fn, signature, loc)
}

coordinator_run_systems :: proc (self: ^Coordinator) {
    system_manager_run(&self.system_mng)
}

coordinator_make_signature :: proc (self: ^Coordinator, typeids: []typeid) -> (signature: Component_Signature, err: Error) {
    for t in typeids {
        type_n := component_manager_get_type(&self.component_mng, t) or_return
        signature += {type_n}
    }
    return
}

coordinator_set_system_failure_fn :: #force_inline proc "contextless" (self: ^Coordinator, fn: System_Failure_Proc) {
    self.system_mng.failure_proc = fn
}

free_coordinator :: proc (self: ^Coordinator) -> Error {
    free_entity_manager(&self.entity_mng) or_return
    free_component_manager(&self.component_mng) or_return
    free_system_manager(&self.system_mng) or_return

    return ERROR_NONE
}
