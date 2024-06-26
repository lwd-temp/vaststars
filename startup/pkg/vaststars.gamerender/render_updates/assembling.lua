local ecs = ...
local world = ecs.world
local w = world.w

local CONSTANT <const> = require "gameplay.interface.constant"
local TILE_SIZE <const> = CONSTANT.TILE_SIZE
local RENDER_LAYER <const> = ecs.require("engine.render_layer").RENDER_LAYER
local ICON_STATUS_NOPOWER <const> = 1
local ICON_STATUS_NORECIPE <const> = 2
local ICON_STATUS_RECIPE <const> = 3
local ROTATORS <const> = {
    N = math.rad(0),
    E = math.rad(-90),
    S = math.rad(-180),
    W = math.rad(-270),
}

local serialize = import_package "ant.serialize"
local RECIPES_CFG <const> = serialize.load "/pkg/vaststars.resources/config/canvas/recipes.ant"

local assembling_sys = ecs.system "assembling_system"
local objects = require "objects"
local global = require "global"
local iprototype = require "gameplay.interface.prototype"
local create_io_shelves = ecs.require "render_updates.common.io_shelves".create
local assetmgr = import_package "ant.asset"
local icanvas = ecs.require "engine.canvas"
local irecipe = require "gameplay.interface.recipe"
local gameplay_core = require "gameplay.core"
local interval_call = ecs.require "engine.interval_call"
local draw_fluid_icon = ecs.require "fluid_icon"
local ipower_check = ecs.require "power_check_system"
local ichest = require "gameplay.interface.chest"
local math3d = require "math3d"
local vsobject_manager = ecs.require "vsobject_manager"
local renew_assembling_fluid_port = ecs.require "render_updates.assembling_fluid_port".renew
local remove_assembling_fluid_port = ecs.require "render_updates.assembling_fluid_port".remove

local function _get_texture_size(materialpath)
    local res = assetmgr.resource(materialpath)
    local texobj = assetmgr.resource(res.properties.s_basecolor.texture)
    local ti = texobj.texinfo
    return tonumber(ti.width), tonumber(ti.height)
end

local function _get_draw_rect(x, y, icon_w, icon_h, multiple)
    multiple = multiple or 1
    local tile_size = TILE_SIZE * multiple
    y = y - tile_size
    local max = math.max(icon_h, icon_w)
    local draw_w = tile_size * (icon_w / max)
    local draw_h = tile_size * (icon_h / max)
    local draw_x = x - (tile_size / 2)
    local draw_y = y + (tile_size / 2)
    return draw_x, draw_y, draw_w, draw_h
end

local function _calc_begin_xy(x, y, w, h)
    local begin_x = x - (w * TILE_SIZE) / 2
    local begin_y = y + (h * TILE_SIZE) / 2
    return begin_x, begin_y
end

