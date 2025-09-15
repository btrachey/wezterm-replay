local wezterm = require('wezterm')

local function find_plugin_package_path(project)
  local separator = package.config:sub(1, 1) == '\\' and '\\' or '/'
  for _, v in ipairs(wezterm.plugin.list()) do
    if v.url == project then
      return v.plugin_dir .. separator .. 'plugin' .. separator .. '?.lua'
    end
  end
end
package.path = package.path
  .. ';'
  .. find_plugin_package_path(
    'file:///Users/brian.tracey/Repos/personal/wezterm-replay'
  )

local util = require('replay.util')
local configuration = require('replay.configuration')
local actions = require('replay.actions')

local function apply_to_config(config, opts)
  util.log_info('starting config')
  configuration.validate_custom_extractors(opts)
  local merged = configuration.update_with_defaults(opts)
  configuration.apply_config(config, merged)
end

local M = {
  apply_to_config = apply_to_config,
  recall = actions.recall,
  replay = actions.replay,
}

return M
