package main

import "core:slice"
import "base:runtime"

System_Result :: enum {
    Continue=0,
    Terminate,
    Error,
}

System_Data :: struct {
    entities: []Entity,
    ent_to_idx: [/*Entity*/]int,
    coordinator: ^Coordinator
}

System_Proc :: #type proc (data: ^System_Data) -> (System_Result, Error)

System :: struct {
    signature: Component_Signature,

    biggest_entity: int,
    capacity: int,

    data: System_Data,
    fn: System_Proc,

    alive: bool,
}

system_init :: proc (self: ^System, data: System_Data, biggest_entity:int, capacity:int, signature: Component_Signature, fn: System_Proc) {

    self.fn = fn
    self.data = data
    self.signature = signature

    ent_raw := (^runtime.Raw_Slice)(&self.data.entities)
    ent_raw.len = 0
}

@private
system_add_entity :: proc (self: ^System, entity: Entity) -> Error {
    if !system_entity_is_valid(self, entity) do return .Invalid_Entity
    if len(self.data.entities) + 1 >= self.capacity do return .Reached_System_Capacity

    raw := (^runtime.Raw_Slice)(&self.data.entities)

    idx := len(self.data.entities)
    self.data.ent_to_idx[entity] = idx
    self.data.entities[idx] = entity

    raw.len += 1

    return ERROR_NONE
}

system_signature_changed :: proc (self: ^System, entity: Entity, new_signature: Component_Signature) -> Error {
    if do_signatures_match(new_signature, self.signature) {
        if !system_has_entity(self, entity) {
            return system_add_entity(self, entity)
        }
        else do return ERROR_NONE
    }

    system_entity_destroyed(self, entity)
    return ERROR_NONE
}

system_entity_destroyed :: proc (self: ^System, entity: Entity) {
    if !system_entity_is_valid(self, entity) do return
    if !system_has_entity(self, entity) do return

    last_idx := len(self.data.entities) - 1
    last_entity := self.data.entities[last_idx]

    to_replace_idx := self.data.ent_to_idx[entity]

    self.data.entities[to_replace_idx] = self.data.entities[last_idx]

    self.data.ent_to_idx[last_entity] = to_replace_idx
    self.data.ent_to_idx[entity] = len(self.data.entities)

    raw := (^runtime.Raw_Slice)(&self.data.entities)
    raw.len -= 1
}

system_reset :: proc (self: ^System) {
    
    self.alive = false
    self.fn = nil
    
    ent_raw := (^runtime.Raw_Slice)(&self.data.entities)
    ent_raw.len = 0

    slice.zero(self.data.entities)
    self.data.coordinator = nil
}

system_entity_is_valid :: proc (self: ^System, entity: Entity) -> bool {
    return entity >= 0 && entity < Entity(self.biggest_entity)
}

system_has_entity :: #force_inline proc"contextless" (self: ^System, entity: Entity) -> bool #no_bounds_check {
    return self.data.entities[self.data.ent_to_idx[entity]] == entity
}

