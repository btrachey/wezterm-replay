local wezterm = require('wezterm')
local os = require('os')
local io = require('io')

local cache_dir = wezterm.home_dir .. '/.replay.wez'
local cache_file = 'cache.json'
local cache_path = cache_dir .. '/' .. cache_file

local all_extractors
local default_extractors = {
  -- commands inside `backticks`
  {
    label = 'backticks',
    prefix = nil,
    postfix = nil,
    extractor = function(s)
      local matches = {}
      for match in string.gmatch(s, '`(.*)`') do
        table.insert(matches, match)
      end
      return matches
    end,
  },
  -- regexes for opening URLs
  {
    label = 'URIs',
    prefix = 'open',
    postfix = nil,
    extractor = function(s)
      local url_regexes = {
        '%((%w+://%S+)%)',
        '%[(%w+://%S+)%]',
        '%{(%w+://%S+)%}',
        '%<(%w+://%S+)%>',
        '%w+://%S+',
      }
      local matches = {}
      for _, regex in ipairs(url_regexes) do
        for match in string.gmatch(s, regex) do
          if match and #match > 0 then
            wezterm.log_info('a match: ' .. match)
            -- make sure there's no newlines hanging around...
            string.gsub(match, '[\n\r]', '')
            table.insert(matches, match)
          end
        end
      end
      return matches
    end,
  },
}

-- extend config.keys object to not override previously defined mappings
local function add_keys(config, new_mappings)
  local orig_keys = config.keys or {}
  for _, v in ipairs(new_mappings) do
    table.insert(orig_keys, v)
  end
  config.keys = orig_keys
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

-- send some text to the mux pane with logging
local function send_command_string(cmd, pane)
  wezterm.log_info('writing command to pane')
  wezterm.log_info(cmd)
  pane:send_text(cmd)
end

-- generate the list of possible commands to send
local function command_choices(pane, extractors)
  local choices = {}
  local zones = pane:get_semantic_zones()
  -- this is all based off "Output" semantic zones,
  -- only works with wezterm shell integration
  local last_output_zone = last_by(zones, function(e)
    return e['semantic_type'] == 'Output'
  end)
  local last_output = pane:get_text_from_semantic_zone(last_output_zone)
  wezterm.log_info('last Output: ' .. last_output)
  for _, extractor in ipairs(extractors) do
    local extracted = extractor.extractor(last_output)
    for _, ex in ipairs(extracted) do
      local label_prefix = ''
      if extractor.prefix then
        label_prefix = extractor.prefix .. ' '
      end
      local label_postfix = ''
      if extractor.postfix then
        label_postfix = ' ' .. extractor.prefix
      end
      table.insert(choices, {
        label = label_prefix .. ex .. label_postfix,
      })
    end
  end
  return choices
end

local M = {}

function M.recall()
  return wezterm.action_callback(function(window, pane, _, _)
    local extracted_commands
    local f = io.open(cache_path, 'r')
    if f then
      local cached = f:read()
      extracted_commands = wezterm.json_parse(cached)
    end
    if #extracted_commands == 0 then
      wezterm.log_info('no commands found')
    elseif #extracted_commands == 1 then
      -- only one result? immediately send it to the prompt
      send_command_string(extracted_commands[1].label, pane)
    else
      -- use the wezterm built-in selection mechanism
      window:perform_action(
        wezterm.action.InputSelector {
          action = wezterm.action_callback(
            function(_, inner_pane, _, inner_label)
              if not inner_label then
                wezterm.log_info('cancelled')
              else
                send_command_string(inner_label, inner_pane)
              end
            end
          ),
          title = 'Replay Command',
          choices = extracted_commands,
          alphabet = '123456789',
          description = 'Send command to pane; press / to search.',
        },
        pane
      )
    end
  end)
end

function M.replay()
  return wezterm.action_callback(function(window, pane, _, _)
    local extracted_commands = command_choices(pane, all_extractors)
    if #extracted_commands == 0 then
      wezterm.log_info('no commands found')
    elseif #extracted_commands == 1 then
      -- only one result? immediately send it to the prompt
      send_command_string(extracted_commands[1].label, pane)
    else
      -- cache the list so it can be re-used later
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

      -- use the wezterm built-in selection mechanism
      window:perform_action(
        wezterm.action.InputSelector {
          action = wezterm.action_callback(
            function(_, inner_pane, _, inner_label)
              if not inner_label then
                wezterm.log_info('cancelled')
              else
                send_command_string(inner_label, inner_pane)
              end
            end
          ),
          title = 'Replay Command',
          choices = extracted_commands,
          alphabet = '123456789',
          description = 'Send command to pane; press / to search.',
        },
        pane
      )
    end
  end)
end

function M.apply_to_config(config, opts)
  for idx, c in ipairs(opts.extractors) do
    assert(
      c.extractor,
      'replay.wez: you must at least define a `func` extractor for custom config '
        .. (c.label or ('index ' .. idx))
    )
    if not c.prefix then
      wezterm.log_info(
        'replay.wez: custom config '
          .. (c.label or ('index ' .. idx))
          .. ' did not define `prefix`'
      )
    end
    if not c.postfix then
      wezterm.log_info(
        'replay.wez: custom config '
          .. (c.label or ('index ' .. idx))
          .. ' did not define `postfix`'
      )
    end
    table.insert(all_extractors, c)
  end
  for _, c in ipairs(default_extractors) do
    wezterm.log_info('adding default extractor ' .. c.label)
    table.insert(all_extractors, c)
  end
  add_keys(config, {
    {
      key = (opts.replay_key or 'l'),
      mods = 'LEADER',
      action = M.replay(),
    },
    {
      key = (opts.recall_key or 'u'),
      mods = 'LEADER',
      action = M.recall(),
    },
  })
end

return M
