package main

import "base:runtime"

System_Manager :: struct {
    systems: [dynamic]System,

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
    
    mng.systems = make([dynamic]System, start_capacity_of_system_arr, allocator) or_return

    mng.biggest_entity = biggest_entity
    mng.system_capacity = system_capacity

    return ERROR_NONE
}

system_manager_reg_system :: proc (
    mng: ^System_Manager,

    coordinator: ^Coordinator,

    fn: System_Proc,
    signature: Component_Signature, 
    loc:=#caller_location
) -> Error {
    
    data: System_Data
    data.coordinator = coordinator
    data.entities = make([]Entity, mng.system_capacity, mng.allocator)
    data.ent_to_idx = make([]int, mng.biggest_entity, mng.allocator)

    system: System
    system_init(&system, data, mng.biggest_entity, mng.system_capacity, signature, fn)

    append(&mng.systems, system)

    return ERROR_NONE
}

system_manager_run :: proc (mng: ^System_Manager) {
    for &system in mng.systems {
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

system_manager_entity_sign_changed :: proc (mng: ^System_Manager, entity: Entity, new_signature: Component_Signature) {
    for &system in mng.systems {
        err := system_signature_changed(&system, entity, new_signature)

        if err != ERROR_NONE {
            system.dead = true
            if mng.failure_proc != nil do mng.failure_proc(err, &system)
        }
    }
}

system_manager_entity_destroyed :: proc (mng: ^System_Manager, entity: Entity) {
    for &system in mng.systems {
        system_entity_destroyed(&system, entity)
    }
}

free_system_manager :: proc (mng: ^System_Manager, loc:=#caller_location) -> Error {
    for &sys in mng.systems {
        system_reset(&sys)

        delete(sys.data.entities, mng.allocator, loc) or_return
        delete(sys.data.ent_to_idx, mng.allocator, loc) or_return
    }

    delete(mng.systems, loc) or_return

    mng.biggest_entity = 0
    mng.system_capacity = 0

    return ERROR_NONE
}

