local ecs, mailbox = ...
local world = ecs.world
local w = world.w
local gameplay_core = require "gameplay.core"
local global = require "global"
local iprototype = require "gameplay.interface.prototype"
local irecipe = require "gameplay.interface.recipe"
local click_tech_event = mailbox:sub {"click_tech"}
local switch_mb = mailbox:sub {"switch"}
local M = {}
local current_tech
local function get_techlist()
    local function get_display_item(technode)
        local name = technode.name
        local value = technode.detail
        local simple_ingredients = {}
        local ingredients = irecipe:get_elements(value.ingredients)
        for _, ingredient in ipairs(ingredients) do
            simple_ingredients[#simple_ingredients + 1] = {icon = ingredient.tech_icon, count = ingredient.count}
        end
        local detail = {}
        if value.sign_desc then
            for _, desc in ipairs(value.sign_desc) do
                detail[#detail+1] = desc
            end
        end
        if value.effects and value.effects.unlock_recipe then
            local prototypes = iprototype.all_prototype_name()
            for _, recipe in ipairs(value.effects.unlock_recipe) do
                local recipe_detail = prototypes["(recipe)" .. recipe]
                if recipe_detail then
                    local input = {}
                    ingredients = irecipe:get_elements(recipe_detail.ingredients)
                    for _, ingredient in ipairs(ingredients) do
                        input[#input + 1] = {name = ingredient.name, icon = ingredient.icon, count = ingredient.count}
                    end
                    local output = {}
                    local results = irecipe:get_elements(recipe_detail.results)
                    for _, ingredient in ipairs(results) do
                        output[#output + 1] = {name = ingredient.name, icon = ingredient.icon, count = ingredient.count}
                    end
                    detail[#detail + 1] = {
                        name = recipe,
                        icon = recipe_detail.icon,
                        desc = recipe_detail.description,
                        input = input,
                        output = output
                    }
                end
            end
        end
        local game_world = gameplay_core.get_world()
        local progress = game_world:research_progress(name) or 0
        local queue = game_world:research_queue()
        return {
            name = name,
            icon = value.icon,
            desc = value.desc or " ",
            sign_icon = value.sign_icon,
            detail = detail,
            ingredients = simple_ingredients,
            count = value.count,
            time = value.time,
            task = value.task,
            progress = (progress > 0) and ((progress * 100) // value.count) or progress,
            running = #queue > 0 and queue[1] == name or false
        }
    end
    local items = {}
    for _, technode in ipairs(global.science.tech_list) do
        local di = get_display_item(technode)
        di.index = #items + 1
        items[#items + 1] = di
    end
    return items
end

local function get_button_str(tech)
    return (tech.running and "停止" or "开始") .. (tech.task and "任务" or "研究")
end

function M:create(object_id)
    local items = get_techlist()
    current_tech = items[1]
    return {
        techitems = items,
        current_tech = current_tech,
        current_desc = current_tech.desc,
        current_icon = current_tech.icon,
        current_running = current_tech.running,
        current_button_str = get_button_str(current_tech)
    }
end

function M:stage_ui_update(datamodel)
    local function set_current_tech(tech)
        if current_tech == tech then
            return
        end
        current_tech = tech
        datamodel.current_tech = tech
        datamodel.current_desc = tech.desc
        datamodel.current_icon = tech.icon
        datamodel.current_running = tech.running
        datamodel.current_button_str = get_button_str(tech)
    end

    for _, _, _, index in click_tech_event:unpack() do
        set_current_tech(datamodel.techitems[index])
    end

    local game_world = gameplay_core.get_world()
    for _, _, _ in switch_mb:unpack() do
        current_tech.running = not current_tech.running
        if current_tech.running then
            for _, tech in ipairs(global.science.tech_list) do
                if current_tech ~= tech then
                    tech.running = false
                end
            end
            game_world:research_queue {current_tech.name}
            print("开始研究：", current_tech.name)
        else
            game_world:research_queue {}
            print("停止研究：", current_tech.name)
        end
        datamodel.current_running = current_tech.running
        datamodel.current_progress = current_tech.progress
        datamodel.current_button_str = get_button_str(current_tech)
    end
end

return M