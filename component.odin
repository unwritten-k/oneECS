package main

MAX_COMPONENTS :: #config(MAX_COMPONENTS, 32)

Component_Id :: u8

Component_Signature :: bit_set[0..<MAX_COMPONENTS; u32]
