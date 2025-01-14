local M = {}

function M.get_chars_after_cursor(length)
  length = length or 1
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line_content = vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]
  return line_content:sub(col + 1, col + length)
end

function M.get_chars_before_cursor(colnums_before, length)
  length = length or 1
  if colnums_before < length then
    return nil
  end
  local content_before = M.get_content_before_cursor(colnums_before - length)
  if not content_before then
    return nil
  end
  return content_before:sub(-length, -1)
end

function M.get_content_before_cursor(shift)
  shift = shift or 0
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  if col < shift then
    return nil
  end
  local line_content = vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]
  return line_content:sub(1, col - shift)
end

function M.probe_punctuation_after_half_symbol()
  local content_before = M.get_content_before_cursor(1) or "";
  local word_pre1 = M.get_chars_before_cursor(1, 1)
  local word_pre2 = M.get_chars_before_cursor(2, 1)
  if not (word_pre1 and word_pre1:match "[-%p]") then
    return false
  elseif
      not word_pre2 or word_pre2 == ""
      or word_pre2:match('[-%s%p]')
      or (word_pre2:match('%w') and content_before:match('%s%w+$'))
      or (word_pre2:match('%w') and content_before:match('^%w+$'))
  then
    return true
  else
    return false
  end
end

function M.probe_caps_start()
  if M.get_content_before_cursor():match "[A-Z][%w]*%s*$" then
    return true
  else
    return false
  end
end

return M

-- vim: ft=lua ts=2 sw=2 et:
