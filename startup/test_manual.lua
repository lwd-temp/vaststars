local gameplay = import_package "vaststars.gameplay"
local prototype = gameplay.prototype

local function isFluidId(id)
    return id & 0x0C00 == 0x0C00
end

local function decode(s)
    s = s:sub(5)
    assert(#s <= 4 * 15)
    local t = {}
    for idx = 1, #s//4 do
        local id, n = string.unpack("<I2I2", s, 4*idx-3)
        if isFluidId(id) then
            return
        end
        t[#t+1] = {prototype.queryById(id).name, n}
    end
    return t
end

local function solverCreate()
    local manual = {}
    local intermediate = {}

    local function insertManual(mainoutput, info)
        manual[info.name] = info
    end

    for name, info in pairs(prototype.each "recipe") do
        if info.allow_manual ~= false then
            local ingredients = decode(info.ingredients)
            local results = decode(info.results)
            if ingredients and results and #results > 0 then
                local r = {
                    id = info.id,
                    name = name,
                    input = ingredients,
                    output = results,
                    time = info.time,
                }
                local mainoutput = results[1][1]
                insertManual(mainoutput, r)
                if info.allow_as_intermediate ~= false then
                    if intermediate[mainoutput] then
                        error("不允许多个配方包含相同的主产物: "..name.."/"..intermediate[mainoutput].name)
                    end
                    intermediate[mainoutput] = r
                end
            end
        end
    end
    return {
        manual = manual,
        intermediate = intermediate,
    }
end

local function solverEvaluate(solver, memory, register, input)
    local mt = {}
    function mt:__index(k)
        self[k] = 0
        return 0
    end
    setmetatable(memory, mt)
    setmetatable(register, mt)

    local output = {}
    local total_progress = 0 -- total progress of current manual crafting
    local manual = solver.manual
    local intermediate = solver.intermediate
    local function push_crafting(item)
        table.insert(output, 1,  {"crafting", item})
    end
    local function push_finish(item)
        table.insert(output, 1,  {"finish", item})
    end
    local function push_separator(recipe)
        table.insert(output, 1,  {"separator", recipe})
    end
    local function do_crafting(recipe)
        for _, s in ipairs(recipe.input) do
            local id = s[1]
            local n = s[2]
            assert(register[id] + memory[id] >= n)
            if register[id] >= n then
                register[id] = register[id] - n
            else
                memory[id] = memory[id] + register[id] - n
                register[id] = 0
            end
        end
        for _, s in ipairs(recipe.output) do
            local id = s[1]
            local n = s[2]
            register[id] = register[id] + n
        end
        total_progress = total_progress + recipe.time
        push_crafting(recipe.name)
    end
    local function solve_intermediate(item, count)
        if count <= memory[item] + register[item] then
            return true
        end

        local recipe = intermediate[item]
        if not recipe then
            return
        end

        local mainoutput = recipe.output[1]
        local mul = mainoutput[2]

        local todo = recipe.input
        local last = count - (memory[item] + register[item])
        local n = 1 + (last-1) // mul
        for i = 1, #todo do
            if not solve_intermediate(todo[i][1], todo[i][2] * n) then
                return
            end
        end

        while register[item] + memory[item] < count do
            do_crafting(recipe)
        end
        return true
    end
    local function solve(recipe, count)
        local mainoutput = recipe.output[1]
        local item, mul = mainoutput[1], mainoutput[2]

        local todo = recipe.input
        local last = count - register[item]
        local n = 1 + (last-1) // mul

        if count > register[item] then
            for i = 1, #todo do
                if not solve_intermediate(todo[i][1], todo[i][2] * n) then
                    return
                end
            end
        end
        for _ = 1, n * mul do
            if register[item] == 0 then
                do_crafting(recipe)
            end
            register[item] = register[item] - 1
            push_finish(item)
        end

        push_separator(recipe.id)
        push_separator(n) -- n is the number of times to repeat the recipe
        push_separator(total_progress) -- total progress of current manual crafting
        total_progress = 0
        return true
    end
    for i = 1, #input do
        local recipe, count = input[i][1], input[i][2]
        local m = manual[recipe]
        if not m then
            assert(false, "unknown manual recipe: "..recipe)
            return
        end
        if not solve(m, count) then
            return
        end
    end
    return output
end

return {
    create = solverCreate,
    evaluate = solverEvaluate,
}