local function _draw_icon(e, object_id, building_srt, status, recipe)
    local x, y = math3d.index(building_srt.t, 1), math3d.index(building_srt.t, 3)
    if status == ICON_STATUS_NOPOWER then
        local material_path = "/pkg/vaststars.resources/materials/canvas/no-power.material"
        local icon_w, icon_h = _get_texture_size(material_path)
        local texture_x, texture_y, texture_w, texture_h = 0, 0, icon_w, icon_h
        local draw_x, draw_y, draw_w, draw_h = _get_draw_rect(x, y, icon_w, icon_h, 1.5)
        icanvas.add_item("icon",
            object_id,
            icanvas.get_key(material_path, RENDER_LAYER.ICON),
            {
                texture = {
                    rect = {
                        x = texture_x,
                        y = texture_y,
                        w = texture_w,
                        h = texture_h,
                    },
                },
                x = draw_x, y = draw_y, w = draw_w, h = draw_h,
            }
        )
    else
        local typeobject = iprototype.queryById(e.building.prototype)
        if status == ICON_STATUS_NORECIPE then
            local material_path = "/pkg/vaststars.resources/materials/canvas/no-recipe.material"
            local icon_w, icon_h = _get_texture_size(material_path)
            local texture_x, texture_y, texture_w, texture_h = 0, 0, icon_w, icon_h
            local draw_x, draw_y, draw_w, draw_h = _get_draw_rect(x, y, icon_w, icon_h, 1.5)
            icanvas.add_item("icon",
                object_id,
                icanvas.get_key(material_path, RENDER_LAYER.ICON),
                {
                    texture = {
                        rect = {
                            x = texture_x,
                            y = texture_y,
                            w = texture_w,
                            h = texture_h,
                        },
                    },
                    x = draw_x, y = draw_y, w = draw_w, h = draw_h,
                }
            )
        else
            local material_path
            local icon_w, icon_h
            local draw_x, draw_y, draw_w, draw_h
            local texture_x, texture_y, texture_w, texture_h

            if typeobject.assembling_icon ~= false then
                local recipe_typeobject = assert(iprototype.queryById(recipe))
                local cfg = RECIPES_CFG[recipe_typeobject.recipe_icon]
                if not cfg then
                    error(("can not found `%s`"):format(recipe_typeobject.recipe_icon))
                    return
                end
                material_path = "/pkg/vaststars.resources/materials/canvas/recipes.material"
                texture_x, texture_y, texture_w, texture_h = cfg.x, cfg.y, cfg.width, cfg.height
                draw_x, draw_y, draw_w, draw_h = _get_draw_rect(x, y, cfg.width, cfg.height, 1.5)
                icanvas.add_item("icon",
                    object_id,
                    icanvas.get_key(material_path, RENDER_LAYER.ICON_CONTENT),
                    {
                        texture = {
                            rect = {
                                x = texture_x,
                                y = texture_y,
                                w = texture_w,
                                h = texture_h,
                            },
                        },
                        x = draw_x, y = draw_y, w = draw_w, h = draw_h,
                    }
                )
            end

            if typeobject.fluidboxes then
                local recipe_typeobject = assert(iprototype.queryById(recipe))

                -- draw fluid icon of fluidboxes
                local t = {
                    {"ingredients", "input"},
                    {"results", "output"},
                }

                local begin_x, begin_y = _calc_begin_xy(x, y, iprototype.rotate_area(typeobject.area, e.building.direction))
                for _, r in ipairs(t) do
                    local i = 0
                    for _, v in ipairs(irecipe.get_elements(recipe_typeobject[r[1]])) do
                        if iprototype.is_fluid_id(v.id) then
                            i = i + 1
                            local c = assert(typeobject.fluidboxes[r[2]][i])
                            local connection = assert(c.connections[1])
                            local connection_x, connection_y, connection_dir = iprototype.rotate_connection(connection.position, e.building.direction, typeobject.area)
                            draw_fluid_icon(
                                object_id,
                                begin_x + connection_x * TILE_SIZE + TILE_SIZE / 2,
                                begin_y - connection_y * TILE_SIZE - TILE_SIZE / 2,
                                v.id
                            )

                            local dx, dy = iprototype.move_coord(connection_x, connection_y, connection_dir, 1, 1)

                            if r[2] == "input" then
                                material_path = "/pkg/vaststars.resources/materials/canvas/fluid-indication-arrow-input.material"
                            else
                                material_path = "/pkg/vaststars.resources/materials/canvas/fluid-indication-arrow-output.material"
                            end

                            icon_w, icon_h = _get_texture_size(material_path)
                            texture_x, texture_y, texture_w, texture_h = 0, 0, icon_w, icon_h
                            draw_x, draw_y, draw_w, draw_h = _get_draw_rect(
                                begin_x + dx * TILE_SIZE + TILE_SIZE / 2,
                                begin_y - dy * TILE_SIZE - TILE_SIZE / 2,
                                icon_w,
                                icon_h
                            )
                            icanvas.add_item("icon",
                                object_id,
                                icanvas.get_key(material_path, RENDER_LAYER.FLUID_INDICATION_ARROW),
                                {
                                    texture = {
                                        rect = {
                                            x = texture_x,
                                            y = texture_y,
                                            w = texture_w,
                                            h = texture_h,
                                        },
                                        srt = {
                                            r = ROTATORS[connection_dir],
                                        },
                                    },
                                    x = draw_x, y = draw_y, w = draw_w, h = draw_h,
                                }
                            )
                        end
                    end
                end
            end -- typeobject.fluidboxes

        end
    end
end

local function _create_icon(object_id, e, building_srt)
    local status = 0
    local recipe = 0
    local typeobject = iprototype.queryById(e.building.prototype)
    local is_generator = iprototype.has_type(typeobject.type, "generator")

    local function on_position_change(self, building_srt)
        local object = assert(objects:get(object_id))
        local e = assert(gameplay_core.get_entity(object.gameplay_eid))
        icanvas.remove_item("icon", object_id)
        _draw_icon(e, object_id, building_srt, status, recipe)
    end
    local function remove(self)
        icanvas.remove_item("icon", object_id)
    end
    local function update(self, e, force_update)
        local s
        if not is_generator and not ipower_check.is_powered_on(gameplay_core.get_world(), e) then
            s = ICON_STATUS_NOPOWER
        else
            if e.assembling.recipe == 0 then
                s = ICON_STATUS_NORECIPE
            else
                s = ICON_STATUS_RECIPE
            end
        end

        if not force_update and s == status and recipe == e.assembling.recipe then
            return
        end

        status, recipe = s, e.assembling.recipe
        icanvas.remove_item("icon", object_id)
        _draw_icon(e, object_id, building_srt, status, recipe)
    end
    return {
        on_position_change = on_position_change,
        remove = remove,
        update = update,
        object_id = object_id,
    }
end

