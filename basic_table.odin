package one_ecs

Table_Type :: enum {
    Table,
    Tag_Table,
}

Basic_Table_Operation :: enum {
    Add,
    Remove,
    Get,
    Clear,
}

Basic_Table :: struct {
    db: ^Database,
    table_type: Table_Type,
    table_proc: proc (op:Basic_Table_Operation, table:^Basic_Table, entity:Entity_Id) -> (rawptr, Error)
}

basic_table_add :: proc (self: ^Basic_Table, entity: Entity_Id) -> (rawptr, Error) {
    return self.table_proc(.Add, self, entity)
}

basic_table_remove :: proc (self: ^Basic_Table, entity: Entity_Id) -> Error {
    _, err := self.table_proc(.Remove, self, entity)
    return err
}

basic_table_get :: proc (self: ^Basic_Table, entity: Entity_Id) -> (rawptr, Error) {
    return self.table_proc(.Get, self, entity)
}

basic_table_clear :: proc (self: ^Basic_Table) {
    self.table_proc(.Clear, self, Entity_Id{})
}

basic_table_free :: proc (self: ^Basic_Table, loc:=#caller_location) -> Error {
    switch self.table_type {
        case .Table: table_free( (^Table)(self), loc )
        case .Tag_Table: unimplemented("Tag Tables are not implemented yet")
    }

    return ERROR_NONE
}
