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
    'file:///users/brian.tracey/Repos/personal/wezterm-replay'
  )

local util = require('util')
local configuration = require('configuration')
local actions = require('actions')

local function apply_to_config(config, opts)
  util.log_info('starting config')
  configuration.validate_custom_extractors(opts)
  configuration.update_with_defaults(opts)
  configuration.apply_config(config, opts)
end

local M = {
  apply_to_config = apply_to_config,
  recall = actions.recall,
  replay = actions.replay,
}

return M
