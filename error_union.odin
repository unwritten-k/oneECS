package main

import "base:runtime"

Entity_Error :: enum {
    Invalid_Entity,
    No_Available_Entities,
    Too_Much_Entites
}

Table_Error :: enum {
    Already_Has_Entity,
    Entity_Not_Found,
}

Error :: union {
    runtime.Allocator_Error,
    Table_Error,
    Entity_Error,
}

ERROR_NONE :: Error{}

error_to_str :: proc (err: Error) -> (str:string) {

    switch type in err {
        case runtime.Allocator_Error:   str = enum_to_str(err.(runtime.Allocator_Error))
        case Table_Error:               str = enum_to_str(err.(Table_Error))
        case Entity_Error:              str = enum_to_str(err.(Entity_Error))
    }
    return
}

@(private="file")
enum_to_str :: proc (en: any) -> string {
    str, _ := fmt.enum_value_to_string(en)
    return str
}
