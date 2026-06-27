package main

MAX_COMPONENTS :: #config(MAX_COMPONENTS, 32)
DEFAULT_MAX_ENTITIES :: #config(DEFAULT_MAX_ENTITIES, 1024)

ERROR_ENTITY :: -1
Entity :: i32

ERROR_COMPONENT :: -1
Component_Type :: int
Component_Signature :: bit_set[0..<MAX_COMPONENTS; u32]

