package main

import "core:strings"
import "core:fmt"

BCOLORS_FAIL :: "\033[91m"
BCOLORS_WARN :: "\033[93m"

print_error :: #force_inline proc (fmt_reason: string, args: ..any) {
    str := strings.concatenate( []string{BCOLORS_FAIL, fmt_reason} )
    defer delete(str)
    fmt.eprintfln(str, args)
}

print_warn :: #force_inline proc (fmt_reason: string, args: ..any) {
    str := strings.concatenate( []string{BCOLORS_WARN, fmt_reason} )
    defer delete(str)
    fmt.eprintfln(str, args)
}
