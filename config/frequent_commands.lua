local wezterm = require('wezterm')
local act = wezterm.action
local store = require('utils.frequent_commands_store')

local M = {}
local DATA_FILE = wezterm.config_dir .. '/frequent_commands.json'
local ADD_ID, MANAGE_ID, BACK_ID = '__add__', '__manage__', '__back__'
local DELETE_ID = '__delete__'
local RUN_ID_PREFIX = 'run:'
local EDIT_LABEL_PREFIX = 'edit-label:'
local EDIT_COMMAND_PREFIX = 'edit-command:'
local DELETE_PREFIX = 'delete:'
local function notify(window, message)
   wezterm.log_info(message)
   window:toast_notification('常用指令', message, nil, 4000)
end

local function notify_error(window, message)
   wezterm.log_error(message)
   window:toast_notification('常用指令', message, nil, 5000)
end

local function open_action(window, pane, action)
   window:perform_action(action, pane)
end

local function load_entries(window)
   local entries, err = store.load()
   if entries then
      return entries
   end
   notify_error(window, '加载常用指令失败：' .. tostring(err))
   return nil
end

local function save_and_continue(window, entries, success_message, on_success)
   local ok, err = store.save(entries)
   if not ok then
      notify_error(window, '保存常用指令失败：' .. tostring(err))
      return
   end
   notify(window, success_message)
   on_success()
end

local function powershell_quote(text)
   return "'" .. text:gsub("'", "''") .. "'"
end

local function launch_editor_dialog(window, mode, entry)
   local script = table.concat({
      "[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)",
      "Add-Type -AssemblyName Microsoft.VisualBasic",
      "$path = " .. powershell_quote(DATA_FILE),
      "$mode = " .. powershell_quote(mode),
      "$entries = @()",
      "if (Test-Path $path) {",
      "  $raw = Get-Content -Path $path -Encoding UTF8 -Raw",
      "  if (-not [string]::IsNullOrWhiteSpace($raw)) {",
      "    $decoded = $raw | ConvertFrom-Json",
      "    $entries = @($decoded | ForEach-Object { [pscustomobject]@{ label = [string]$_.label; command = [string]$_.command } })",
      "  }",
      "}",
      "$index = " .. tostring(entry and entry.index or -1),
      "$initialLabel = " .. powershell_quote(entry and entry.label or ''),
      "$initialCommand = " .. powershell_quote(entry and entry.command or ''),
      "if ($mode -eq 'add') {",
      "  $label = [Microsoft.VisualBasic.Interaction]::InputBox('常用指令名称', '常用指令', '')",
      "  if ([string]::IsNullOrWhiteSpace($label)) { exit 0 }",
      "  $command = [Microsoft.VisualBasic.Interaction]::InputBox('常用指令内容', '常用指令', '')",
      "  if ([string]::IsNullOrWhiteSpace($command)) { exit 0 }",
      "  $entries += [pscustomobject]@{ label = $label.Trim(); command = $command.Trim() }",
      "} elseif ($mode -eq 'edit-label' -and $index -ge 0 -and $index -lt $entries.Count) {",
      "  $label = [Microsoft.VisualBasic.Interaction]::InputBox('常用指令名称', '常用指令', $initialLabel)",
      "  if ([string]::IsNullOrWhiteSpace($label)) { exit 0 }",
      "  $entries[$index].label = $label.Trim()",
      "} elseif ($mode -eq 'edit-command' -and $index -ge 0 -and $index -lt $entries.Count) {",
      "  $command = [Microsoft.VisualBasic.Interaction]::InputBox('常用指令内容', '常用指令', $initialCommand)",
      "  if ([string]::IsNullOrWhiteSpace($command)) { exit 0 }",
      "  $entries[$index].command = $command.Trim()",
      "} else {",
      "  exit 0",
      "}",
      "$json = $entries | ConvertTo-Json -Compress",
      "[IO.File]::WriteAllText($path, $json, [Text.UTF8Encoding]::new($false))",
   }, '; ')

   wezterm.background_child_process({
      'powershell.exe',
      '-NoLogo',
      '-NoProfile',
      '-Command',
      script,
   })

   notify(window, '已打开常用指令输入框，完成后重新打开面板即可看到更新。')
