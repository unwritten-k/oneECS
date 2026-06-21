package main

import "core:slice"
import "base:runtime"

/////// Table base

Table_Base :: struct {
    allocator: runtime.Allocator,

    type_info: ^runtime.Type_Info,

    capacity: int,

    entity_to_idx: []int,
    idx_to_entity: []Entity,

    idx_to_rawptr: []rawptr,

    size: int,
}

table_base_init :: proc (table: ^Table_Base, table_capacity:=MAX_ENTITIES, allocator:=context.allocator, loc:=#caller_location) {

    table.allocator = allocator

    table.capacity = table_capacity
    table.entity_to_idx = make([]int,       table_capacity, allocator, loc)
    table.idx_to_entity = make([]Entity,    table_capacity, allocator, loc)
    table.idx_to_rawptr = make([]rawptr,    table_capacity, allocator, loc)

}

free_table_base :: proc (table: ^Table_Base, loc:=#caller_location) {

    delete(table.entity_to_idx, table.allocator, loc)
    delete(table.idx_to_entity, table.allocator, loc)
    delete(table.idx_to_rawptr, table.allocator, loc)

    table.size = -1
}

//////// Bytes table

// cannot be initialized, only casted from Table($T)
Table_Bytes :: struct {
    using base: Table_Base,
    bytes_arr: []byte
}

// Returns true, if removed entity data from array. Otherwise returns false
//
// **Note**: Removed component associated with given entity
// becomes invalid after removal 
table_bytes_remove_component :: proc (table: ^Table_Bytes, entity: Entity) -> bool {

    if !entity_is_valid(entity) do return false
    if !table_bytes_has_entity(table, entity) do return false
    
    entity_to_remove_idx := table.entity_to_idx[entity]
    last_idx := table.size - 1

    // Size in bytes
    type_size := table.type_info.size

    bytes_start := int(entity) * type_size
    bytes_end   := bytes_start + type_size

    slice.fill(table.bytes_arr[bytes_start:bytes_end], 0)

    table.idx_to_rawptr[entity_to_remove_idx] = table.idx_to_rawptr[last_idx]

    last_entity := table.idx_to_entity[last_idx]
    table.entity_to_idx[last_entity] = entity_to_remove_idx
    table.idx_to_entity[entity_to_remove_idx] = last_entity

    table.size -= 1

    return true
}

table_bytes_clear :: proc (table: ^Table_Bytes) {

    slice.fill(table.bytes_arr, 0)
    table.size = 0
}

// Returns true if entity is found. Otherwise false
table_bytes_has_entity :: proc (table: ^Table_Bytes, entity:Entity) -> bool {

    return entity >= 0 && entity < i32(table.size)
}

free_table_bytes :: proc (table: ^Table_Bytes) {
    
    free_table_base(&table.base)

    delete(table.bytes_arr)
}

//////// Component table

Table :: struct($T: typeid) {
    using base: Table_Base,
    comp_arr: []T,
}

table_init :: proc (table: ^Table($T), table_capacity:=MAX_ENTITIES, allocator:=context.allocator, loc:=#caller_location) {

    table_base_init(&table.base, table_capacity, allocator, loc)

    table.type_info = type_info_of(typeid_of(T))

    table.comp_arr = make([]T, table_capacity, allocator, loc)
}

// Returns true, if inserted entity data in array. Otherwise returns false
table_add_component :: proc (table: ^Table($T), entity: Entity, loc:=#caller_location) -> (component: ^T, ok: bool) {

    if !entity_is_valid(entity) do return nil, false
    if table_has_entity(table, entity) do return nil, false

    idx := table.size

    table.entity_to_idx[entity] = idx
    table.idx_to_entity[idx] = entity

    component = &table.comp_arr[idx]
    
    table.idx_to_rawptr[idx] = component
    
    table.size += 1

    ok = true

    return
}

// Returns true, if removed entity data from array. Otherwise returns false
//
// **Note**: Removed component associated with given entity
// becomes invalid after removal 
table_remove_component :: proc (table: ^Table($T), entity: Entity) -> bool {

    return table_bytes_remove_component((^Table_Bytes)(table), entity)
}

// Returns pointer to component and true.
// In case of failure, returns nil and false
table_get_component :: proc (table: ^Table($T), entity: Entity) -> (component:^T, ok:bool) {

    if !entity_is_valid(entity) do return nil, false
    if !table_has_entity(table, entity) do return nil, false

    return table.idx_to_rawptr[table.entity_to_idx[entity]], true
}

table_clear :: proc (table: ^Table($T)) {

    table_bytes_clear((^Table_Bytes)(table))
}

// Returns true if entity is found. Otherwise false
table_has_entity :: proc (table: ^Table($T), entity:Entity) -> bool {

    return entity >= 0 && entity < i64(table.size)
}

free_table :: proc (table: ^Table($T)) {

    free_table_base(&table.base)

    delete(table.comp_arr)
}
