local wezterm = require('wezterm')
local act = wezterm.action
local time = wezterm.time

local M = {}
local ADD_LABEL_EVENT = 'frequent-commands.add-label'
local ADD_COMMAND_EVENT = 'frequent-commands.add-command'
local EDIT_LABEL_EVENT = 'frequent-commands.edit-label'
local EDIT_COMMAND_EVENT = 'frequent-commands.edit-command'
local prompt_state = {}
local callbacks = nil

local function state_key(pane)
   return pane:pane_id()
end

local function set_prompt_state(pane, state)
   prompt_state[state_key(pane)] = state
end

local function get_prompt_state(pane)
   return prompt_state[state_key(pane)]
end

local function clear_prompt_state(pane)
   prompt_state[state_key(pane)] = nil
end

function M.open_action(window, pane, action)
   time.call_after(0.01, function()
      window:perform_action(action, pane)
   end)
end

local function queue_event(window, pane, event_name)
   time.call_after(0.01, function()
      wezterm.emit(event_name, window, pane)
   end)
end

local function prompt_input(window, pane, description, initial_value, on_submit)
   window:perform_action(
      act.PromptInputLine({
         description = description,
         initial_value = initial_value,
         action = wezterm.action_callback(function(inner_window, inner_pane, line)
            local value = callbacks.sanitize_text(line)
            if not value then
               if line ~= nil then
                  callbacks.notify_error(inner_window, description .. '不能为空。')
               end
               return
            end
            on_submit(inner_window, inner_pane, value)
         end),
      }),
      pane
   )
end

function M.start_add(window, pane, entries)
   set_prompt_state(pane, { entries = entries })
   queue_event(window, pane, ADD_LABEL_EVENT)
end

function M.start_edit_label(window, pane, entries, index)
   set_prompt_state(pane, { entries = entries, index = index })
   queue_event(window, pane, EDIT_LABEL_EVENT)
end

function M.start_edit_command(window, pane, entries, index)
   set_prompt_state(pane, { entries = entries, index = index })
   queue_event(window, pane, EDIT_COMMAND_EVENT)
end

function M.setup(opts)
   callbacks = opts
end

wezterm.on(ADD_LABEL_EVENT, function(window, pane)
   prompt_input(window, pane, '常用指令名称', '', function(inner_window, inner_pane, label)
      local state = get_prompt_state(inner_pane)
      if not state then
         callbacks.notify_error(inner_window, '新增常用指令状态已丢失。')
         return
      end
      state.label = label
      set_prompt_state(inner_pane, state)
      queue_event(inner_window, inner_pane, ADD_COMMAND_EVENT)
   end)
end)

wezterm.on(ADD_COMMAND_EVENT, function(window, pane)
   local state = get_prompt_state(pane)
   if not state then
      callbacks.notify_error(window, '新增常用指令状态已丢失。')
      return
   end
   prompt_input(window, pane, '常用指令内容', '', function(inner_window, inner_pane, command)
      table.insert(state.entries, { label = state.label, command = command })
      callbacks.save_and_continue(inner_window, state.entries, '已新增常用指令。', function()
         clear_prompt_state(inner_pane)
         callbacks.show_manage_panel(inner_window, inner_pane, state.entries)
      end)
   end)
end)

wezterm.on(EDIT_LABEL_EVENT, function(window, pane)
   local state = get_prompt_state(pane)
   if not state then
      callbacks.notify_error(window, '修改名称状态已丢失。')
      return
   end
   prompt_input(window, pane, '常用指令名称', state.entries[state.index].label, function(inner_window, inner_pane, label)
      state.entries[state.index].label = label
      callbacks.save_and_continue(inner_window, state.entries, '已更新指令名称。', function()
         clear_prompt_state(inner_pane)
         callbacks.show_entry_actions(inner_window, inner_pane, state.entries, state.index)
      end)
   end)
end)

wezterm.on(EDIT_COMMAND_EVENT, function(window, pane)
   local state = get_prompt_state(pane)
   if not state then
      callbacks.notify_error(window, '修改内容状态已丢失。')
      return
   end
   prompt_input(window, pane, '常用指令内容', state.entries[state.index].command, function(inner_window, inner_pane, command)
      state.entries[state.index].command = command
      callbacks.save_and_continue(inner_window, state.entries, '已更新指令内容。', function()
         clear_prompt_state(inner_pane)
         callbacks.show_entry_actions(inner_window, inner_pane, state.entries, state.index)
      end)
   end)
end)

return M
