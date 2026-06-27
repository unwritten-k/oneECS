package main

import "base:runtime"

Component_Manager :: struct {
    allocator: runtime.Allocator,

    max_entities: int,
    max_types: int,
    table_capacity: int,

    type_to_idx: map[typeid]Component_Type,
    tid_to_table: []^Table_Base,

    n_types: int,
}

component_manager_init :: proc (
    mng: ^Component_Manager,
    allocator:runtime.Allocator,
    max_entites:=DEFAULT_MAX_ENTITIES, 
    max_types:=DEFAULT_MAX_COMPONENTS, 
    table_capacity:=DEFAULT_MAX_ENTITIES,
    loc:=#caller_location
) -> Error {

    mng.allocator = allocator

    mng.max_entities = max_entites
    mng.max_types = max_types
    mng.table_capacity = table_capacity

    mng.type_to_idx = make(map[typeid]Component_Type, max_types, allocator, loc) or_return
    mng.tid_to_table = make([]^Table_Base, max_types, allocator, loc) or_return

    mng.n_types = 0

    return ERROR_NONE
}

// Allocates new table on heap and registers it under T typeid
component_manager_register_type :: proc (mng: ^Component_Manager, $T: typeid, loc:=#caller_location) -> Error {
    if T in mng.type_to_idx do return .Already_Registered
    if len(mng.type_to_idx) >= mng.max_types do return .Reached_Type_Limit

    table := new(Table(T), mng.allocator, loc) or_return
    table_init(table, mng.allocator, mng.max_entities, mng.table_capacity) or_return

    mng.type_to_idx[T] = mng.n_types
    mng.tid_to_table[mng.n_types] = (^Table_Base)(table)
    
    mng.n_types += 1

    return ERROR_NONE
}

component_manager_add_component :: proc (mng: ^Component_Manager, $T: typeid, entity: Entity) -> (component: ^T, err: Error) {
    if T not_in mng.type_to_idx do return nil, .Not_Registered
    if !component_manager_entity_is_valid(mng, entity) do return nil, .Invalid_Entity

    table := (^Table(T))(mng.tid_to_table[mng.type_to_idx[T]])
    return table_add_component(table, entity)
}

component_manager_remove_component :: proc (mng: ^Component_Manager, T: typeid, entity: Entity) -> Error {
    if T not_in mng.type_to_idx do return .Not_Registered
    if !component_manager_entity_is_valid(mng, entity) do return .Invalid_Entity

    table := (^Table_Bytes)(mng.tid_to_table[mng.type_to_idx[T]])
    return table_bytes_remove_component(table, entity)
}

component_manager_get_component :: proc (mng: ^Component_Manager, $T: typeid, entity: Entity) -> (component: ^T, err: Error) {
    if T not_in mng.type_to_idx do return nil, .Not_Registered
    if !component_manager_entity_is_valid(mng, entity) do return nil, .Invalid_Entity

    table := (^Table(T))(mng.tid_to_table[mng.type_to_idx[T]])
    return table_get_component(table, entity)
}

component_manager_get_table :: proc (mng: ^Component_Manager, $T: typeid) -> (table: ^Table(T), err: Error) {
    if T not_in mng.type_to_idx do return nil, .Not_Registered

    return (^Table(T))(mng.tid_to_table[mng.type_to_idx[T]]), ERROR_NONE
}

component_manager_get_entity :: proc (mng: ^Component_Manager, component: ^$T) -> (entity: Entity, err: Error) {
    if T not_in mng.type_to_idx do return ERROR_ENTITY, .Not_Registered
    
    table := (^Table(T))(mng.tid_to_table[mng.type_to_idx[T]])
    return table_get_entity(table, component)
}

component_manager_entity_is_valid :: #force_inline proc "contextless" (mng: ^Component_Manager, entity: Entity) -> bool {
    return entity >= 0 && entity < Entity(mng.max_entities)
}

free_component_manager :: proc (mng: ^Component_Manager, loc:=#caller_location) -> Error {
    for _, tid in mng.type_to_idx {

        table := (^Table_Bytes)(mng.tid_to_table[tid])
        free_table_bytes(table) or_return
        free(table, mng.allocator, loc)
    }

    delete(mng.type_to_idx, loc) or_return
    delete(mng.tid_to_table, mng.allocator, loc) or_return

    return ERROR_NONE
}
