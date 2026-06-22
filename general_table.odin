package main

General_Table :: struct {
    entity_manager: ^Entity_Manager,
    id: Component_Type,
    table_type: Table_Type
}

free_general_table :: proc (table: ^General_Table) {
    switch table.table_type {
        case .Unknown:
            panic_contextless("Unknown type of a table!")
        case .Table:
            free_table_bytes((^Table_Bytes)(table))
    }
}

Table_Type :: enum {
    Unknown,
    Table,
}

