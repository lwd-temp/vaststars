local ecs = ...
local world = ecs.world
local w = world.w

local iom = ecs.import.interface "ant.objcontroller|iobj_motion"
local math3d = require "math3d"
local camera = ecs.require "engine.camera"

local MOVE_SPEED <const> = 8.0
local YAXIS_PLANE <const> = math3d.constant("v4", {0, 1, 0, 0})
local PLANES <const> = {YAXIS_PLANE}
local camera_controller = ecs.system "camera_controller"
local single_touch_mb = world:sub {"single_touch"}
local touch_mb = world:sub {"touch"}
local ui_message_move_camera_mb = world:sub {"ui_message", "move_camera"}
local mouse_wheel_mb = world:sub {"mouse_wheel"}

local datalist = require "datalist"
local fs = require "filesystem"
local CAMERA_DEFAULT = datalist.parse(fs.open(fs.path("/pkg/vaststars.resources/camera_default.prefab")):read "a")
local CAMERA_DEFAULT_YAIXS <const> = CAMERA_DEFAULT[1].data.scene.t[2]
local CAMERA_YAIXS_MIN <const> = CAMERA_DEFAULT_YAIXS - 150
local CAMERA_YAIXS_MAX <const> = CAMERA_DEFAULT_YAIXS + 150

local __handle_drop_camera; do
    local last_position

    function __handle_drop_camera(ce)
        local position

        for _, state, data in single_touch_mb:unpack() do
            if state == "START" then
                last_position = math3d.ref(camera.screen_to_world(data.x, data.y, PLANES)[1])
            elseif state == "MOVE" then
                position = data
            elseif state == "CANCEL" or state == "END" then
                last_position = nil
            end
        end

        if last_position and position then
            local current = camera.screen_to_world(position.x, position.y, PLANES)[1]
            local delta = math3d.ref(math3d.sub(last_position, current))
            iom.move_delta(ce, delta)
            world:pub {"dragdrop_camera", delta}
        end
    end
end

function camera_controller:camera_usage()
    local mq = w:first("main_queue camera_ref:in")
    local ce <close> = w:entity(mq.camera_ref)

    for _, state, touches in touch_mb:unpack() do
        local count = #touches
        if count == 2 then
            local touch1 = touches[1]
            local touch2 = touches[2]
            -- TODO: handle pinch zoom
        end
    end

    for _, delta in mouse_wheel_mb:unpack() do
        local mq = w:first("main_queue camera_ref:in render_target:in")
        local ce<close> = w:entity(mq.camera_ref, "scene:update")
        local deltavec = math3d.mul(iom.get_direction(ce), delta * MOVE_SPEED)
        local position = math3d.add(iom.get_position(ce), deltavec)
        local y = math3d.index(position, 2)
        if y >= CAMERA_YAIXS_MIN and y <= CAMERA_YAIXS_MAX then
            iom.set_position(ce, position)
        end
    end

    __handle_drop_camera(ce)

    for _, _, left, top, position in ui_message_move_camera_mb:unpack() do
        local mq = w:first("main_queue render_target:in")
        local vr = mq.render_target.view_rect
        local vmin = math.min(vr.w / vr.ratio, vr.h / vr.ratio)
        local ui_position = camera.screen_to_world(left / 100 * vmin, top / 100 * vmin, PLANES)[1]

        local delta = math3d.set_index(math3d.sub(position, ui_position), 2, 0) -- the camera is always moving in the x/z axis and the y axis is always 0
        iom.move_delta(ce, delta)
    end
end