package.path = '../?.lua;' .. package.path
zss = require'../zss'

_ENV = require('lunity')('ZSS Tests')

function test.load_two_sheets()
	local sheet = zss:new()
	sheet:add[[
		a { a:1 }
		b { b:1 }
		b.foo { foo:1 }
	]]
	sheet:add[[
		.foo { foo:2 }
		b { b:2 }
	]]
	assertEqual(sheet:match('a').a, 1)
	assertEqual(sheet:match('b').b, 2)
	assertEqual(sheet:match('a.foo').foo, 2)
	assertEqual(sheet:match('b.foo').foo, 1)
	assertTableEmpty(sheet:match('z'))
end

function test.extend_a_sheet()
	local sheet1, id1 = zss:new():add('a {a:1} b {b:1}')
	local sheet2, id2 = sheet1:extend():add('a {a:2}')
	assert(id2, 'sheet:add() must return an id')
	assertNotEqual(id1, id2, 'sheet:add() must return unique ids')
	assertEqual(sheet1:match('a').a, 1)
	assertEqual(sheet1:match('b').b, 1)
	assertEqual(sheet2:match('a').a, 2)
	assertEqual(sheet2:match('b').b, 1, 'extended sheets must inherit from their parent')

	local sheet3 = sheet1:extend('test1.css')
	assertEqual(sheet3:match('.danger').size, 18, 'should be able to pass filenames to load to extend')
end

function test.disable_own_sheet()
	local sheet = zss:new()
	local _, id1 = sheet:add'a {a:1}'
	local _, id2 = sheet:add'a {a:2}'
	assertEqual(sheet:match('a').a, 2)
	sheet:disable(id2)
	assertEqual(sheet:match('a').a, 1)
	sheet:enable(id2)
	assertEqual(sheet:match('a').a, 2)
end

function test.disable_in_parent()
	local sheet1, id1 = zss:new():add('a {a:1} b {b:1}')
	local sheet2, id2 = sheet1:extend():add('a {a:2}')
	assertEqual(sheet2:match('a').a, 2)
	assertEqual(sheet2:match('b').b, 1, '')
	sheet1:disable(id1)
	assertEqual(sheet2:match('a').a, 2)
	assertNil(sheet2:match('b').b)
	sheet1:enable(id1)
	assertEqual(sheet2:match('b').b, 1)
end

function test.disable_ancestor_sheet_in_self()
	local sheet1, id1 = zss:new():add('a {a:1} b {b:1}')
	local sheet2, id2 = sheet1:extend():add('a {a:2}')
	assertEqual(sheet2:match('a').a, 2)
	assertEqual(sheet2:match('b').b, 1)
	sheet2:disable(id1)
	assertEqual(sheet1:match('a').a, 1)
	assertEqual(sheet1:match('b').b, 1)
	assertEqual(sheet2:match('a').a, 2)
	assertNil(sheet2:match('b').b)
	sheet2:enable(id1)
	assertEqual(sheet2:match('b').b, 1)
end

local function countkeys(t)
	local i=0
	for _,_ in pairs(t) do i=i+1 end
	return i
end

-- This is a bit of an implementation test, relying on nominally internal data structures
function test.test_caching()
	local sheet = zss:new{files={'test1.css'}}
	assertTableEmpty(sheet._computed)
	for i=1,10 do sheet:match(string.format('pedestrian[ttc=%.1f]', i/10)) end
	assertEqual(countkeys(sheet._computed), 10, 'unique strings should result in unique cached computes')

	for i=1,10 do sheet:match(string.format('pedestrian[ttc=%.1f]', i/10)) end
	assertEqual(countkeys(sheet._computed), 10, 'repeated strings must not grow the cache')

	for i=1,100 do sheet:match({type='pedestrian', data={ttc=i}}) end
	assertEqual(countkeys(sheet._computed), 10, 'table-based queries must not grow the cache')
end

test()