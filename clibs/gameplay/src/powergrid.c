#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>
#include <assert.h>
#include <string.h>

#include "luaecs.h"
#include "prototype.h"
#include "world.h"
#include "entity.h"

#define CONSUMER_PRIORITY 2
#define GENERATOR_PRIORITY 2
#define NORMAL_TEMPERATURE 15

struct powergrid {
	float consumer_power[CONSUMER_PRIORITY];
	float generator_power[GENERATOR_PRIORITY];
	float accumulator_output;
	float accumulator_input;
	float solar;
	float consumer_efficiency[CONSUMER_PRIORITY];
	float generator_efficiency[GENERATOR_PRIORITY];
	float accumulator_efficiency;

	struct ecs_context *ecs;
	struct prototype_cache *P;
	lua_State *L;
};

static void
stat_consumer(struct powergrid *pg) {
	int i;
	struct ecs_context *ctx = pg->ecs;
	lua_State *L = pg->L;
	struct prototype_context p = { L, pg->P, 0 };
	for (i=0;entity_iter(pg->ecs, TAG_CONSUMER, i);i++) {
		struct entity *e = entity_sibling(ctx, TAG_CONSUMER, i, COMPONENT_ENTITY);
		if (e == NULL)
			luaL_error(L, "No entity");
		p.id = e->prototype;
		struct capacitance *c = entity_sibling(ctx, TAG_CONSUMER, i, COMPONENT_CAPACITANCE);
		if (c == NULL)
			luaL_error(L, "No capacitance");

		float power = pt_power(&p);
		float charge = c->shortage < power ? c->shortage : power;
		int priority = pt_priority(&p);
		pg->consumer_power[priority] += charge;
//		printf("Charge priority %d %f\n", priority, charge);
	}
}

static void
stat_generator(struct powergrid *pg) {
	struct ecs_context *ctx = pg->ecs;
	lua_State *L = pg->L;
	struct prototype_context p = { L, pg->P, 0 };
	int i;
	for (i=0;entity_iter(ctx, TAG_GENERATOR, i);i++) {
		struct entity *e = entity_sibling(ctx, TAG_GENERATOR, i, COMPONENT_ENTITY);
		if (e == NULL)
			luaL_error(L, "No entity");
		p.id = e->prototype;
		struct capacitance *c = entity_sibling(ctx, TAG_GENERATOR, i, COMPONENT_CAPACITANCE);
		if (c == NULL)
			luaL_error(L, "No capacitance");
		float full_power = pt_power(&p);
		int priority = pt_priority(&p);
		if (c->shortage == 0) {
			// full output
			pg->generator_power[priority] += full_power;
		} else {
			pg->generator_power[priority] += full_power - c->shortage;
		}
	}
}

static void
stat_accumulator(struct powergrid *pg) {
	struct ecs_context *ctx = pg->ecs;
	lua_State *L = pg->L;
	struct prototype_context p = { L, pg->P, 0 };
	int i;
	for (i=0;entity_iter(ctx, TAG_ACCUMULATOR, i);i++) {
		struct entity *e = entity_sibling(ctx, TAG_ACCUMULATOR, i, COMPONENT_ENTITY);
		if (e == NULL)
			luaL_error(L, "No entity");
		p.id = e->prototype;
		struct capacitance *c = entity_sibling(ctx, TAG_ACCUMULATOR, i, COMPONENT_CAPACITANCE);
		if (c == NULL)
			luaL_error(L, "No capacitance");
		float power = pt_power(&p);
		if (c->shortage == 0) {
			// battery is full
			pg->accumulator_output += power;
		} else {
			float charge_power = pt_charge_power(&p);
			pg->accumulator_input += (c->shortage <= charge_power) ? c->shortage : charge_power;
			float battery_remain = pt_battery(&p) - c->shortage;
			pg->accumulator_output += (battery_remain <= power) ? battery_remain : power;
		}
	}
}

