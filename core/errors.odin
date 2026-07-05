package basic

import "core:fmt"
import "base:runtime"

Core_Error :: enum {
    None=0,
    Exceeded_Capacity,
    Out_Of_Bounds,
    Already_Freed,
    Not_Found,
}

Error :: union #shared_nil {
    runtime.Allocator_Error,
    Core_Error,
}

ERROR_NONE :: Error {}

error_to_str :: proc (err: Error) -> (str:string) {
    switch t in err {
        case runtime.Allocator_Error:   str = enum_to_str(err.(runtime.Allocator_Error))
        case Core_Error:                str = enum_to_str(err.(Core_Error))
    }
    return
}

@(private="file")
enum_to_str :: proc (e: any) -> string {
    str, _ := fmt.enum_value_to_string(e)
    return str
}
