local wezterm = require('wezterm')
local act = wezterm.action

local M = {}

local split_menu_action = act.InputSelector({
   title = 'Shift+右键分割当前终端',
   description = '选择一个方向并回车确认',
   choices = {
      { id = 'horizontal', label = '水平分割终端（左右）' },
      { id = 'vertical', label = '垂直分割终端（上下）' },
      { id = 'close', label = '关闭当前终端' },
   },
   action = wezterm.action_callback(function(window, pane, id)
      if id == 'horizontal' then
         window:perform_action(
            act.SplitPane({ direction = 'Right', size = { Percent = 50 } }),
            pane
         )
         return
      end

      if id == 'vertical' then
         window:perform_action(
            act.SplitPane({ direction = 'Down', size = { Percent = 50 } }),
            pane
         )
         return
      end

      if id == 'close' then
         window:perform_action(
            act.CloseCurrentPane({ confirm = false }),
            pane
         )
      end
   end),
})

function M.append_to_mouse_bindings(mouse_bindings)
   table.insert(mouse_bindings, {
      event = { Down = { streak = 1, button = 'Right' } },
      mods = 'SHIFT',
      action = act.Nop,
   })

   table.insert(mouse_bindings, {
      event = { Up = { streak = 1, button = 'Right' } },
      mods = 'SHIFT',
      action = split_menu_action,
   })

   -- When an app grabs the mouse, holding SHIFT bypasses app capture and
   -- the modifier is removed before matching bindings, so this second pair
   -- keeps the menu working in vim/tmux mouse mode.
   table.insert(mouse_bindings, {
      event = { Down = { streak = 1, button = 'Right' } },
      mods = 'NONE',
      mouse_reporting = true,
      action = act.Nop,
   })

   table.insert(mouse_bindings, {
      event = { Up = { streak = 1, button = 'Right' } },
      mods = 'NONE',
      mouse_reporting = true,
      action = split_menu_action,
   })
end

return M
