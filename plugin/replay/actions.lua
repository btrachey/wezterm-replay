local wezterm = require('wezterm')
local io = require('io')

local util = require('replay.util')
local extractors = require('replay.extractors')

local function handle_selection(window, pane, extracted_commands)
  if #extracted_commands == 0 then
    util.log_info('no commands found')
  elseif #extracted_commands == 1 then
    -- only one result? immediately send it to the prompt
    util.send_command_string(extracted_commands[1].label, pane)
  else
    util.cache_results(extracted_commands)
    window:perform_action(
      wezterm.action.InputSelector {
        action = wezterm.action_callback(
          function(_, inner_pane, _, inner_label)
            if not inner_label then
              util.log_info('selection cancelled')
            else
              util.send_command_string(inner_label, inner_pane)
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
end

local function command_choices(pane, extractors)
  local choices = {}
  local zones = pane:get_semantic_zones()
  -- this is all based off "Output" semantic zones,
  -- only works with wezterm shell integration
  local last_output_zone = util.last_by(zones, function(e)
    return e['semantic_type'] == 'Output'
  end)
  local last_output = pane:get_text_from_semantic_zone(last_output_zone)
  util.log_info('last Output: ' .. last_output)
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

local function replay()
  return wezterm.action_callback(function(window, pane, _, _)
    local extracted_commands = command_choices(pane, extractors.all_extractors)
    handle_selection(window, pane, extracted_commands)
  end)
end

local function recall()
  return wezterm.action_callback(function(window, pane, _, _)
    local extracted_commands
    local f = io.open(util.cache_path, 'r')
    if f then
      local cached = f:read()
      extracted_commands = wezterm.json_parse(cached)
    end
    handle_selection(window, pane, extracted_commands)
  end)
end

local M = { replay = replay, recall = recall }

return M
