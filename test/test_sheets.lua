package.path = '../?.lua;' .. package.path

zss = require'zss'
_ENV = require('lunity')('ZSS Tests')

function test.load_two_sheets()
	local style = zss:new()
	style:add[[
		a { a:1 }
		b { b:1 }
		b.foo { foo:1 }
	]]
	style:add[[
		.foo { foo:2 }
		b { b:2 }
	]]
	assertEqual(style:match('a').a, 1)
	assertEqual(style:match('b').b, 2)
	assertEqual(style:match('a.foo').foo, 2)
	assertEqual(style:match('b.foo').foo, 1)
	assertTableEmpty(style:match('z'))
end

function test.extend_a_style()
	local style1, id1 = zss:new():add('a {a:1} b {b:1}')
	local style2, id2 = style1:extend():add('a {a:2}')
	assert(id2, 'style:add() must return an id')
	assertNotEqual(id1, id2, 'style:add() must return unique ids')
	assertEqual(style1:match('a').a, 1)
	assertEqual(style1:match('b').b, 1)
	assertEqual(style2:match('a').a, 2)
	assertEqual(style2:match('b').b, 1, 'extended styles must inherit from their parent')

	local style3 = style1:extend('test1.css')
	assertEqual(style3:match('.danger').size, 18, 'should be able to pass filenames to load to extend')
end

function test.extensions_and_values()
	local style1 = zss:new{constants={a=1, b=2}, basecss='a {a:a} b {b:b} c {c:c}'}
	local style2 = style1:extend():valueConstants{b=3, c=4}:add('j {a:a} k {b:b} l {c:c}')
	assertEqual(style1:match('a').a, 1)
	assertEqual(style1:match('b').b, 2)
	assertEqual(style1:match('c').c, 'c')
	assertEqual(style2:match('a').a, 1, 'extension styles can still resolve old rules with old values')
	assertEqual(style2:match('b').b, 2, 'new values in an extension style do not change values in already-loaded rules') -- is this really desirable?
	assertEqual(style2:match('c').c, 'c', 'new values in an extension style do not change values in already-loaded rules') -- is this really desirable?
	assertEqual(style2:match('j').a, 1, 'extension styles must resolve using base values')
	assertEqual(style2:match('k').b, 3, 'extension styles use new values when loading new rules')
	assertEqual(style2:match('l').c, 4)
end

function test.disable_own_style()
	local style = zss:new()
	local _, id1 = style:add'a {a:1}'
	local _, id2 = style:add'a {a:2}'
	assertEqual(style:match('a').a, 2)
	style:disable(id2)
	assertEqual(style:match('a').a, 1)
	style:enable(id2)
	assertEqual(style:match('a').a, 2)
end

function test.disable_in_parent()
	local style1, id1 = zss:new():add('a {a:1} b {b:1}')
	local style2, id2 = style1:extend():add('a {a:2}')
	assertEqual(style2:match('a').a, 2)
	assertEqual(style2:match('b').b, 1, '')
	style1:disable(id1)
	assertEqual(style2:match('a').a, 2)
	assertNil(style2:match('b').b)
	style1:enable(id1)
	assertEqual(style2:match('b').b, 1)
end

function test.disable_ancestor_style_in_self()
	local style1, id1 = zss:new():add('a {a:1} b {b:1}')
	local style2, id2 = style1:extend():add('a {a:2}')
	assertEqual(style2:match('a').a, 2)
	assertEqual(style2:match('b').b, 1)
	style2:disable(id1)
	assertEqual(style1:match('a').a, 1)
	assertEqual(style1:match('b').b, 1)
	assertEqual(style2:match('a').a, 2)
	assertNil(style2:match('b').b)
	style2:enable(id1)
	assertEqual(style2:match('b').b, 1)
end

function test.at_rules()
	local style = zss:new():add[[
		@foo-bar { a:1; b:2 }
		@jim-jam { a:2; b:3 }
		@foo-bar { a:4; b:5 }
	]]
	assertNotNil(style.atrules)
	assertNotNil(style.atrules['@foo-bar'])
	assertEqual(#style.atrules['@foo-bar'], 2)
	assertEqual(style.atrules['@foo-bar'][1].a, 1)
	assertEqual(style.atrules['@foo-bar'][2].a, 4)
end

function test.atrule_handler()
	local style = zss:new()
	style:handleDirectives{
		brush = function(me, declarations)
			assertEqual(me, style)
			assertEqual(declarations.name,'foo')
			assertEqual(declarations.src,'bar')
			me.foundBrush = true
		end
	}
	style:add '@brush { name:foo; src:bar }'
	assert(style.foundBrush, 'handleDirectives must run when an at rule is seen')
end

local function countkeys(t)
	local i=0
	for _,_ in pairs(t) do i=i+1 end
	return i
end

-- This is a bit of an implementation test, relying on nominally internal data structures
function test.test_caching()
	local style = zss:new{files={'test1.css'}}
	assertTableEmpty(style._computed)
	for i=1,10 do style:match(string.format('pedestrian[ttc=%.1f]', i/10)) end
	assertEqual(countkeys(style._computed), 10, 'unique strings should result in unique cached computes')

	for i=1,10 do style:match(string.format('pedestrian[ttc=%.1f]', i/10)) end
	assertEqual(countkeys(style._computed), 10, 'repeated strings must not grow the cache')

	for i=1,100 do style:match({type='pedestrian', data={ttc=i}}) end
	assertEqual(countkeys(style._computed), 10, 'table-based queries must not grow the cache')
end

test()