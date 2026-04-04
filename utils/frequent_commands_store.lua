local wezterm = require('wezterm')

---@class FrequentCommand
---@field label string
---@field command string

local M = {}

local DATA_FILE = wezterm.config_dir .. '/frequent_commands.json'

---@type FrequentCommand[]
local DEFAULT_COMMANDS = {
   { label = '显示当前目录', command = 'pwd' },
   { label = '列出文件', command = 'ls' },
}

---@return string
local function encode_json(value)
   if wezterm.json_encode then
      return wezterm.json_encode(value)
   end
   return wezterm.serde.json_encode(value)
end

---@return FrequentCommand[]
local function clone_default_commands()
   local entries = {}
   for _, entry in ipairs(DEFAULT_COMMANDS) do
      table.insert(entries, {
         label = entry.label,
         command = entry.command,
      })
   end
   return entries
end

---@param path string
---@return string|nil
---@return string|nil
local function read_file(path)
   local file, err = io.open(path, 'rb')
   if not file then
      return nil, err
   end

   local content = file:read('*a')
   file:close()
   return content, nil
end

---@param path string
---@param content string
---@return boolean
---@return string|nil
local function write_file(path, content)
   local file, err = io.open(path, 'wb')
   if not file then
      return false, err
   end

   file:write(content)
   file:close()
   return true, nil
end

---@param err string|nil
---@return boolean
local function is_missing_file_error(err)
   if type(err) ~= 'string' then
      return false
   end

   return err:find('No such file', 1, true) ~= nil
      or err:find('cannot find the path', 1, true) ~= nil
      or err:find('cannot find the file', 1, true) ~= nil
      or err:find('No such file or directory', 1, true) ~= nil
end

---@param value string|nil
---@return string|nil
function M.require_text(value)
   if type(value) ~= 'string' then
      return nil
   end

   local trimmed = value:match('^%s*(.-)%s*$')
   if trimmed == '' then
      return nil
   end

   return trimmed
end

---@param value any
---@return FrequentCommand[]|nil
---@return string|nil
local function normalize_entries(value)
   if type(value) ~= 'table' then
      return nil, '常用指令注册表必须是 JSON 数组'
   end

   local entries = {}
   for index, entry in ipairs(value) do
      if type(entry) ~= 'table' then
         return nil, string.format('第 %d 项必须是对象', index)
      end

      local label = M.require_text(entry.label)
      local command = M.require_text(entry.command)
      if not label then
         return nil, string.format('第 %d 项缺少有效的名称', index)
      end
      if not command then
         return nil, string.format('第 %d 项缺少有效的指令内容', index)
      end

      table.insert(entries, {
         label = label,
         command = command,
      })
   end

   return entries, nil
end

---@param entries FrequentCommand[]
---@return boolean
---@return string|nil
function M.save(entries)
   return write_file(DATA_FILE, encode_json(entries))
end

---@return FrequentCommand[]|nil
---@return string|nil
function M.load()
   local content, read_err = read_file(DATA_FILE)
   if not content then
      if not is_missing_file_error(read_err) then
         return nil, read_err
      end

      local defaults = clone_default_commands()
      local ok, write_err = M.save(defaults)
      if not ok then
         return nil, write_err
      end
      return defaults, nil
   end

   local ok, decoded = pcall(wezterm.json_parse, content)
   if not ok then
      return nil, decoded
   end

   return normalize_entries(decoded)
end

return M
