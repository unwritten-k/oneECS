package main

import "base:runtime"

System_Group :: struct {
    signature: Component_Signature,
    systems: [dynamic]System,

}

System_Manager :: struct {
    system_groups: map[Component_Signature]System_Group,

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
    start_capacity_of_system_arr: int=16, 
    loc:=#caller_location
) -> Error {
    
    mng.allocator = allocator
    
    mng.system_groups = make(map[Component_Signature]System_Group, start_capacity_of_system_arr, allocator) or_return

    mng.biggest_entity = biggest_entity
    mng.system_capacity = system_capacity

    return ERROR_NONE
}

system_manager_reg_system :: proc (mng: ^System_Manager, data: System_Data, fn: System_Proc, signature: Component_Signature, loc:=#caller_location) -> Error {

    system: System
    system_init(&system, data, mng.biggest_entity, mng.system_capacity, signature, fn)

    if system_group, ok := mng.system_groups[signature]; ok {
        append(&system_group.systems, system)
    }
    else {
        mng.system_groups[signature] = System_Group{
            signature,
            make([dynamic]System, 8, mng.allocator, loc)
        }
        append(&system_group.systems, system)
    }

    return ERROR_NONE
}

system_manager_run :: proc (mng: ^System_Manager) {
    for sig, &group in mng.system_groups {
        for &system in group.systems {
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
}

