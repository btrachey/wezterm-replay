local wezterm = require('wezterm')

local default_extractors = {
  -- commands inside `backticks`
  {
    prefix = nil,
    postfix = nil,
    func = function(s)
      local matches = {}
      for match in string.gmatch(s, '`(.*)`') do
        table.insert(matches, match)
      end
      return matches
    end,
  },
  -- regexes for opening URLs
  {
    prefix = 'open',
    postfix = nil,
    func = function(s)
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
    local extracted = extractor.func(last_output)
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

function M.apply_to_config(config, _)
  add_keys(config, {
    -- get actionable commands out of the last output
    {
      key = 'l',
      mods = 'LEADER',
      action = wezterm.action_callback(function(window, pane, _, _)
        local extracted_commands = command_choices(pane, default_extractors)
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
      end),
    },
  })
end

return M
