#include <lua.hpp>
#include "world.h"
#include "fluid.h"

extern "C" {
    #include "fluidflow.h"
}

fluidflow::fluidflow()
: network(fluidflow_new())
{}

fluidflow::~fluidflow() {
	fluidflow_delete(network);
}

uint16_t fluidflow::build(struct fluid_box *box) {
	uint16_t newid = 0;
	if (freelist.empty()) {
		if (maxid >= 0xFFFF) {
			return 0;
		}
		newid = ++maxid;
	}
	else {
		newid = freelist.back();
		freelist.pop_back();
	}
	box->capacity *= multiple;
	box->height *= multiple;
	box->base_level *= multiple;
	box->pumping_speed *= multiple;
	if (fluidflow_build(network, newid, box)) {
		freelist.push_back(newid);
		return 0;
	}
	return newid;
}

bool fluidflow::rebuild(uint16_t id) {
	fluid_state state;
	if (!fluidflow_query(network, id, &state)) {
		return false;
	}
	int r;
	r = fluidflow_teardown(network, id);
	assert(r == 0); (void)r;
	r = fluidflow_build(network, id, &state.box);
	assert(r == 0); (void)r;
	r = fluidflow_set(network, id, state.volume, 1);
	assert(r == 0); (void)r;
	return true;
}

bool fluidflow::restore(uint16_t id, struct fluid_box *box) {
	if (id <= maxid) {
		freelist.erase(std::remove_if(freelist.begin(), freelist.end(),
			[=](uint16_t x) {
				return x == id;
			}
		), freelist.end());
	}
	else {
		for (auto i = maxid + 1; i < id; ++i) {
			freelist.push_back(i);
		}
		maxid = id;
	}
	box->capacity *= multiple;
	box->height *= multiple;
	box->base_level *= multiple;
	box->pumping_speed *= multiple;
	if (fluidflow_build(network, id, box)) {
		freelist.push_back(id);
		return false;
	}
	return true;
}

bool fluidflow::teardown(int id) {
	if (0 == fluidflow_teardown(network, id)) {
		freelist.push_back(id);
		return true;
	}
	return false;
}

bool fluidflow::connect(int from, int to, bool oneway) {
	return 0 == fluidflow_connect(network, from, to, oneway? 1: 0);
}

void fluidflow::dump() {
	fluidflow_dump(network);
}

bool fluidflow::query(int id, fluid_state& state) {
	if (!fluidflow_query(network, id, &state)) {
		return false;
	}
	return true;
}

void fluidflow::block(int id) {
	fluidflow_block(network, id);
}

void fluidflow::update() {
	fluidflow_update(network);
}

void fluidflow::set(int id, int fluid) {
	int r = fluidflow_set(network, id, fluid, multiple);
	assert(r != -1);
}

void fluidflow::set(int id, int fluid, int user_multiple) {
	int r = fluidflow_set(network, id, fluid, user_multiple);
	assert(r != -1);
}

static int
lupdate(lua_State *L) {
	world& w = *(world*)lua_touserdata(L, 1);
	for (auto& [_,f] : w.fluidflows) {
		f.update();
	}
	for (auto& e : w.select<fluidboxes, assembling>()) {
		assembling& a = e.get<assembling>();
		if (a.recipe != 0) {
			fluidboxes& fb = e.get<fluidboxes>();
			recipe_container& container = w.query_container<recipe_container>(a.container);
			for (size_t i = 0; i < 4; ++i) {
				uint16_t fluid = fb.in[i].fluid;
				if (fluid != 0) {
					auto& f = w.fluidflows[fluid];
					uint8_t index = ((a.fluidbox_in >> (i*4)) & 0xF) - 1;
					fluid_state state;
					if (f.query(fb.in[i].id, state)) {
						container.recipe_set(recipe_container::slot_type::in, index, state.volume / f.multiple);
					}
				}
			}
			for (size_t i = 0; i < 3; ++i) {
				uint16_t fluid = fb.out[i].fluid;
				if (fluid != 0) {
					auto& f = w.fluidflows[fluid];
					uint8_t index = ((a.fluidbox_out >> (i*4)) & 0xF) - 1;
					fluid_state state;
					if (f.query(fb.out[i].id, state)) {
						container.recipe_set(recipe_container::slot_type::out, index, state.volume / f.multiple);
					}
				}
			}
		}
	}
	return 0;
}

static int
lfluidflow_build(lua_State *L) {
	world& w = *(world*)lua_touserdata(L, 1);
	uint16_t fluid = (uint16_t)luaL_checkinteger(L, 2);
	int capacity = (int)luaL_checkinteger(L, 3);
	int height = (int)luaL_checkinteger(L, 4);
	int base_level = (int)luaL_checkinteger(L, 5);
	int pumping_speed = (int)luaL_optinteger(L, 6, 0);
	fluid_box box {
		.capacity = capacity,
		.height = height,
		.base_level = base_level,
		.pumping_speed = pumping_speed,
	};
	uint16_t id = w.fluidflows[fluid].build(&box);
	if (id == 0) {
		return luaL_error(L, "fluidflow build failed.");
	}
	lua_pushinteger(L, id);
	return 1;
}

