package main

import "base:runtime"

Table_Base :: struct {
    type_info: ^runtime.Type_Info,

    entity_to_idx: [MAX_ENTITIES]int,
    idx_to_entity: [MAX_ENTITIES]Entity,

    size: int,
}

table_base_init :: proc (table: ^Table_Base, allocator:=context.allocator, loc:=#caller_location) {

    table.allocator = allocator

    table.entity_to_idx = make([]int,       MAX_ENTITIES, allocator, loc)
    table.idx_to_entity = make([]Entity,    MAX_ENTITIES, allocator, loc)
    table.idx_to_rawptr = make([]rawptr,    MAX_ENTITIES, allocator, loc)

}

//////// Component table

Table :: struct($T: typeid) {
    using base: Table_Base,
    comp_arr: []T,
}

table_init :: proc (table: ^Table($T), allocator:=context.allocator, loc:=#caller_location) {
    table_base_init(&table.base, allocator, loc)

    table.type_info = type_info_of(typeid_of(type_of(T)))

    table.comp_arr = make([]T, MAX_ENTITIES, allocator, loc)
}

// Returns true, if inserted entity data in array. Otherwise returns false
table_insert :: proc (table: ^Table($T), entity: Entity, component: T) -> bool {

    if !entity_is_valid(entity) do return false
    if table_has_entity(table, entity) do return false

    idx := table.size

    table.entity_to_idx[entity] = idx
    table.idx_to_entity[idx] = entity
    table.comp_arr[idx] = component
    
    table.size += 1

    return true
}

// Returns true, if removed entity data from array. Otherwise returns false
table_remove :: proc (table: ^Table($T), entity: Entity) -> bool {

    if !entity_is_valid(entity) do return false
    if !table_has_entity(table, entity) do return false

    entity_to_remove_idx := table.entity_to_idx[entity]
    last_idx := table.size - 1

    table.comp_arr[entity_to_remove_idx] = table.comp_arr[last_idx]

    last_entity := table.idx_to_entity[last_idx]
    table.entity_to_idx[last_entity] = entity_to_remove_idx
    table.idx_to_entity[entity_to_remove_idx] = last_entity

    table.size -= 1

    return true
}

// Returns pointer to component and true.
// In case of failure, returns nil and false
table_get_data :: proc (table: ^Table($T), entity: Entity) -> (component:^T, ok:bool) {

    if !entity_is_valid(entity) do return nil, false
    if !table_has_entity(table, entity) do return nil, false

    return &table.comp_arr[table.entity_to_idx[entity]], true
}

table_clear :: proc (table: ^Table($T)) {
    table.size = 0
}

// Returns true if entity is found. Otherwise false
table_has_entity :: proc (table: ^Table($T), entity:Entity) -> bool {

    return entity >= 0 && entity < i64(table.size)
}

