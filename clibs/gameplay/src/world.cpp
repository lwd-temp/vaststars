#include <lua.hpp>
#include <stdint.h>
#include <stdlib.h>
#include <assert.h>
#include "world.h"
#include "container.h"

#define CONTAINER_TYPE(id)  ((id) & 0x8000)
#define CONTAINER_INDEX(id) ((id) & 0x3FFF)
#define CONTAINER_TYPE_CHEST      0x0000
#define CONTAINER_TYPE_ASSEMBLING 0x8000

template <>
container& world::query_container<container>(uint16_t id) {
    uint16_t idx = CONTAINER_INDEX(id);
    if (CONTAINER_TYPE(id) == CONTAINER_TYPE_CHEST) {
        assert(containers.chest.size() > idx);
        return containers.chest[idx];
    }
    assert(containers.assembling.size() > idx);
    return containers.assembling[idx];
}

template <>
assembling_container& world::query_container<assembling_container>(uint16_t id) {
    uint16_t idx = CONTAINER_INDEX(id);
    assert(CONTAINER_TYPE(id) != CONTAINER_TYPE_CHEST);
    assert(containers.assembling.size() > idx);
    return containers.assembling[idx];
}

template <>
uint16_t world::container_id<chest_container>() {
    return CONTAINER_TYPE_CHEST | (uint16_t)(containers.chest.size()-1);
}

template <>
uint16_t world::container_id<assembling_container>() {
    return CONTAINER_TYPE_ASSEMBLING | (uint16_t)(containers.assembling.size()-1);
}

static int
lcreate_world(lua_State* L) {
	struct world* w = (struct world*)lua_newuserdatauv(L, sizeof(struct world), 0);
	new (w) world;
	w->c.L = L;
	w->c.ecs = (struct ecs_context *)lua_touserdata(L, 1);
	w->c.P = (struct prototype_cache *)lua_touserdata(L, 2);
	return 1;
}

extern "C" __declspec(dllexport) int
luaopen_vaststars_core(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "create_world", lcreate_world },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}
