#+private
package one_ecs

import "base:runtime"

Basic_Table :: struct {
    type_info: ^runtime.Type_Info,
    variant: union {Table, Tag_Table}
}

basic_table_add :: proc (self: ^Basic_Table, entity: Entity_Id) -> Error {
    switch t in self.variant {
        case Table:     return table_add_component(&self.variant.(Table), entity)
        case Tag_Table: return tag_table_add_component(&self.variant.(Tag_Table), entity)
    }
    return ERROR_NONE
}

// This function will always fail for basic tables which variant is Tag_Table
basic_table_get :: proc (self: ^Basic_Table, entity: Entity_Id) -> (rawptr, Error) {
    switch t in self.variant {
        case Table:     return table_get_component(&self.variant.(Table), entity)
        case Tag_Table: return nil, Registry_Error.Wrong_Table_Type
    }
    return nil, ERROR_NONE
}

basic_table_remove :: proc (self: ^Basic_Table, entity: Entity_Id) -> Error {
    switch t in self.variant {
        case Table:     return table_remove_component(&self.variant.(Table), entity)
        case Tag_Table: return tag_table_remove_component(&self.variant.(Tag_Table), entity)
    }
    return ERROR_NONE
}

basic_table_has :: proc (self: ^Basic_Table, entity: Entity_Id) -> bool {
    switch t in self.variant {
        case Table:     return table_has_component(&self.variant.(Table), entity)
        case Tag_Table: return tag_table_has_component(&self.variant.(Tag_Table), entity)
    }
    return false
}

basic_table_free :: proc (self: ^Basic_Table, loc:=#caller_location) -> Error {
    switch t in self.variant {
        case Table:     return table_free(&self.variant.(Table))
        case Tag_Table: return tag_table_free(&self.variant.(Tag_Table), loc)
    }

    return ERROR_NONE
}
