package.path = '../?.lua;' .. package.path

zss = require'zss'
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

function test.extensions_and_values()
	local sheet1 = zss:new{constants={a=1, b=2}, basecss='a {a:a} b {b:b} c {c:c}'}
	local sheet2 = sheet1:extend():valueConstants{b=3, c=4}:add('j {a:a} k {b:b} l {c:c}')
	assertEqual(sheet1:match('a').a, 1)
	assertEqual(sheet1:match('b').b, 2)
	assertEqual(sheet1:match('c').c, 'c')
	assertEqual(sheet2:match('a').a, 1, 'extension sheets can still resolve old rules with old values')
	assertEqual(sheet2:match('b').b, 2, 'new values in an extension sheet do not change values in already-loaded rules') -- is this really desirable?
	assertEqual(sheet2:match('c').c, 'c', 'new values in an extension sheet do not change values in already-loaded rules') -- is this really desirable?
	assertEqual(sheet2:match('j').a, 1, 'extension sheets must resolve using base values')
	assertEqual(sheet2:match('k').b, 3, 'extension sheets use new values when loading new rules')
	assertEqual(sheet2:match('l').c, 4)
end

function test.extensions_and_functions()
	local f1,f2 = {},{}
	function f1.a() return 1 end
	function f1.b() return 2 end
	function f2.b() return 3 end
	function f2.c() return 4 end
	local sheet1 = zss:new{functions=f1, basecss='a {a:a()} b {b:b()} c {c:c()}'}
	local sheet2 = sheet1:extend():valueFunctions(f2):add('j {a:a()} k {b:b()} l {c:c()}')
	assertEqual(sheet1:match('a').a, 1)
	assertEqual(sheet1:match('b').b, 2)
	assertTableEquals(sheet1:match('c').c, {func='c', params={}})
	assertEqual(sheet2:match('a').a, 1)
	assertEqual(sheet2:match('b').b, 2)
	assertTableEquals(sheet2:match('c').c, {func='c', params={}}, 'extension sheets do not use new functions for old rules')
	assertEqual(sheet2:match('j').a, 1, 'extension sheets must have access to handlers from the base')
	assertEqual(sheet2:match('k').b, 3, 'extension sheets must use redefined handlers if they conflict')
	assertEqual(sheet2:match('l').c, 4, 'extension sheets must have access to their own handlers')
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

function test.at_rules()
	local sheet = zss:new():add[[
		@foo-bar { a:1; b:2 }
		@jim-jam { a:2; b:3 }
		@foo-bar { a:4; b:5 }
	]]
	assertNotNil(sheet.atrules)
	assertNotNil(sheet.atrules['@foo-bar'])
	assertEqual(#sheet.atrules['@foo-bar'], 2)
	assertEqual(sheet.atrules['@foo-bar'][1].a, 1)
	assertEqual(sheet.atrules['@foo-bar'][2].a, 4)
end

function test.atrule_handler()
	local sheet = zss:new()
	sheet:handleDirectives{
		brush = function(me, declarations)
			assertEqual(me, sheet)
			assertEqual(declarations.name,'foo')
			assertEqual(declarations.src,'bar')
			me.foundBrush = true
		end
	}
	sheet:add '@brush { name:foo; src:bar }'
	assert(sheet.foundBrush, 'handleDirectives must run when an at rule is seen')
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