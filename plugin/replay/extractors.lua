local M = {
  all_extractors = {},
  default_extractors = {
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
              -- make sure there's no newlines hanging around...
              string.gsub(match, '[\n\r]', '')
              table.insert(matches, match)
            end
          end
        end
        return matches
      end,
    },
  },
}

return M
