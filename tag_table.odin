#+private
package one_ecs

import "base:runtime"
////////////////// DEFINITIONS


@(private="file")
INVALID_ID :: -1

Tag_Table :: struct {
    db: ^Database,
    type_info: ^runtime.Type_Info,

    entity_to_tag: []bool,
    
    t_id: int,
}

// Allocates tag table and attaches it to table
tag_table_init :: proc (self: ^Tag_Table, db: ^Database, type: typeid, loc:=#caller_location) -> Error {
    self.db = db
    self.type_info = type_info_of(type)

    self.entity_to_tag = make([]bool, db.max_entities, db.allocator, loc) or_return

    return ERROR_NONE
}

////////////////// TAG OPERATIONS


// Sets boolean at entity idx to true. Can fail if entity is invalid
tag_table_add_component :: proc (self: ^Tag_Table, entity: Entity_Id) -> Error {
    if !database_entity_is_valid(self.db, entity) do return Collection_Error.Invalid_Entity

    self.entity_to_tag[entity.idx] = true

    return ERROR_NONE
}

// Sets boolean at entity idx to false. Can fail if entity is invalid
tag_table_remove_component :: proc (self: ^Tag_Table, entity: Entity_Id) -> Error {
    if !database_entity_is_valid(self.db, entity) do return Collection_Error.Invalid_Entity

    self.entity_to_tag[entity.idx] = false

    return ERROR_NONE
}

// Returns boolean at entity's idx. True when entity has tag and false when it does not
tag_table_has_component :: proc (self: ^Tag_Table, entity: Entity_Id) -> bool {
    return database_entity_is_valid(self.db, entity) && self.entity_to_tag[entity.idx]
}

// Clears tag table completely
tag_table_clear :: proc (self: ^Tag_Table) {
    for &tag in self.entity_to_tag {
        tag = false
    }
}

////////////////// TAG TABLE FREEING


tag_table_free :: proc (self: ^Tag_Table, loc:=#caller_location) -> Error {
    delete(self.entity_to_tag, self.db.allocator, loc) or_return

    self.t_id = -1

    return ERROR_NONE
}

