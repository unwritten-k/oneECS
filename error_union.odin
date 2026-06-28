package main

import "core:fmt"
import "base:runtime"

Entity_Error :: enum {
    None=0,
    Invalid_Entity,
    No_Available_Entities,
    Too_Much_Entities
}

Table_Error :: enum {
    None=0,
    Already_Has_Entity,
    Entity_Not_Found,
    Reached_Component_Limit,
}

Component_Error :: enum {
    None=0,
    Already_Registered,
    Not_Registered,
    Reached_Type_Limit,
}

System_Error :: enum {
    None=0,
    Signatures_Do_Not_Match,
    Reached_System_Capacity,
}

Error :: union {
    runtime.Allocator_Error,
    Table_Error,
    Entity_Error,
    Component_Error,
    System_Error
}

ERROR_NONE :: Error{}

error_to_str :: proc (err: Error) -> (str:string) {

    switch type in err {
        case runtime.Allocator_Error:   str = enum_to_str(err.(runtime.Allocator_Error))
        case Table_Error:               str = enum_to_str(err.(Table_Error))
        case Entity_Error:              str = enum_to_str(err.(Entity_Error))
        case Component_Error:           str = enum_to_str(err.(Component_Error))
        case System_Error:              str = enum_to_str(err.(System_Error))
    }
    return
}

@(private="file")
enum_to_str :: proc (en: any) -> string {
    str, _ := fmt.enum_value_to_string(en)
    return str
}
