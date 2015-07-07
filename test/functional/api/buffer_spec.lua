-- Sanity checks for buffer_* API calls via msgpack-rpc
local helpers = require('test.functional.helpers')
local clear, nvim, buffer, curbuf, curwin, eq, ok =
  helpers.clear, helpers.nvim, helpers.buffer, helpers.curbuf, helpers.curwin,
  helpers.eq, helpers.ok

describe('buffer_* functions', function()
  before_each(clear)

  describe('line_count, insert and del_line', function()
    it('works', function()
      eq(1, curbuf('line_count'))
      curbuf('insert', -1, {'line'})
      eq(2, curbuf('line_count'))
      curbuf('insert', -1, {'line'})
      eq(3, curbuf('line_count'))
      curbuf('del_line', -1)
      eq(2, curbuf('line_count'))
      curbuf('del_line', -1)
      curbuf('del_line', -1)
      -- There's always at least one line
      eq(1, curbuf('line_count'))
    end)
  end)


  describe('{get,set,del}_line', function()
    it('works', function()
      eq('', curbuf('get_line', 0))
      curbuf('set_line', 0, 'line1')
      eq('line1', curbuf('get_line', 0))
      eq('', curbuf('get_line', 1))
      eq('', curbuf('get_line', -2))
      eq(false, pcall(function() curbuf('set_line', 1) end))
      eq(false, pcall(function() curbuf('set_line', -2) end))
      curbuf('set_line', 0, 'line2')
      eq('line2', curbuf('get_line', 0))
      eq(false, pcall(function() curbuf('del_line', 2) end))
      eq(false, pcall(function() curbuf('del_line', -3) end))
      curbuf('del_line', 0)
      eq('', curbuf('get_line', 0))
    end)

    it('can handle NULs', function()
      curbuf('set_line', 0, 'ab\0cd')
      eq('ab\0cd', curbuf('get_line', 0))
    end)
  end)


  describe('{get,set}_line_slice', function()
    it('works', function()
      eq({''}, curbuf('get_line_slice', 0, -1, true, true))
      -- Replace buffer
      curbuf('set_line_slice', 0, -1, true, true, {'a', 'b', 'c'})
      eq({'a', 'b', 'c'}, curbuf('get_line_slice', 0, -1, true, true))
      eq({'b', 'c'}, curbuf('get_line_slice', 1, -1, true, true))
      eq({'b'}, curbuf('get_line_slice', 1, 2, true, false))
      eq({}, curbuf('get_line_slice', 1, 1, true, false))
      eq({'a', 'b'}, curbuf('get_line_slice', 0, -1, true, false))
      eq({'b'}, curbuf('get_line_slice', 1, -1, true, false))
      eq({'b', 'c'}, curbuf('get_line_slice', -2, -1, true, true))
      eq({}, curbuf('get_line_slice', 2, 3, false, true))
      eq({}, curbuf('get_line_slice', 3, 9, true, true))
      eq({}, curbuf('get_line_slice', 3, -1, true, true))
      eq({}, curbuf('get_line_slice', -3, -4, false, true))
      eq({}, curbuf('get_line_slice', -4, -5, true, true))
      eq({'c'}, curbuf('get_line_slice', -1, 4, true, true))
      eq({'a', 'b', 'c'}, curbuf('get_line_slice', 0, 5, true, true))
      eq(false, pcall(function() curbuf('set_line_slice', 4, 5, true, true, {'d'}) end))
      eq(false, pcall(function() curbuf('set_line_slice', -4, -5, true, true, {'d'}) end))
      curbuf('set_line_slice', 1, 2, true, false, {'a', 'b', 'c'})
      eq({'a', 'a', 'b', 'c', 'c'}, curbuf('get_line_slice', 0, -1, true, true))
      curbuf('set_line_slice', -1, -1, true, true, {'a', 'b', 'c'})
      eq({'a', 'a', 'b', 'c', 'a', 'b', 'c'},
        curbuf('get_line_slice', 0, -1, true, true))
      curbuf('set_line_slice', 0, -3, true, false, {})
      eq({'a', 'b', 'c'}, curbuf('get_line_slice', 0, -1, true, true))
      curbuf('set_line_slice', 0, -1, true, true, {})
      eq({''}, curbuf('get_line_slice', 0, -1, true, true))
    end)
  end)

  describe('{get,set}_var', function()
    it('works', function()
      curbuf('set_var', 'lua', {1, 2, {['3'] = 1}})
      eq({1, 2, {['3'] = 1}}, curbuf('get_var', 'lua'))
      eq({1, 2, {['3'] = 1}}, nvim('eval', 'b:lua'))
    end)
  end)

  describe('{get,set}_option', function()
    it('works', function()
      eq(8, curbuf('get_option', 'shiftwidth'))
      curbuf('set_option', 'shiftwidth', 4)
      eq(4, curbuf('get_option', 'shiftwidth'))
      -- global-local option
      curbuf('set_option', 'define', 'test')
      eq('test', curbuf('get_option', 'define'))
      -- Doesn't change the global value
      eq([[^\s*#\s*define]], nvim('get_option', 'define'))
    end)
  end)

  describe('{get,set}_name', function()
    it('works', function()
      nvim('command', 'new')
      eq('', curbuf('get_name'))
      local new_name = nvim('eval', 'resolve(tempname())')
      curbuf('set_name', new_name)
      eq(new_name, curbuf('get_name'))
      nvim('command', 'w!')
      local f = io.open(new_name)
      ok(f ~= nil)
      f:close()
      os.remove(new_name)
    end)
  end)

  describe('is_valid', function()
    it('works', function()
      nvim('command', 'new')
      local b = nvim('get_current_buffer')
      ok(buffer('is_valid', b))
      nvim('command', 'bw!')
      ok(not buffer('is_valid', b))
    end)
  end)

  describe('get_mark', function()
    it('works', function()
      curbuf('insert', -1, {'a', 'bit of', 'text'})
      curwin('set_cursor', {3, 4})
      nvim('command', 'mark V')
      eq({3, 0}, curbuf('get_mark', 'V'))
    end)
  end)
end)
