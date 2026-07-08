package one_ecs

import "base:runtime"

Tag_Table :: struct {}

Basic_Table :: struct {
    type_info: ^runtime.Type_Info,
    variant: union {Table, Tag_Table}
}

basic_table_remove :: proc (self: ^Basic_Table, entity: Entity_Id) -> Error {
    switch t in self.variant {
        case Table: return table_remove_component(&self.variant.(Table), entity)
        case Tag_Table: unimplemented("Tag tables are not implemented yet")
    }
    return ERROR_NONE
}

basic_table_free :: proc (self: ^Basic_Table, loc:=#caller_location) -> Error {
    switch t in self.variant {
        case Table: table_free(&self.variant.(Table))
        case Tag_Table: unimplemented("Tag tables are not implemented yet")
    }

    return ERROR_NONE
}
