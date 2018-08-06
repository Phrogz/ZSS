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

function test.inherit_a_sheet()
	local sheet1, id1 = zss:new():add('a {a:1} b {b:1}')
	local sheet2, id2 = sheet1:clone():add('a {a:2}')
	assert(id2, 'sheet:add() must return an id')
	assertNotEqual(id1, id2, 'sheet:add() must return unique ids')
	assertEqual(sheet1:match('a').a, 1)
	assertEqual(sheet1:match('b').b, 1)
	assertEqual(sheet2:match('a').a, 2)
	assertEqual(sheet2:match('b').b, 1, 'cloned sheets must inherit from their parent')
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
	local sheet2, id2 = sheet1:clone():add('a {a:2}')
	assertEqual(sheet2:match('a').a, 2)
	assertEqual(sheet2:match('b').b, 1, '')
	sheet1:disable(id1)
	assertEqual(sheet2:match('a').a, 2)
	assertNil(sheet2:match('b').b)
	sheet1:enable(id1)
	assertEqual(sheet2:match('b').b, 1)
end

function test.disable_ancstor_sheet_in_self()
	local sheet1, id1 = zss:new():add('a {a:1} b {b:1}')
	local sheet2, id2 = sheet1:clone():add('a {a:2}')
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

test{useANSI=false}