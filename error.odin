package one_ecs

import "core:fmt"
import "base:runtime"
import core "core"

Collection_Error :: enum {
    None=0,
    Invalid_Entity,
    Entity_Not_Found,
    Already_Added,
    Exceeded_Capacity,
}

Registry_Error :: enum {
    None=0,
    Already_Registered,
    Not_Registered,
    Wrong_Table_Type,
}

Error :: union #shared_nil {
    runtime.Allocator_Error,
    core.Error,
    core.Core_Error,
    Collection_Error,
    Registry_Error,
}

ERROR_NONE :: Error{}

error_to_str :: proc (err: Error) -> (str: string) {
    str = "None"
    switch t in err {
        case runtime.Allocator_Error:   str = enum_to_str(err.(runtime.Allocator_Error))
        case core.Error:                str = core.error_to_str(err.(core.Error))
        case core.Core_Error:           str = enum_to_str(err.(core.Core_Error))
        case Collection_Error:          str = enum_to_str(err.(Collection_Error))
        case Registry_Error:            str = enum_to_str(err.(Registry_Error))
    }
    return
}

@(private="file")
enum_to_str :: proc (e: any) -> string {
    str, _ := fmt.enum_value_to_string(e)
    return str
}
