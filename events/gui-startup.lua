local wezterm = require('wezterm')
local mux = wezterm.mux

local M = {}

M.setup = function()
   wezterm.on('gui-startup', function(cmd)
      local _, _, window = mux.spawn_window(cmd or {})
      local gui_window = window:gui_window()

      -- Center window on screen
      local screen = wezterm.gui.screens().active
      local dims = gui_window:get_dimensions()

      local x = (screen.width - dims.pixel_width) / 2
      local y = (screen.height - dims.pixel_height) / 2

      gui_window:set_position(x, y)
   end)
end

return M
