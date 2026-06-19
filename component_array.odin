package main

Component_Array_Ptr :: struct {
    ptr: rawptr,
    id: typeid,
}

component_array_to_ptr :: proc (array: ^Component_Array($T)) -> Component_Array_Ptr {

    return Component_Array_Ptr {
        array,
        typeid_of(type_of(array))
    }
}

component_array_from_ptr :: proc ($T: typeid, ptr: Component_Array_Ptr) -> Component_Array(T) {
    if T == ptr.id do return cast(Component_Array(T))ptr.ptr
    else do return nil
}

Component_Array :: struct($T: typeid) {

    comp_arr: [MAX_ENTITIES]T,

    entity_to_idx: [MAX_ENTITIES]int,
    idx_to_entity: [MAX_ENTITIES]Entity,

    size: int,

}

// Returns true, if inserted entity data in array. Otherwise returns false
component_array_insert :: proc (array: ^Component_Array($T), entity: Entity, component: T) -> bool {

    if !entity_is_valid(entity) do return false
    if !has_entity(array, entity) do return false

    idx := array.size

    array.entity_to_idx[entity] = idx
    array.idx_to_entity[idx] = entity
    array.comp_arr[idx] = component
    
    array.size += 1

    return true
}

// Returns true, if removed entity data from array. Otherwise returns false
component_array_remove :: proc (array: ^Component_Array($T), entity: Entity, component: T) -> bool {

    if !entity_is_valid(entity) do return false
    if !has_entity(array, entity) do return false

    entity_to_remove_idx := array.entity_to_idx[entity]
    last_idx := array.size - 1

    array.comp_arr[entity_to_remove_idx] = array.comp_arr[last_idx]

    last_entity := array.idx_to_entity[last_idx]
    array.entity_to_idx[last_entity] = entity_to_remove_idx
    array.idx_to_entity[entity_to_remove_idx] = last_entity

    array.size -= 1

    return true
}

// Returns pointer to component and true.
// In case of failure, returns nil and false
get_data :: proc (array: ^Component_Array($T), entity: Entity) -> (component:^T, ok:bool) {

    if !entity_is_valid(entity) do return nil, false
    if !has_entity(array, entity) do return nil, false

    return &array.comp_arr[array.entity_to_idx[entity]], true
}

// Returns true if entity is found. Otherwise false
//
// **Note**: this function excepts that given entity is valid
@(private="file")
has_entity :: proc (array: ^Component_Array, entity:Entity) -> bool {

    idx := array.entity_to_idx[entity]

    if array.idx_to_entity[idx] != entity do return false

    return true
}
