package main

import "base:runtime"

System_Manager :: struct {
    systems: map[Component_Signature]System,

    failure_proc: proc (err: Error, system: ^System),

    biggest_entity: int,
    system_capacity: int,

    allocator: runtime.Allocator,
}

system_manager_init :: proc (
    mng: ^System_Manager, 
    allocator: runtime.Allocator, 
    biggest_entity: int, 
    system_capacity: int, 
    start_capacity_of_system_arr: int, 
    loc:=#caller_location
) -> Error {
    
    mng.allocator = allocator
    
    mng.systems = make(map[Component_Signature]System, start_capacity_of_system_arr, allocator) or_return

    mng.biggest_entity = biggest_entity
    mng.system_capacity = system_capacity

    return ERROR_NONE
}

system_manager_reg_system :: proc (mng: ^System_Manager, data: System_Data, fn: System_Proc, signature: Component_Signature) -> Error {

    system: System
    system_init(&system, data, mng.biggest_entity, mng.system_capacity, signature, fn)

    mng.systems[signature] = system

    return ERROR_NONE
}

system_manager_run :: proc (mng: ^System_Manager) {
    for sig, &system in mng.systems {
        if system.dead do continue

        res, err := system.fn(&system.data)
        switch res {
            case .Continue: continue
            case .Terminate: system.dead = true
            case .Error: {
                system.dead = true
                if mng.failure_proc != nil do mng.failure_proc(err, &system)
            }
        }
    }
}

