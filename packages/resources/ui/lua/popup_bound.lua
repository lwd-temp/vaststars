-- the unit is vmin
local bound = {
    left = 35, -- see also: width of the detail panel in detal_panel.rml
    top = 0,
    right = 172 - 16, -- 172vmin approximate to 97vmax, 97vmax is the width of div, 16vmin is the width of button, see also: construct.rml - the current technology progress on top right of the screen
    bottom = 100 - 20, -- 20vmin is the height of main-menu-block, see also: construct.rml - main-menu-block
}

return function (left, top, offset_left, offset_top, panel_width, panel_height)
    local move_camera = false
    left = left - offset_left
    top = top - offset_top

    if left < bound.left then
        left = bound.left
        move_camera = true
    end

    if top < bound.top then
        top = bound.top
        move_camera = true
    end

    if left + panel_width > bound.right then
        left = bound.right - panel_width
        move_camera = true
    end

    if top + panel_height > bound.bottom then
        top = bound.bottom - panel_height
        move_camera = true
    end

    return move_camera, left, top
end