local wezterm = require('wezterm')
local os = require('os')
local io = require('io')

-- extend config.keys object to not override previously defined mappings
local function add_keys(config, new_mappings)
  local orig_keys = config.keys or {}
  for _, v in ipairs(new_mappings) do
    table.insert(orig_keys, v)
  end
  config.keys = orig_keys
end

local cache_dir = wezterm.home_dir .. '/.replay.wez'
local cache_file = 'cache.json'
local cache_path = cache_dir .. '/' .. cache_file

local function cache_results(extracted_commands)
  local f = io.open(cache_path, 'w+')
  if f then
    f:write(wezterm.json_encode(extracted_commands))
    f:flush()
    f:close()
  else
    os.execute('mkdir -p ' .. cache_dir)
    local f2 = io.open(cache_path, 'w+')
    if f2 then
      f2:write(wezterm.json_encode(extracted_commands))
      f2:flush()
      f2:close()
    end
  end
end

-- return last item in an array which satisfies the predicate
local function last_by(arr, func)
  local res = nil
  for _, v in ipairs(arr) do
    if func(v) then
      res = v
    end
  end
  return res
end

local function log_msg(msg)
  return '[wezterm-replay] ' .. msg
end

local function log_info(msg)
  wezterm.log_info(log_msg(msg))
end

-- send some text to the mux pane with logging
local function send_command_string(cmd, pane)
  log_info('writing command to pane')
  log_info(cmd)
  pane:send_text(cmd)
end

-- merge two tables, keeping the "right" side values
local function table_merge(t1, t2)
  for k, v in pairs(t2) do
    if (type(v) == 'table') and (type(t1[k] or false) == 'table') then
      table_merge(t1[k], t2[k])
    else
      t1[k] = v
    end
  end
  return t1
end

local M = {
  add_keys = add_keys,
  cache_results = cache_results,
  last_by = last_by,
  log_info = log_info,
  log_msg = log_msg,
  send_command_string = send_command_string,
  table_merge = table_merge,
}

return M