end
local function build_main_choices(entries)
   local choices = {}
   for index, entry in ipairs(entries) do
      table.insert(choices, {
         id = RUN_ID_PREFIX .. tostring(index),
         label = string.format('%s :: %s', entry.label, entry.command),
      })
   end
   table.insert(choices, { id = ADD_ID, label = '新增常用指令' })
   table.insert(choices, { id = MANAGE_ID, label = '管理常用指令' })
   return choices
end

local function build_manage_choices(entries)
   local choices = {
      { id = ADD_ID, label = '新增常用指令' },
      { id = BACK_ID, label = '返回主面板' },
   }
   for index, entry in ipairs(entries) do
      table.insert(choices, {
         id = EDIT_LABEL_PREFIX .. tostring(index),
         label = '修改名称 :: ' .. entry.label,
      })
      table.insert(choices, {
         id = EDIT_COMMAND_PREFIX .. tostring(index),
         label = '修改内容 :: ' .. entry.label,
      })
      table.insert(choices, {
         id = DELETE_PREFIX .. tostring(index),
         label = '删除指令 :: ' .. entry.label,
      })
   end
   return choices
end

local show_main_panel
local show_manage_panel

local function add_entry(window, pane, entries)
   launch_editor_dialog(window, 'add')
end

local function edit_label(window, pane, entries, index)
   launch_editor_dialog(window, 'edit-label', {
      index = index - 1,
      label = entries[index].label,
   })
end

local function edit_command(window, pane, entries, index)
   launch_editor_dialog(window, 'edit-command', {
      index = index - 1,
      command = entries[index].command,
   })
end

local function delete_entry(window, pane, entries, index)
   table.remove(entries, index)
   save_and_continue(window, entries, '已删除常用指令。', function()
      show_manage_panel(window, pane, entries)
   end)
end

function show_manage_panel(window, pane, entries)
   open_action(
      window,
      pane,
      act.InputSelector({
         title = '管理常用指令',
         choices = build_manage_choices(entries),
         fuzzy = true,
         fuzzy_description = '选择要编辑的指令或操作：',
         action = wezterm.action_callback(function(inner_window, inner_pane, id)
            if id == ADD_ID then
               add_entry(inner_window, inner_pane, entries)
               return
            end
            if id == BACK_ID then
               show_main_panel(inner_window, inner_pane, entries)
               return
            end
            if type(id) == 'string' and id:find(EDIT_LABEL_PREFIX, 1, true) == 1 then
               local entry_index = tonumber(id:sub(#EDIT_LABEL_PREFIX + 1))
               edit_label(inner_window, inner_pane, entries, entry_index)
               return
            end
            if type(id) == 'string' and id:find(EDIT_COMMAND_PREFIX, 1, true) == 1 then
               local entry_index = tonumber(id:sub(#EDIT_COMMAND_PREFIX + 1))
               edit_command(inner_window, inner_pane, entries, entry_index)
               return
            end
            if type(id) == 'string' and id:find(DELETE_PREFIX, 1, true) == 1 then
               local entry_index = tonumber(id:sub(#DELETE_PREFIX + 1))
               delete_entry(inner_window, inner_pane, entries, entry_index)
            end
         end),
      })
   )
end

function show_main_panel(window, pane, entries)
   local current_entries = entries or load_entries(window)
   if not current_entries then
      return
   end
   open_action(
      window,
      pane,
      act.InputSelector({
         title = '常用指令',
         choices = build_main_choices(current_entries),
         fuzzy = true,
         fuzzy_description = '选择要注入的指令或操作：',
         action = wezterm.action_callback(function(inner_window, inner_pane, id)
            if id == ADD_ID then
               add_entry(inner_window, inner_pane, current_entries)
               return
            end
            if id == MANAGE_ID then
               show_manage_panel(inner_window, inner_pane, current_entries)
               return
            end
            if type(id) == 'string' and id:find(RUN_ID_PREFIX, 1, true) == 1 then
               local index = tonumber(id:sub(#RUN_ID_PREFIX + 1))
               local entry = current_entries[index]
               if not entry then
                  notify_error(inner_window, '没有找到选中的常用指令。')
                  return
               end
               inner_pane:send_text(entry.command)
            end
         end),
      })
   )
end

function M.action()
   return wezterm.action_callback(function(window, pane)
      show_main_panel(window, pane, nil)
   end)
end
return M
