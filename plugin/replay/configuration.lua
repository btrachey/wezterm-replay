local util = require('replay.util')
local extractors = require('replay.extractors')
local actions = require('replay.actions')

local defaults = {
  replay_key = 'r',
  recall_key = 'q',
  skip_keybinds = false,
  extractors = extractors.default_extractors,
}

local function apply_config(config, opts)
  for _, ex in ipairs(opts.extractors) do
    table.insert(extractors.all_extractors, ex)
  end
  if opts.skip_keybinds then
    util.log_info('skipping auto-setting of key bindings')
  else
    util.add_keys(config, {
      {
        key = opts.replay_key,
        mods = 'LEADER',
        action = actions.replay(),
      },
      {
        key = opts.recall_key,
        mods = 'LEADER',
        action = actions.recall(),
      },
    })
  end
end

local function update_with_defaults(conf)
  if not conf then
    return defaults
  else
    -- special handing of extractors because we need to concat first then merge
    if conf.extractors then
      for _, ex in ipairs(extractors.default_extractors) do
        util.log_info('adding default extractor ' .. ex.label)
        table.insert(conf.extractors, ex)
      end
    end
    util.table_merge(defaults, conf)
  end
end

local function create_pattern_extractor(pattern)
  return function(s)
    local matches = {}
    for match in string.gmatch(s, pattern) do
      table.insert(matches, match)
    end
    return matches
  end
end

local function validate_custom_extractors(conf)
  if conf.extractors then
    for idx, ex in ipairs(conf.extractors) do
      if ex.extractor and ex.pattern then
        error(
          util.log_msg(
            'cannot define both `extractor` and `pattern`;'
              .. (ex.label or (' index ' .. idx))
          )
        )
      elseif not ex.extractor and not ex.pattern then
        error(
          util.log_msg(
            'must define at least one of `extractor` or `pattern`;'
              .. (ex.label or (' index ' .. idx))
          )
        )
      end
      if not ex.prefix then
        util.log_info(
          'custom config '
            .. (ex.label or ('index ' .. idx))
            .. ' did not define `prefix`'
        )
      end
      if not ex.postfix then
        util.log_info(
          'custom config '
            .. (ex.label or ('index ' .. idx))
            .. ' did not define `postfix`'
        )
      end
      if ex.pattern then
        ex.extractor = create_pattern_extractor(ex.pattern)
      end
    end
  end
end

local M = {
  apply_config = apply_config,
  update_with_defaults = update_with_defaults,
  validate_custom_extractors = validate_custom_extractors,
}

return M
