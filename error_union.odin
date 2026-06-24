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
