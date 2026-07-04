package basic

import "base:runtime"

Core_Error :: enum {
    None=0,
    Exceeded_Capacity,
    Out_Of_Bounds,
    Already_Freed,
    Not_Found,
}

Error :: union {
    runtime.Allocator_Error,
    Core_Error,
}

ERROR_NONE :: Error{}
