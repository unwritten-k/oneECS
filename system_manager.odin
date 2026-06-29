package main

import "base:runtime"

System_Failure_Proc :: proc (err: Error, system: ^System)

System_Manager :: struct {
    systems: [dynamic]System,

    failure_proc: System_Failure_Proc,

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
    
    mng.systems = make([dynamic]System, 0, start_capacity_of_system_arr, allocator) or_return

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
        if system.dead || !system.initialized do continue

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
        if !system.initialized do continue

        err := system_signature_changed(&system, entity, new_signature)

        if err != ERROR_NONE {
            system.dead = true
            if mng.failure_proc != nil do mng.failure_proc(err, &system)
        }
    }
}

system_manager_entity_destroyed :: proc (mng: ^System_Manager, entity: Entity) {
    for &system in mng.systems {
        if !system.initialized do continue

        system_entity_destroyed(&system, entity)
    }
}

@private
// Accepts system id to update and signatures array,
// where index is Entity and Value is Component_Signature.
// Array as such is stored in Entity_Manager
system_manager_update_entities :: proc (mng: ^System_Manager, sys_id: int, signatures: [/*Entity*/]Component_Signature) -> Error {
    if sys_id < 0 || sys_id >= len(mng.systems) do return .Invalid_System_Id
    
    system := &mng.systems[sys_id]

    for sign, ent in signatures {
        if sign == nil do continue
        
        if do_signatures_match(sign, system.signature) {
            system_add_entity(system, Entity(ent)) or_return
        }
    }

    return ERROR_NONE
}

free_system_manager :: proc (mng: ^System_Manager, loc:=#caller_location) -> Error {
    for &sys in mng.systems {
        if !sys.initialized do continue

        system_reset(&sys)

        delete(sys.data.entities, mng.allocator, loc) or_return
        delete(sys.data.ent_to_idx, mng.allocator, loc) or_return
    }

    delete(mng.systems, loc) or_return

    mng.biggest_entity = 0
    mng.system_capacity = 0

    return ERROR_NONE
}

