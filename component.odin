package main

Component :: struct {
    id: typeid,
    ptr: rawptr
}

cast_component_to :: proc ($T: typeid, component: Component, caller_loc:=#caller_location) -> T {
    if component.id == T {
        return cast(T)component
    }
    else {
        panic("ID of given component and desired type do not match", caller_loc)
    }
}
