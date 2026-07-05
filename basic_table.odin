package one_ecs

Table_Type :: enum {
    Table,
    Tag_Table,
}

Basic_Table :: struct {
    db: ^Database,
    table_type: Table_Type,
}

basic_table_free :: proc (self: ^Basic_Table, loc:=#caller_location) -> Error {
    switch self.table_type {
        case .Table: table_bytes_free( (^Table_Bytes)(self), loc )
        case .Tag_Table: unimplemented("Tag Tables are not implemented yet")
    }

    return ERROR_NONE
}
