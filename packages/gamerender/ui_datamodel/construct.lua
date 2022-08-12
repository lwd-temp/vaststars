local ecs, mailbox = ...
local world = ecs.world
local w = world.w

local math3d = require "math3d"
local YAXIS_PLANE_B <const> = math3d.constant("v4", {0, 1, 0, 0})
local YAXIS_PLANE_T <const> = math3d.constant("v4", {0, 1, 0, 20})
local PLANES <const> = {YAXIS_PLANE_T, YAXIS_PLANE_B}
local camera = ecs.require "engine.camera"
local gameplay_core = require "gameplay.core"
local iui = ecs.import.interface "vaststars.gamerender|iui"
local iprototype = require "gameplay.interface.prototype"
local create_normalbuilder = ecs.require "editor.normalbuilder"
local create_pipebuilder = ecs.require "editor.pipebuilder"
local create_roadbuilder = ecs.require "editor.roadbuilder"
local create_pipetogroundbuilder = ecs.require "editor.pipetogroundbuilder"
local objects = require "objects"
local ieditor = ecs.require "editor.editor"
local global = require "global"
local iobject = ecs.require "object"
local terrain = ecs.require "terrain"
local icamera = ecs.require "engine.camera"
local idetail = ecs.import.interface "vaststars.gamerender|idetail"
local construct_menu_cfg = import_package "vaststars.prototype"("construct_menu")
local DISABLE_FPS = require("debugger").disable_fps

local dragdrop_camera_mb = world:sub {"dragdrop_camera"}
local construct_begin_mb = mailbox:sub {"construct_begin"} -- 建造 -> 建造模式
local dismantle_begin_mb = mailbox:sub {"dismantle_begin"} -- 建造 -> 拆除模式
local rotate_mb = mailbox:sub {"rotate"} -- 旋转建筑
local construct_confirm_mb = mailbox:sub {"construct_confirm"} -- 确认放置
local construct_complete_mb = mailbox:sub {"construct_complete"} -- 开始施工
local dismantle_complete_mb = mailbox:sub {"dismantle_complete"} -- 开始拆除
local cancel_mb = mailbox:sub {"cancel"} -- 主界面左上角返回按钮
local show_setting_mb = mailbox:sub {"show_setting"} -- 主界面左下角 -> 游戏设置
local headquater_mb = mailbox:sub {"headquater"} -- 主界面左下角 -> 指挥中心
local technology_mb = mailbox:sub {"technology"} -- 主界面左下角 -> 科研中心
local construct_entity_mb = mailbox:sub {"construct_entity"} -- 建造 entity
local laying_pipe_begin_mb = mailbox:sub {"laying_pipe_begin"} -- 铺管开始
local laying_pipe_cancel_mb = mailbox:sub {"laying_pipe_cancel"} -- 铺管取消
local laying_pipe_confirm_mb = mailbox:sub {"laying_pipe_confirm"} -- 铺管结束
local open_taskui_event = mailbox:sub {"open_taskui"}
local load_resource_mb = mailbox:sub {"load_resource"}
local single_touch_mb = world:sub {"single_touch"}
local imanual = require "ui_datamodel.common.manual"
local inventory = global.inventory
local pickup_mb = world:sub {"pickup"}
local single_touch_move_mb = world:sub {"single_touch", "MOVE"}

local builder
local last_prototype_name

-- TODO: we really need to get headquater object?
local function get_headquater_object_id()
    for id in objects:select("CONSTRUCTED", "headquater", true) do
        return id
    end
end

local function _has_teardown_entity()
    for _ in objects:select("TEMPORARY", "teardown", true) do
        return true
    end
    return false
end

