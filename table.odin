package main

import "core:mem"
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

table_base_init :: proc (table: ^Table_Base, allocator: runtime.Allocator, table_capacity:=MAX_ENTITIES, loc:=#caller_location) -> Error {

    table.allocator = allocator

    table.capacity = table_capacity

    table.entity_to_idx = make([]int,       table_capacity, allocator, loc) or_return
    table.idx_to_entity = make([]Entity,    table_capacity, allocator, loc) or_return
    table.idx_to_rawptr = make([]rawptr,    table_capacity, allocator, loc) or_return

    return ERROR_NONE
}

table_base_entity_is_valid :: proc (table: ^Table_Base, entity: Entity) -> bool {
    return entity >= 0 && entity < i32(table.capacity)
}

free_table_base :: proc (table: ^Table_Base, loc:=#caller_location) -> Error {

    delete(table.entity_to_idx, table.allocator, loc) or_return
    delete(table.idx_to_entity, table.allocator, loc) or_return
    delete(table.idx_to_rawptr, table.allocator, loc) or_return

    table.size = -1

    return ERROR_NONE
}

//////// Bytes table

Table_Bytes :: struct {
    using base: Table_Base,
    bytes_arr: []byte
}

table_bytes_init :: proc (table: ^Table_Bytes, allocator: runtime.Allocator, type_info: ^runtime.Type_Info, table_capacity:=MAX_ENTITIES, loc:=#caller_location) -> (err:Error) {
    table_base_init(&table.base, allocator, table_capacity, loc) or_return

    table.type_info = type_info

    table.bytes_arr = make ([]byte, type_info.size*table_capacity, allocator, loc) or_return

    table_bytes_clear(table)

    return
}

// Returns true, if removed entity data from array. Otherwise returns false
//
// **Note**: Removed component associated with given entity
// becomes invalid after removal 
table_bytes_remove_component :: proc (table: ^Table_Bytes, entity: Entity) -> Error {

    if !table_base_entity_is_valid(&table.base, entity) do return .Invalid_Entity
    if !table_bytes_has_entity(table, entity) do return .Entity_Not_Found
    
    entity_to_remove_idx := table.entity_to_idx[entity]
    last_idx := table.size - 1

    bytes_end := entity_to_remove_idx + table.type_info.size
    mem.zero(raw_data(table.bytes_arr[entity_to_remove_idx:bytes_end]), table.type_info.size)

    table.idx_to_rawptr[entity_to_remove_idx] = table.idx_to_rawptr[last_idx]

    last_entity := table.idx_to_entity[last_idx]
    table.entity_to_idx[last_entity] = entity_to_remove_idx
    table.idx_to_entity[entity_to_remove_idx] = last_entity

    table.size -= 1

    raw := (^runtime.Raw_Slice)(&table.bytes_arr)
    raw.len -= 1

    return ERROR_NONE
}

table_bytes_clear :: proc (table: ^Table_Bytes) {

    raw := (^runtime.Raw_Slice)(&table.bytes_arr)
    mem.zero(raw.data, raw.len)

    raw.len = 0

    table.size = 0
}

// Returns true if entity is found. Otherwise false
//
// **Note**: this function expects that given entity is valid
table_bytes_has_entity :: proc (table: ^Table_Bytes, entity:Entity) -> bool {
    if table.entity_to_idx[entity] < table.size && table.idx_to_entity[table.entity_to_idx[entity]] == entity {
        return true
    }
    else do return false
}

free_table_bytes :: proc (table: ^Table_Bytes, loc:=#caller_location) -> Error {
    
    free_table_base(&table.base, loc) or_return

    delete(table.bytes_arr, table.allocator, loc) or_return

    table_bytes_clear(table)

    return ERROR_NONE
}

//////// Component table

Table :: struct($T: typeid) {
    using base: Table_Base,
    comp_arr: []T,
}

table_init :: proc (table: ^Table($T), allocator: runtime.Allocator, table_capacity:=MAX_ENTITIES, loc:=#caller_location) -> Error {

    table_base_init(&table.base, allocator, table_capacity, loc) or_return

    table.type_info = type_info_of(typeid_of(T))

    table.comp_arr = make([]T, table_capacity, allocator, loc) or_return

    table_clear(table)

    return ERROR_NONE
}

// Returns true, if inserted entity data in array. Otherwise returns false
table_add_component :: proc (table: ^Table($T), entity: Entity) -> (component: ^T, err: Error) {

    if !table_base_entity_is_valid(&table.base, entity) do return nil, .Invalid_Entity
    if table_has_entity(table, entity) do return nil, .Already_Has_Entity
    if table.size >= table.capacity do return nil, .Reached_Component_Limit

    raw := (^runtime.Raw_Slice)(&table.comp_arr)

    idx := raw.len

    table.entity_to_idx[entity] = idx
    table.idx_to_entity[idx] = entity

    #no_bounds_check {
        component = &table.comp_arr[idx]
    }
    
    table.idx_to_rawptr[idx] = component
    
    raw.len += 1
    table.size += 1

    return
}

// Returns true, if removed entity data from array. Otherwise returns false
//
// **Note**: Removed component associated with given entity
// becomes invalid after removal 
table_remove_component :: proc (table: ^Table($T), entity: Entity) -> Error {

    return table_bytes_remove_component((^Table_Bytes)(table), entity)
}

// Returns pointer to component and true.
// In case of failure, returns nil and false
table_get_component :: proc (table: ^Table($T), entity: Entity) -> (component:^T, err: Error) {

    if !table_base_entity_is_valid(&table.base, entity) do return nil, .Invalid_Entity
    if !table_has_entity(table, entity) do return nil, .Entity_Not_Found

    return table.idx_to_rawptr[table.entity_to_idx[entity]], true
}

table_clear :: proc (table: ^Table($T)) {

    table_bytes_clear((^Table_Bytes)(table))
}

// Returns true if entity is found. Otherwise false
//
// **Note**: this function expects that given entity is valid
table_has_entity :: proc (table: ^Table($T), entity:Entity) -> bool {

    if table.entity_to_idx[entity] < table.size && table.idx_to_entity[table.entity_to_idx[entity]] == entity {
        return true
    }
    else do return false
}

free_table :: proc (table: ^Table($T), loc:=#caller_location) -> Error {

    free_table_base(&table.base, loc) or_return
    
    delete(table.comp_arr, table.allocator, loc) or_return

    return ERROR_NONE
}