local function _draw_consumer_icon(object_id, building_srt)
    local x, y = math3d.index(building_srt.t, 1), math3d.index(building_srt.t, 3)
    local material_path = "/pkg/vaststars.resources/materials/canvas/no-power.material"
    local icon_w, icon_h = _get_texture_size(material_path)
    local texture_x, texture_y, texture_w, texture_h = 0, 0, icon_w, icon_h
    local draw_x, draw_y, draw_w, draw_h = _get_draw_rect(x, y, icon_w, icon_h, 1.5)
    icanvas.add_item("icon",
        object_id,
        icanvas.get_key(material_path, RENDER_LAYER.ICON_CONTENT),
        {
            texture = {
                rect = {
                    x = texture_x,
                    y = texture_y,
                    w = texture_w,
                    h = texture_h,
                },
            },
            x = draw_x, y = draw_y, w = draw_w, h = draw_h,
        }
    )
end

local function _create_consumer_icon(object_id, building_srt)
    _draw_consumer_icon(object_id, building_srt)
    local function remove()
        icanvas.remove_item("icon", object_id)
    end
    local function on_position_change(self, building_srt)
        icanvas.remove_item("icon", object_id)
        _draw_consumer_icon(object_id, building_srt)
    end
    return {
        on_position_change = on_position_change,
        remove = remove,
    }
end

local function _get_game_object(object)
    local vsobject = vsobject_manager:get(object.id) or error(("(%s) vsobject not found"):format(object.prototype_name))
    return vsobject.game_object
end

local function _build_io_shelves(gameplay_world, e, object, typeobject)
    if typeobject.io_shelf == false then
        return
    end

    local building = global.buildings[object.id]

    --
    if e.assembling.recipe == 0 then
        local io_shelves = building.io_shelves
        if io_shelves then
            io_shelves:remove()
            building.io_shelves = nil
        end
    else
        local io_shelves = building.io_shelves
        if io_shelves then
            building.io_shelves:update(gameplay_world, e, _get_game_object(object))
        else
            building.io_shelves = create_io_shelves(gameplay_world, e, _get_game_object(object))
        end
    end
end

function assembling_sys:gameworld_prebuild()
    local gameplay_world = gameplay_core.get_world()
    local ecs = gameplay_world.ecs
    for e in ecs:select "REMOVED fluidboxes:in eid:in" do
        remove_assembling_fluid_port(e.eid)
    end
end

function assembling_sys:gameworld_build()
    local gameplay_world = gameplay_core.get_world()
    local gameplay_ecs = gameplay_world.ecs
    for e in gameplay_ecs:select "assembling:in building:in chest:in" do
        local object = assert(objects:coord(e.building.x, e.building.y))
        local typeobject = iprototype.queryById(e.building.prototype)
        _build_io_shelves(gameplay_world, e, object, typeobject)
    end
    for e in gameplay_ecs:select "assembling:in fluidboxes:in" do
        renew_assembling_fluid_port(gameplay_world, e)
    end

    for e in gameplay_world.ecs:select "building_changed assembling:in chest:in building:in capacitance?in eid:in" do
        local object = assert(objects:coord(e.building.x, e.building.y))
        local building = global.buildings[object.id]
        if not building.assembling_icon then
            building.assembling_icon = _create_icon(object.id, e, object.srt)
        end
        building.assembling_icon:update(e, true)
    end
end

local _update = interval_call(300, function()
    local gameplay_world = gameplay_core.get_world()

    for e in gameplay_world.ecs:select "assembling:in chest:in building:in capacitance?in eid:in" do
        local object = assert(objects:coord(e.building.x, e.building.y))
        local building = global.buildings[object.id]

        local io_shelves = building.io_shelves
        if io_shelves then
            local typeobject_recipe = iprototype.queryById(e.assembling.recipe)
            local ingredients_n <const> = #typeobject_recipe.ingredients//4 - 1
            local results_n <const> = #typeobject_recipe.results//4 - 1
            for idx = 1, ingredients_n + results_n do
                local slot = assert(ichest.get(gameplay_world, e.chest, idx))
                assert(slot.item ~= 0)
                local typeobject_item = iprototype.queryById(slot.item)
                if iprototype.has_type(typeobject_item.type, "item") then
                    io_shelves:update_item(idx, slot.amount)
                end
            end
        end

        if not building.assembling_icon then
            building.assembling_icon = _create_icon(object.id, e, object.srt)
        end
        building.assembling_icon:update(e)
    end

    -- special handling for the display of the 'no power' icon on the laboratory or airport
    for e in gameplay_world.ecs:select "consumer:in assembling:absent building:in capacitance:in eid:in" do
        local object = assert(objects:coord(e.building.x, e.building.y))
        local building = global.buildings[object.id]
        if not ipower_check.is_powered_on(gameplay_world, e) then
            if not building.consumer_icon then
                building.consumer_icon = _create_consumer_icon(object.id, object.srt)
            end
        else
            if building.consumer_icon then
                building.consumer_icon:remove()
                building.consumer_icon = nil
            end
        end
    end
end)

function assembling_sys:gameworld_update()
    _update()
end
