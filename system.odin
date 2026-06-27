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
    coordinator: ^Coordinator
}

System_Proc :: #type proc (data: ^System_Data) -> (System_Result, Error)

System :: struct {
    signature: Component_Signature,

    data: System_Data,
    fn: System_Proc,
}

system_init :: proc (self: ^System, data: System_Data, signature: Component_Signature, fn: System_Proc) {

    self.fn = fn
    self.data = data
    self.signature = signature

    ent_raw := (^runtime.Raw_Slice)(&self.data.entities)
    ent_raw.len = 0
}

system_reset :: proc (self: ^System) {
    
    self.fn = nil
    
    ent_raw := (^runtime.Raw_Slice)(&self.data.entities)
    ent_raw.len = 0

    slice.zero(self.data.entities)
    self.data.coordinator = nil
}