static void
calc_efficiency(struct powergrid *pg) {
	// todo : solar
	int i;
	float need_power = 0;
	for (i=0;i<CONSUMER_PRIORITY;i++) {
		need_power += pg->consumer_power[i];
	}
	float offer_power = 0;
	for (i=0;i<GENERATOR_PRIORITY;i++) {
		offer_power += pg->generator_power[i];
	}
	if (need_power > offer_power) {
		// power is not enough, all generator efficiency are 100%
		for (i=0;i<GENERATOR_PRIORITY;i++) {
			pg->generator_efficiency[i] = 1.0f;
		}

		need_power -= offer_power;
		// accumulator output
		if (need_power >= pg->accumulator_output) {
			if (pg->accumulator_output == 0) {
				pg->accumulator_efficiency = 0;
			} else {
				pg->accumulator_efficiency = 1.0f;
				offer_power += pg->accumulator_output;
			}
			for (i=0;i<CONSUMER_PRIORITY;i++) {
				if (offer_power == 0) {
					// no power
					pg->consumer_efficiency[i] = 0;
				} else if (offer_power >= pg->consumer_power[i]) {
					// P[i] is satisfied
					pg->consumer_efficiency[i] = 1.0f;
					offer_power -= pg->consumer_power[i];
				} else {
					pg->consumer_efficiency[i] = offer_power / pg->consumer_power[i];
					offer_power = 0;
				}
			}
		} else {
			pg->accumulator_efficiency = need_power / pg->accumulator_output;
			// power is enough now.
			for (i=0;i<CONSUMER_PRIORITY;i++) {
				pg->consumer_efficiency[i] = 1.0f;
			}
		}
	} else {
		// power is enough, all consumer efficiency are 100%
		for (i=0;i<CONSUMER_PRIORITY;i++) {
			pg->consumer_efficiency[i] = 1.0f;
		}
		offer_power -= need_power;
		// charge accumulators
		if (offer_power >= pg->accumulator_input) {
			if (pg->accumulator_input == 0) {
				pg->accumulator_efficiency = 0;
			} else {
				pg->accumulator_efficiency = -1.0f;
				need_power += pg->accumulator_input;
			}
			for (i=0;i<GENERATOR_PRIORITY;i++) {
				if (need_power == 0) {
					// Don't need power yet
					pg->generator_efficiency[i] = 0;
				} else if (need_power >= pg->generator_power[i]) {
					// P[i] should full output
					pg->generator_efficiency[i] = 1.0f;
					need_power -= pg->generator_power[i];
				} else {
					pg->generator_efficiency[i] = need_power / pg->generator_power[i];
					need_power = 0;
				}
			}
		} else {
			pg->accumulator_efficiency = -offer_power / pg->accumulator_input;
			// part charge, generators full output
			for (i=0;i<GENERATOR_PRIORITY;i++) {
				pg->generator_efficiency[i] = 1.0f;
			}
		}
	}
}

static void
powergrid_run(struct powergrid *pg) {
	struct ecs_context *ctx = pg->ecs;
	lua_State *L = pg->L;
	struct prototype_context p = { L, pg->P, 0 };
	int i;
	struct capacitance * c;
	for (i=0;(c = entity_iter(ctx, COMPONENT_CAPACITANCE, i));i++) {
		struct entity *e = entity_sibling(ctx, COMPONENT_CAPACITANCE, i, COMPONENT_ENTITY);
		if (e == NULL)
			luaL_error(L, "No entity");
		p.id = e->prototype;
		if (entity_sibling(ctx, COMPONENT_CAPACITANCE, i, TAG_CONSUMER)) {
			// It's a consumer, charge capacitance
			if (c->shortage > 0) {
				float eff = pg->consumer_efficiency[pt_priority(&p)];
				if (eff > 0) {
					// charge
					float power = pt_power(&p);
					if (c->shortage <= power) {
						if (eff >= 1.0f) {
							c->shortage = 0;	// full charge
						} else {
							c->shortage *= (1 - eff);
						}
					} else {
						c->shortage -= power * eff;
					}
				}
			}
		} else if (entity_sibling(ctx, COMPONENT_CAPACITANCE, i, TAG_GENERATOR)) {
			// It's a generator, and must be not a consumer
			float eff = pg->generator_efficiency[pt_priority(&p)];
			if (eff > 0) {
				float consume_energy = pt_power(&p) / pt_efficiency(&p) * eff;
				c->shortage += consume_energy;
			}
		} else if (pg->accumulator_efficiency != 0 &&
			entity_sibling(ctx, COMPONENT_CAPACITANCE, i, TAG_ACCUMULATOR)) {
			float eff = pg->accumulator_efficiency;
			if (eff > 0) {
				// discharge
				float battery = pt_battery(&p); 
				float remain = battery - c->shortage;
				float power = pt_power(&p) * eff;
				if (remain >= power) {
					c->shortage += power;
				} else {
					c->shortage = battery;
				}
			} else {
				// charge
				eff = -eff;
				float charge_power = pt_charge_power(&p) * eff;
				if (charge_power >= c->shortage) {
					c->shortage = 0;
				} else {
					c->shortage -= charge_power;
				}
			}
		}
	}
}

static int
lupdate(lua_State *L) {
	struct powergrid pg;
	// step 1: init powergrid runtime struct
	memset(&pg, 0, sizeof(pg));
	struct world* w = (struct world *)lua_touserdata(L, 1);
	pg.ecs = w->ecs;
	pg.P = w->P;
	// todo : get from ecs (G)
	pg.L = w->L;

	// step 2: stat consumers in powergrid
	stat_consumer(&pg);
	// step 3: stat generators
	stat_generator(&pg);
	// step 4: stat accumulators
	stat_accumulator(&pg);
	// step 5: calc efficiency
	calc_efficiency(&pg);
	// step 6: powergrid charge consumers' capacitance, and consume generators' capacitance
	powergrid_run(&pg);

	return 0;
}

LUAMOD_API int
luaopen_vaststars_powergrid_system(lua_State *L) {
	luaL_checkversion(L);

	luaL_Reg l[] = {
		{ "update", lupdate },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}