static int
lfluidflow_rebuild(lua_State *L) {
	world& w = *(world*)lua_touserdata(L, 1);
	uint16_t fluid = (uint16_t)luaL_checkinteger(L, 2);
	uint16_t id = (uint16_t)luaL_checkinteger(L, 3);
	w.fluidflows[fluid].rebuild(id);
	return 0;
}

static int
lfluidflow_restore(lua_State *L) {
	world& w = *(world*)lua_touserdata(L, 1);
	uint16_t fluid = (uint16_t)luaL_checkinteger(L, 2);
	uint16_t id = (uint16_t)luaL_checkinteger(L, 3);
	int capacity = (int)luaL_checkinteger(L, 4);
	int height = (int)luaL_checkinteger(L, 5);
	int base_level = (int)luaL_checkinteger(L, 6);
	int pumping_speed = (int)luaL_optinteger(L, 7, 0);
	fluid_box box {
		.capacity = capacity,
		.height = height,
		.base_level = base_level,
		.pumping_speed = pumping_speed,
	};
	bool ok = w.fluidflows[fluid].restore(id, &box);
	if (!ok) {
		return luaL_error(L, "fluidflow restore failed.");
	}
	return 0;
}

static int
lfluidflow_teardown(lua_State *L) {
	world& w = *(world*)lua_touserdata(L, 1);
	uint16_t fluid = (uint16_t)luaL_checkinteger(L, 2);
	uint16_t id = (uint16_t)luaL_checkinteger(L, 3);
	bool ok = w.fluidflows[fluid].teardown(id);
	if (!ok) {
		return luaL_error(L, "fluidflow teardown failed.");
	}
	return 0;
}

static int
lfluidflow_connect(lua_State *L) {
	world& w = *(world*)lua_touserdata(L, 1);
	uint16_t fluid = (uint16_t)luaL_checkinteger(L, 2);
	fluidflow& flow = w.fluidflows[fluid];
	luaL_checktype(L, 3, LUA_TTABLE);
	lua_Integer n = luaL_len(L, 3);
	for (lua_Integer i = 1; i+2 <= n; i += 3) {
		lua_rawgeti(L, 3, i);
		lua_rawgeti(L, 3, i+1);
		lua_rawgeti(L, 3, i+2);
		uint16_t from = (uint16_t)luaL_checkinteger(L, -3);
		uint16_t to = (uint16_t)luaL_checkinteger(L, -2);
		bool oneway = !!lua_toboolean(L, -1);
		bool ok =  flow.connect(from, to, oneway);
		if (!ok) {
			return luaL_error(L, "fluidflow connect failed.");
		}
		lua_pop(L, 3);
	}
	return 0;
}

static int
lfluidflow_query(lua_State *L) {
	world& w = *(world*)lua_touserdata(L, 1);
	uint16_t fluid = (uint16_t)luaL_checkinteger(L, 2);

	auto& f = w.fluidflows[fluid];
	uint16_t id = (uint16_t)luaL_checkinteger(L, 3);
	fluid_state state;
	if (!f.query(id, state)) {
		return luaL_error(L, "fluidflow query failed.");
	}
	lua_createtable(L, 0, 7);
	lua_pushinteger(L, f.multiple);
	lua_setfield(L, -2, "multiple");
	lua_pushinteger(L, state.volume);
	lua_setfield(L, -2, "volume");
	lua_pushinteger(L, state.flow);
	lua_setfield(L, -2, "flow");
	lua_pushinteger(L, state.box.capacity);
	lua_setfield(L, -2, "capacity");
	lua_pushinteger(L, state.box.height);
	lua_setfield(L, -2, "height");
	lua_pushinteger(L, state.box.base_level);
	lua_setfield(L, -2, "base_level");
	lua_pushinteger(L, state.box.pumping_speed);
	lua_setfield(L, -2, "pumping_speed");
	return 1;
}

static int
lfluidflow_set(lua_State *L) {
	world& w = *(world*)lua_touserdata(L, 1);
	uint16_t fluid = (uint16_t)luaL_checkinteger(L, 2);

	auto& f = w.fluidflows[fluid];
	uint16_t id = (uint16_t)luaL_checkinteger(L, 3);
	int value = (int)luaL_checkinteger(L, 4);
	int multiple = (int)luaL_optinteger(L, 5, f.multiple);
	f.set(id, value, multiple);
	return 0;
}

static int
lfluidflow_dump(lua_State *L) {
	world& w = *(world*)lua_touserdata(L, 1);
	uint16_t fluid = (uint16_t)luaL_checkinteger(L, 2);
	w.fluidflows[fluid].dump();
	return 0;
}

extern "C" int
luaopen_vaststars_fluidflow_core(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "build", lfluidflow_build },
		{ "restore", lfluidflow_restore },
		{ "teardown", lfluidflow_teardown },
		{ "connect", lfluidflow_connect },
		{ "query", lfluidflow_query },
		{ "set", lfluidflow_set },
		{ "rebuild", lfluidflow_rebuild },
		{ "dump", lfluidflow_dump },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}

extern "C" int
luaopen_vaststars_fluid_system(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "update", lupdate },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}