local function _get_construct_menu()
    local construct_menu = {}
    for _, menu in ipairs(construct_menu_cfg) do
        local m = {}
        m.name = menu.name
        m.icon = menu.icon
        m.detail = {}

        for _, prototype_name in ipairs(menu.detail) do
            local typeobject = assert(iprototype.queryByName("item", prototype_name))
            local c = inventory:get(typeobject.id)
            if c.count > 0 then
                m.detail[#m.detail + 1] = {
                    show_prototype_name = iprototype.show_prototype_name(typeobject),
                    prototype_name = prototype_name,
                    icon = typeobject.icon,
                    count = c.count,
                }
            end
        end

        construct_menu[#construct_menu+1] = m
    end
    return construct_menu
end

local _show_grid_entity ; do
    local igrid_entity = ecs.require "engine.grid_entity"
    local obj
    function _show_grid_entity(b)
        if b then
            if not obj then
                obj = igrid_entity.create("polyline_grid", terrain._width, terrain._height, terrain.tile_size, {t = {0, 4, 0}})
            else
                obj:show(true)
            end
        else
            if obj then
                obj:show(false)
            end
        end
    end
end

---------------
local M = {}

function M:create()
    return {
        construct_menu = {},
        tech_count = global.science.tech_list and #global.science.tech_list or 0,
        show_tech_progress = false,
        current_tech_icon = "none",    --当前科技图标
        current_tech_name = "none",    --当前科技名字
        current_tech_progress = "0%",  --当前科技进度
        manual_queue = {},
        manual_queue_length = 0, -- cache the length of manual queue, for animation when manual queue has been finished
    }
end

function M:update_construct_inventory(datamodel)
    datamodel.construct_menu = _get_construct_menu()
end

-- TODO
function M:fps_text(datamodel, text)
    if DISABLE_FPS then
        return
    end
    datamodel.fps_text = text
end

function M:drawcall_text(datamodel, text)
    if DISABLE_FPS then
        return
    end
    datamodel.drawcall_text = text
end

function M:show_chapter(datamodel, main_text, sub_text)
    datamodel.show_chapter = true
    datamodel.chapter_main_text = main_text
    datamodel.chapter_sub_text = sub_text
end

function M:update_tech(datamodel, tech)
    if tech then
        datamodel.show_tech_progress = true
        datamodel.is_task = tech.task
        datamodel.current_tech_name = tech.name
        datamodel.current_tech_icon = tech.detail.icon
        datamodel.current_tech_progress = (tech.progress * 100) // tech.detail.count .. '%'
    else
        datamodel.show_tech_progress = false
        datamodel.tech_count = global.science.tech_list and #global.science.tech_list or 0
        world:pub {"ui_message", "tech_finish_animation"}
    end
end

function M:stage_ui_update(datamodel)
    for _, _, _, double_confirm in construct_begin_mb:unpack() do
        idetail.unselected()
        if builder then
            if builder:check_unconfirmed(double_confirm) then
                world:pub {"ui_message", "show_unconfirmed_double_confirm"}
                goto continue
            end
        end

        if not double_confirm then
            world:pub {"ui_message", "unconfirmed_double_confirm_continuation"}
            goto continue
        end

        _show_grid_entity(true)
        ieditor:revert_changes({"TEMPORARY", "CONFIRM"})
        datamodel.show_rotate = false
        datamodel.show_confirm = false
        datamodel.show_construct_complete = false
        gameplay_core.world_update = false
        global.mode = "construct"
        camera.transition("camera_construct.prefab")
        last_prototype_name = nil

        inventory:flush()
        datamodel.construct_menu = _get_construct_menu()
        ::continue::
    end

    for _, _, _, double_confirm in dismantle_begin_mb:unpack() do
        idetail.unselected()
        if builder then
            if builder:check_unconfirmed(double_confirm) then
                world:pub {"ui_message", "show_unconfirmed_double_confirm"}
                goto continue
            end

            builder:clean(datamodel)
            builder = nil
        end

        if not double_confirm then
            world:pub {"ui_message", "unconfirmed_double_confirm_continuation"}
            goto continue
        end

        _show_grid_entity(false)
        ieditor:revert_changes({"TEMPORARY", "CONFIRM"})
        datamodel.show_teardown = _has_teardown_entity()

        global.mode = "teardown"
        gameplay_core.world_update = false
        camera.transition("camera_construct.prefab")
        ::continue::
    end

    for _ in rotate_mb:unpack() do
        assert(gameplay_core.world_update == false)
        builder:rotate_pickup_object(datamodel)
    end

    for _ in construct_confirm_mb:unpack() do
        assert(gameplay_core.world_update == false)
        builder:confirm(datamodel)
        self:flush()
    end

    for _ in construct_complete_mb:unpack() do
        builder:complete(datamodel)
        self:flush()
        builder = nil
        gameplay_core.world_update = true
        global.mode = "normal"
        camera.transition("camera_default.prefab")
        _show_grid_entity(false)
    end

    for _ in dismantle_complete_mb:unpack() do
        ieditor:teardown_complete()
        global.mode = "normal"
        gameplay_core.world_update = true
        camera.transition("camera_default.prefab")
    end

    for _, _, _, double_confirm in cancel_mb:unpack() do
        if builder then
            if builder:check_unconfirmed(double_confirm) then
                world:pub {"ui_message", "show_unconfirmed_double_confirm"}
                goto continue
            end

            builder:clean(datamodel)
            builder = nil
        end

        if not double_confirm then
            world:pub {"ui_message", "unconfirmed_double_confirm_continuation"}
            goto continue
        end

        ieditor:revert_changes({"TEMPORARY", "CONFIRM"})
        gameplay_core.world_update = true
        global.mode = "normal"
        camera.transition("camera_default.prefab")
        _show_grid_entity(false)
        ::continue::
    end

    for _ in headquater_mb:unpack() do
        local object_id = get_headquater_object_id()
        if object_id then
            iui.open("inventory.rml", object_id)
        else
            log.error("can not found headquater")
        end
    end

    for _ in open_taskui_event:unpack() do
        if gameplay_core.world_update and global.science.current_tech then
            gameplay_core.world_update = false
            iui.open("task_pop.rml")
        end
    end

    for _ in technology_mb:unpack() do
        gameplay_core.world_update = false
        iui.open("science.rml")
    end

    for _ in show_setting_mb:unpack() do
        iui.open("option_pop.rml")
    end

    for _ in laying_pipe_begin_mb:unpack() do
        builder:laying_pipe_begin(datamodel)
        self:flush()
    end

    for _ in laying_pipe_cancel_mb:unpack() do
        builder:laying_pipe_cancel(datamodel)
        self:flush()
    end

    for _ in laying_pipe_confirm_mb:unpack() do
        builder:laying_pipe_confirm(datamodel)
        self:flush()
    end

    for _ in load_resource_mb:unpack() do
        local resource = require "resources"
        local assetmgr = import_package "ant.asset"
        local length

        local imaterial = ecs.import.interface "ant.asset|imaterial"
        length = #imaterial.load_res('/pkg/ant.resources/materials/pickup_opacity.material')
        length = #imaterial.load_res('/pkg/ant.resources/materials/pickup_opacity.material', {skinning="GPU"})
        length = #imaterial.load_res('/pkg/ant.resources/materials/pickup_transparent.material')
        length = #imaterial.load_res('/pkg/ant.resources/materials/pickup_transparent.material', {skinning="GPU"})
        length = #imaterial.load_res("/pkg/ant.resources/materials/predepth.material", {depth_type="inv_z"})
        length = #imaterial.load_res("/pkg/ant.resources/materials/predepth.material", {depth_type="inv_z", skinning="GPU"})

        assetmgr.load_fx {
            fs = "/pkg/ant.resources/shaders/pbr/fs_pbr.sc",
            vs = "/pkg/ant.resources/shaders/pbr/vs_pbr.sc",
        }

        local skip = {"glb", "cfg", "hdr", "dds", "anim", "event", "lua", "efk", "rml", "rcss", "ttc", "png", "material"}
        local handler = {
            ["prefab"] = function(f)
                local fs = require "filesystem"
                local datalist  = require "datalist"
                local lf = assert(fs.open(fs.path(f)))
                local data = lf:read "a"
                lf:close()
                local prefab_resource = {"material", "mesh", "skeleton", "meshskin"}
                for _, d in ipairs(datalist.parse(data)) do
                    for _, field in ipairs(prefab_resource) do
                        if d.data[field] then
                            if field == "material" then
                                length = #imaterial.load_res(d.data.material, d.data.material_setting)
                            else
                                length = #assetmgr.resource(d.data[field])
                            end
                        end
                    end
                end
            end,
            ["texture"] = function (f)
                length = #assetmgr.resource(f)
            end,
        }
        for _, name in ipairs(resource) do
            local f = ("/pkg/vaststars.resources%s"):format(name)
            local ext = f:match(".*%.(.*)$")

            for _, _ext in ipairs(skip) do
                if ext == _ext then
                    goto continue
                end
            end

            log.info("load " .. f)
            assert(handler[ext], "unknown resource type " .. ext)
            handler[ext](f)
            ::continue::
        end
        log.info("finished load resources")
    end
end

function M:stage_camera_usage(datamodel)
    for _, delta in dragdrop_camera_mb:unpack() do
        if builder then
            builder:touch_move(datamodel, delta)
            self:flush()
        end
    end

    for _, _, _, prototype_name in construct_entity_mb:unpack() do
        if last_prototype_name ~= prototype_name then
            if builder then
                builder:clean(datamodel)
            end

            if iprototype.is_pipe_to_ground(prototype_name) then
                builder = create_pipetogroundbuilder()
            elseif iprototype.is_pipe(prototype_name) then
                builder = create_pipebuilder()
            elseif iprototype.is_road(prototype_name) then
                builder = create_roadbuilder()
            else
                builder = create_normalbuilder()
            end

            local typeobject = iprototype.queryByName("entity", prototype_name)
            builder:new_entity(datamodel, typeobject)
            self:flush()

            last_prototype_name = prototype_name
        end
    end

    for _, state in single_touch_mb:unpack() do
        if state == "END" or state == "CANCEL" then
            if builder then
                builder:touch_end(datamodel)
                self:flush()
            end
        end
    end

    local leave = true

    local function _get_object(pickup_x, pickup_y)
        for _, pos in ipairs(icamera.screen_to_world(pickup_x, pickup_y, PLANES)) do
            local coord = terrain:get_coord_by_position(pos)
            if coord then
                local object = objects:coord(coord[1], coord[2])
                if object then
                    return object
                end
            end
        end
    end

    -- 点击其它建筑 或 拖动时, 将弹出窗口隐藏
    for _, _, x, y in pickup_mb:unpack() do
        do -- for debug
            local pos = icamera.screen_to_world(x, y, {PLANES[1]})
            local coord = terrain:align(pos[1], 1, 1)
            if coord then
                print(("pickup coord: (%s, %s) ground(%s, %s)"):format(coord[1], coord[2], coord[1] - (coord[1] % terrain.ground_width), coord[2] - (coord[2] % terrain.ground_height)))
            end
        end

        local object = _get_object(x, y)
        if object then -- object may be nil, such as when user click on empty space
            if global.mode == "teardown" then
                ieditor:teardown(object.id)
                datamodel.show_teardown = _has_teardown_entity()

            elseif global.mode == "normal" then
                if idetail.show(object.id) then
                    leave = false
                end
            end
        else
            idetail.unselected()
        end

        if leave then
            world:pub {"ui_message", "leave"}
            leave = false
            break
        end
    end

    for _ in single_touch_move_mb:unpack() do
        if leave then
            world:pub {"ui_message", "leave"}
            leave = false
            break
        end
    end

    datamodel.manual_queue = imanual.get_queue(4)
    if datamodel.manual_queue_length > 0 and #datamodel.manual_queue == 0 then
        world:pub {"ui_message", "manual_finish"}
    end
    datamodel.manual_queue_length = #datamodel.manual_queue

    iobject.flush()
end
return M