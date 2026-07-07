package basic

import "core:testing"
import "base:runtime"

INVALID_IDX :: -1
MAX_GEN :: 255

Entity_Id :: bit_field i64 {
    idx: int | 56,
    gen: uint | 8,
}

Entity_Factory :: struct {
    allocator: runtime.Allocator,

    capacity: int,
    alive_ids: []Entity_Id,
    created_count: int,

    freed_ids: []int,
    freed_count: int,
}

entity_factory_init :: proc (self: ^Entity_Factory, cap: int, allocator: runtime.Allocator, loc:=#caller_location) -> Error {
    self.allocator = allocator
    self.capacity = cap
    
    self.alive_ids = make([]Entity_Id, cap, allocator, loc) or_return
    self.freed_ids = make([]int, cap, allocator, loc) or_return

    entity_factory_clear(self)

    return ERROR_NONE
}

entity_factory_clear :: proc (self: ^Entity_Factory) {
    for i in 0..<self.capacity {
        self.alive_ids[i].idx = INVALID_IDX
        self.alive_ids[i].gen = 0

        self.freed_ids[i] = INVALID_IDX
    }

    self.created_count = 0
    self.freed_count = 0
}

entity_factory_create_id :: proc (self: ^Entity_Factory) -> (id: Entity_Id, err: Error) {

    if entity_factory_len(self) >= self.capacity {
        id.idx = INVALID_IDX
        err = .Exceeded_Capacity
        return
    }

    id_ptr: ^Entity_Id

    if self.freed_count > 0 {
        self.freed_count -= 1

        idx := self.freed_ids[self.freed_count]
        self.freed_ids[self.freed_count] = INVALID_IDX

        id_ptr = &self.alive_ids[idx]
        id_ptr.gen = id_ptr.gen+1 if id_ptr.gen<MAX_GEN else 0
        id_ptr.idx = idx

        id = id_ptr^

    }
    else {
        id_ptr = &self.alive_ids[self.created_count]

        id_ptr.idx = self.created_count

        id = id_ptr^

        self.created_count += 1
    }

    return
}

entity_factory_is_expired :: #force_inline proc "contextless" (self: ^Entity_Factory, id: Entity_Id) -> bool {
    if id.idx < 0 || id.idx > self.capacity do return true

    return self.alive_ids[id.idx] != id
}

entity_factory_is_freed :: #force_inline proc "contextless" (self: ^Entity_Factory, id: Entity_Id) -> bool {
    return self.alive_ids[id.idx].idx == INVALID_IDX
}

entity_factory_len :: #force_inline proc "contextless" (self: ^Entity_Factory) -> int {
    return self.created_count - self.freed_count
}

entity_factory_free_id :: proc (self: ^Entity_Factory, id: Entity_Id) -> Error {
    if self.freed_count >= self.capacity do return .Exceeded_Capacity
    if id.idx < 0 || id.idx > self.capacity do return .Out_Of_Bounds
    if self.alive_ids[id.idx] != id do return .Not_Found
    if entity_factory_is_freed(self, id) do return .Already_Freed

    self.alive_ids[id.idx].idx = INVALID_IDX
    self.freed_ids[self.freed_count] = id.idx
    self.freed_count += 1

    return ERROR_NONE
}

entity_factory_free :: proc (self: ^Entity_Factory, loc:=#caller_location) -> Error {
    delete(self.alive_ids, self.allocator, loc) or_return
    delete(self.freed_ids, self.allocator, loc) or_return
    
    self.created_count = 0
    self.freed_count = 0
    self.capacity = 0
    
    self.allocator = {}

    return ERROR_NONE
}


@test
entity_factory_test :: proc (_: ^testing.T) {
    factory: Entity_Factory
    err : Error
    
    err = entity_factory_init(&factory, 10, context.allocator)
    assert(err == ERROR_NONE, error_to_str(err))
    context.allocator = runtime.panic_allocator() // no allocations should be made after factory init

    defer assert(  entity_factory_free(&factory) == ERROR_NONE  )

    first_id: Entity_Id
    first_id, err = entity_factory_create_id(&factory)
    assert(err == ERROR_NONE, error_to_str(err))
    assert(first_id.idx == 0 && first_id.gen == 0)
    assert(!entity_factory_is_expired(&factory, first_id)) // first_id cannot be expired yet

    second_id: Entity_Id
    second_id, err = entity_factory_create_id(&factory)
    assert(err == ERROR_NONE, error_to_str(err))
    assert(second_id.idx == 1 && second_id.gen == 0) // second_id should be the same generation as first
    assert(!entity_factory_is_expired(&factory, second_id)) // second_id cannot be expired yet

    err = entity_factory_free_id(&factory, first_id)
    assert(err == ERROR_NONE, error_to_str(err))
    assert(entity_factory_is_freed(&factory, first_id)) // this should be true after first_id is freed

    third_id: Entity_Id
    third_id, err = entity_factory_create_id(&factory) // here, first_id should be reused
    assert(err == ERROR_NONE, error_to_str(err))
    assert(third_id.idx == 0 && third_id.gen == 1)

    assert(entity_factory_is_expired(&factory, first_id)) // so after reuse first_id expires
}
