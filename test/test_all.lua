package.path = '../?.lua;' .. package.path
local print=print

local function devnull() end
zss = require'zss'
zss.debug = devnull
zss.info  = devnull
zss.warn  = devnull
zss.error = devnull

_ENV = require('lunity')('ZSS Tests')

function test.basic_parsing()
	local style = zss:new()
	style:add[[
		a1 {
			a: 0;
			b: 1;
			c: 2;
		}
		b1 { a:0; b:1; c:2; }
		c1 { a:0; b:1; c:2 }
		d1 { a:0;b:1; c:2 }
		e1 {a:0;b:1;c:2}

		a2 {
			b: 1;
			c: 2;
			d: {x=1, y=2};
			e:3;
		}
		b2 { b:1; c:2; d:{x=1, y=2}; e:3; }
		c2 { b:1; c:2; d:{x=1, y=2}; e:3 }
		d2 { b:1; c:2;d:{x=1,y=2};e:3; }
		e2 {b:1;c:2;d:{x=1,y=2};e:3}
	]]
	local expected = { a=0, b=1, c=2 }
	assertTableEquals(style:match('a1'), expected)
	assertTableEquals(style:match('b1'), expected)
	assertTableEquals(style:match('c1'), expected)
	assertTableEquals(style:match('d1'), expected)
	assertTableEquals(style:match('e1'), expected)

	local expected = { b=1, c=2, d={x=1, y=2}, e=3 }
	assertTableEquals(style:match('a2'), expected)
	assertTableEquals(style:match('b2'), expected)
	assertTableEquals(style:match('c2'), expected)
	assertTableEquals(style:match('d2'), expected)
	assertTableEquals(style:match('e2'), expected)
end

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
	local null = function() return {} end
	local style1, id1 = zss:new{constants={fx=null, rgba=null}}:add('a {a:1} b {b:1}')
	local style2, id2 = style1:extend():add('a {a:2}')
	assert(id2, 'style:add() must return an id')
	assertNotEqual(id1, id2, 'style:add() must return unique ids')
	assertEqual(style1:match('a').a, 1)
	assertEqual(style1:match('b').b, 1)
	assertEqual(style2:match('a').a, 2)
	assertEqual(style2:match('b').b, 1, 'extended styles must inherit from their parent')

	local style3 = style1:extend('danger.css')
	assertEqual(style3:match('.danger').size, 18, 'should be able to pass filenames to load to extend')

	assertNil(style1.tmpSpecialName, 'ensure that we have a clean slate for the next test')
	assertNil(style2.tmpSpecialName, 'ensure that we have a clean slate for the next test')
	style1.tmpSpecialName = 42
	assertEqual(style2.tmpSpecialName, 42, 'extended styles must inherit properties from the original')
end

function test.extensions_and_values()
	local style1 = zss:new{constants={a=1, b=2}, basecss='a {a:a} b {b:b} c {c:c}'}
	local style2 = style1:extend():constants{b=3, c=4}:add('j {a:a} k {b:b} l {c:c}')
	assertEqual(style1:match('a').a, 1)
	assertEqual(style1:match('b').b, 2)
	assertEqual(style1:match('c').c, nil)
	assertEqual(style2:match('a').a, 1, 'extension styles can still resolve old rules with old values')
	assertEqual(style2:match('b').b, 2, 'new values in an extension style do not change values in already-loaded rules') -- is this really desirable?
	assertEqual(style2:match('c').c, nil, 'new values in an extension style do not change values in already-loaded rules') -- is this really desirable?
	assertEqual(style2:match('j').a, 1, 'extension styles must resolve using base values')
	assertEqual(style2:match('k').b, 3, 'extension styles use new values when loading new rules')
	assertEqual(style2:match('l').c, 4)
end

function test.disable_own_sheet()
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

function test.disable_ancestor_sheet_in_self()
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
		@foo-bar { a:1 }
	]]
	assertEqual(style:match('@foo-bar').a, 1)
	assertNil(  style:match('bork').a, 'atrules must not be mistaken for * selectors')
end

function test.directives()
	local style = zss:new()
	style:directives{
		brush = function(me, declarations)
			assertEqual(me, style)
			assertEqual(declarations.name,'foo')
			assertEqual(declarations.src,'bar')
			me.foundBrush = true
		end
	}
	style:add '@brush { name:"foo"; src:"bar" }'
	assert(style.foundBrush, 'directives must run when an at rule is seen')

	local style = zss:new()
	style:constants{ white = 'white' }
	style:directives{ vars = function(me, props) me:constants(props) end }
	style:directives{ white = function() end }
	style:add[[
	  @vars { uiscale:1.5; fg:white }
	  text { size:12*uiscale; fill:fg }
	]]
	assertEqual(style:match('text').size, 18)
	assertEqual(style:match('text').fill, 'white')
end

function test.vars()
	local style = zss:new()
	style:constants{ a=17 }
	style:add[[
	  @vars { b:25; c:(a or 0)+25; d:(a or 0) + (b or 0); e:f; f:99; }
	  zzz { a:a; b:b; c:c; d:d; e:e; f:f; m:m; n:n; }
	  @vars { m:42; n:(a or 0)+(b or 0) }
	]]
	assertEqual(style:match('zzz').a, 17, 'styles can read from constants (a)')
	assertEqual(style:match('zzz').b, 25, 'styles can read from @vars (b)')
	assertEqual(style:match('zzz').c, 42, '@vars can read constants (c)')

	-- The behavior of variables in the same sheet depending on one another is undefined
	-- assertEqual(style:match('zzz').d, 42, '@vars can use variables already declared in the same block (d)')
	-- assertNil(style:match('zzz').e, '@vars CANNOT use variables declared later in the same block (e)')
	-- assertEqual(style:match('zzz').n, 42, '@vars can read from @vars declared previously in the same sheet (n)')

	-- Whether rules can use variables declared later in the sheet is undefined
	-- assertEqual(style:match('zzz').m, 42, 'styles can read from @vars declared later in the same sheet (m)') -- sketchy

	style:constants{ a=1 }
	assertEqual(style:match('zzz').a, 1,  'constants are updated (a2)')
	assertEqual(style:match('zzz').b, 25, '@vars not referencing constants are unaffected by constant changes (b2)')
	assertEqual(style:match('zzz').c, 26, '@vars reading constants are updated (c2)')

	-- The behavior of variables in the same sheet depending on one another is undefined
	-- assertEqual(style:match('zzz').d, 26, '@vars can use variables already declared in the same block (d2)')
	-- assertNil(style:match('zzz').e, '@vars CANNOT use variables declared later in the same block (e2)')
	-- assertEqual(style:match('zzz').n, 26, '@vars can read from @vars declared previously in the same sheet (n2)')

	-- Whether rules can use variables declared later in the sheet is undefined
	-- assertEqual(style:match('zzz').m, 42, 'styles can read from @vars declared later in the same sheet (m2)') -- sketchy

	-- Test for issue #4 edge case
	style = zss:new{basecss = [[@vars {v:c} xxx {c:c; v:v}]]}
	assertEqual(style:match('xxx').c, nil, 'constants added before parsing are nil')
	assertEqual(style:match('xxx').v, nil, 'constants added before parsing are nil')
	style:constants{ c=42 }
	assertEqual(style:match('xxx').c, 42, 'constants added after parsing update rules')
	assertEqual(style:match('xxx').v, 42, 'constants added after parsing update @vars')
end

local function countkeys(t)
	local i=0
	for _,_ in pairs(t) do i=i+1 end
	return i
end

-- This is a bit of an implementation test, relying on nominally internal data structures
function test.test_caching()
	local style = zss:new():constants{ fx=function() return {} end }:add[[
		*           { fill:none; stroke:'magenta'; stroke-width:1; font:'main' }
		.pedestrian { fill:'purple'; fill-opacity:0.3 }
		*[@ttc<1.5] { effect:fx('flash',0.2) }
	]]
	assertTableEmpty(style._computed)
	for i=1,10 do style:match(string.format('pedestrian[ttc=%.1f]', i/10)) end
	assertEqual(countkeys(style._computed), 10, 'unique strings should result in unique cached computes')

	for i=1,10 do style:match(string.format('pedestrian[ttc=%.1f]', i/10)) end
	assertEqual(countkeys(style._computed), 10, 'repeated strings must not grow the cache')

	for i=1,100 do style:match({type='pedestrian', data={ttc=i}}) end
	assertEqual(countkeys(style._computed), 10, 'table-based queries must not grow the cache')
end

function test.functions_with_values()
	local style = zss:new{
		constants = {
			x=17, y=false, yy=true,
			a = function(...) return {...} end
		},
		basecss = [[
			a { p:a() }
			b { p:a(1,2,3) }
			c { p:a(x,y,cow,yy,'yy') }
		]]
	}
	assertEqual(#style:match('a').p, 0)
	assertTableEquals(style:match('b').p, {1,2,3})
	assertTableEquals(style:match('c').p, {17,false,nil,true,'yy'})
end

function test.functions_nested()
	local style = zss:new{
		constants = {
			x=17, y=4,
			add = function(...)
				local sum=0
				for _,n in ipairs{...} do sum = sum + (tonumber(n) or 0) end
				return sum
			end
		},
		basecss = [[
			a { p:add(x,y,x,y) }
			b { p:add(add(x,y),add(y,x)) }
			c { p:add(add(@x,@y),@z) }
		]]
	}
	assertEqual(style:match('a').p, 42, 'add() function works on flat values')
	assertEqual(style:match('b').p, 42, 'nested non-placeholder functions are properly parsed and run')
	assertEqual(style:match('c[x=17][y=16][z=15]').p, 48, 'nested placeholder functions are properly parsed and run')
end

function test.functions_with_placeholders()
	local ct1, ct2 = 0,0
	local style = zss:new{
		constants = {
			ct1  = function() ct1=ct1+1 return ct1 end,
			ct2  = function() ct2=ct2+1 return ct2 end,
			add  = function(a,b) return (tonumber(a) or 0)+(tonumber(b) or 0) end,
			echo = function(n) return n end
		},
		basecss = [[
			x   { p1:add(1,2) }
			y   { p2:add(@r,17) }
			z   { p3:add(25,@s) }
			e   { p4:echo(@foo) }
			ct1 { p5:ct1()   }
			ct2 { p6:ct2(@x) }
		]]
	}
	assertEqual(style:match('x').p1, 3,  'simple functions work')
	assertEqual(style:match('y').p2, 17, 'placeholder functions "work" even without data passed')
	assertEqual(style:match('z').p3, 25, 'placeholder functions "work" even without data passed')
	assertEqual(style:match('e').p4, nil, 'placeholder functions receive no parameter if no data')
	assertEqual(style:match('e[foo=42]').p4, 42, 'placeholder functions receive data by name from attributes')
	assertEqual(style:match({type='e', data={foo=42}}).p4, 42, 'placeholder functions receive data by name')
	assertEqual(style:match('y[r=25]').p2, 42, 'values work through descriptor strings')
	assertEqual(style:match({type='y', data={r=25}}).p2, 42, 'values work through descriptor tables')
	assertEqual(style:match('z[s=17]').p3, 42, 'values work through descriptor strings')
	assertEqual(style:match({type='z', data={s=17}}).p3, 42, 'values work through descriptor tables')
	assertEqual(style:match({type='y', data={r=4}}).p2, 21, 'new values produce new results')
	assertEqual(style:match('y[r=4]').p2, 21, 'new values produce new results')

	-- assertEqual(ct1,                   1), 'parsing the rules invokes non-placeholder functions')
	assertEqual(style:match('ct1').p5, 1, 'non-placholder functions do not get re-invoked')
	assertEqual(ct1,                   1, 'non-placholder functions do not get re-invoked')

	assertEqual(ct2,                                      0, 'placholder functions do not get invoked during parsing')
	assertEqual(style:match('ct2').p6,                    1, 'placholder functions get invoked each time, regardless of data')
	assertEqual(style:match('ct2[x=1]').p6,               2, 'placholder functions get invoked each time, regardless of data')
	assertEqual(style:match({type='ct2'}).p6,             3, 'placholder functions get invoked each time, regardless of data')
	assertEqual(style:match({type='ct2', data={x=2}}).p6, 4, 'placholder functions get invoked each time, regardless of data')

	local style = zss:new{
		constants = { add=function(a,b) return a+b end },
		basecss   = [[
			a[@x=17] { p1:add(25,@x) }
			a[@x=25] { p2:add(17,@x) }
		]]
	}
	assertEqual(style:match('a[x=17]').p1, 42)
	assertEqual(style:match('a[x=25]').p2, 42)
	assertEqual(style:match('a[x=17]').p1, 42)
	assertEqual(style:match('a[x=25]').p2, 42)

	local style = zss:new():add("type[@attr] { prop:'yay'; echo:@attr }")
	assertEqual(style:match('type[@attr=17]').prop,       'yay')
	assertEqual(style:match('type[@attr=17]').echo,       17)
	assertEqual(style:match('type[@attr="x"]').prop,      'yay')
	assertEqual(style:match('type[@attr="x"]').echo,      'x')
	assertEqual(style:match("type[@attr='x']").prop,      'yay')
	assertEqual(style:match("type[@attr='x']").echo,      'x')
	assertEqual(style:match('type[@attr={a=42}]').prop,   'yay')
	assertEqual(style:match('type[@attr={a=42}]').echo.a, 42)
	assertEqual(style:match('type[@attr=true]').prop,     'yay')
	assertEqual(style:match('type[@attr=true]').echo,     true)
	assertEqual(style:match('type[@attr=false]').prop,    'yay')
	assertEqual(style:match('type[@attr=false]').echo,    false)
	assertEqual(style:match('type[@attr=nil]').prop,      nil)
	assertEqual(style:match('type[@attr=nil]').echo,      nil)
end

function test.functions_with_extensions()
	local t1,t2 = {},{}
	function t1.a() return 1 end
	function t1.b() return 2 end
	function t2.b() return 3 end
	function t2.c() return 4 end
	local style1 = zss:new{constants=t1, basecss='a {a:a()} b {b:b()} c {c:c()}'}
	local style2 = style1:extend():constants(t2):add('j {a:a()} k {b:b()} l {c:c()}')
	assertEqual(style1:match('a').a, 1)
	assertEqual(style1:match('b').b, 2)
	assertEqual(style1:match('c').c, nil)
	assertEqual(style2:match('a').a, 1)
	assertEqual(style2:match('b').b, 2)
	assertEqual(style2:match('c').c, nil, 'extension styles do not use new functions for old rules')
	assertEqual(style2:match('j').a, 1, 'extension styles must have access to handlers from the base')
	assertEqual(style2:match('k').b, 3, 'extension styles must use redefined handlers if they conflict')
	assertEqual(style2:match('l').c, 4, 'extension styles must have access to their own handlers')
end

function test.matching_simple()
	local style = zss:new{ basecss=[[
		a { a:1 }
		.b { b:1 }
		a.b { ab:1 }
		#c  { c:1 }
		a.b#c { abc:1 }
		#c.b { bc:1 }
		aa { aa:1 }
		.d { d:1 }
		.e { e:1 }
		.d.e { de:1 }
	]] }
	assertEqual(style:match('a').a,1)
	assertNil(style:match('a').ab)
	assertNil(style:match('a').aa)
	assertNil(style:match('aa').a)
	assertNil(style:match('a').c)
	assertNil(style:match('.b').ab)
	assertEqual(style:match('.b').b,1)
	assertEqual(style:match('a.b').ab,1)
	assertEqual(style:match('a.b').a,1)
	assertEqual(style:match('a.b').b,1)
	assertEqual(style:match('a#c.b').abc,1)
	assertEqual(style:match('a#c.b').c,1)
	assertEqual(style:match('a#c.b').b,1)
	assertEqual(style:match('a#c.b').a,1)
	assertEqual(style:match('#c').c,1)
	assertNil(style:match('#c').abc)
	assertNil(style:match('#c').bc)
	assertNil(style:match('#c.b').abc)
	assertEqual(style:match('#c.b').bc,1)
	assertEqual(style:match('#c.b').b,1)
	assertEqual(style:match('#c.b').c,1)
	assertEqual(style:match('.e.d').d,1)
	assertEqual(style:match('.e.d').e,1)
	assertEqual(style:match('.e.d').de,1)
	assertNil(style:match('.d').de)
end

function test.matching_attr()
	local style = zss:new():constants{x=42}:add[[
		*       { c:true }
		*[@x]   { x:@x   }
		t[@x<5] { op:'<' }
		t[@x>5] { op:'>' }
		t[@x=5] { op:'=' }
		t[5<@x] { po:'>' }
		t[5>@x] { po:'<' }
		t[5=@x] { po:'=' }
	]]

	assertEqual(style:match('z').c, true)
	assertNil(style:match('z').x,                           'constants must not leak as attributes')
	assertEqual(style:match('z[x=17]').x,               17, 'can find attributes from string')
	assertEqual(style:match{type='z', data={x=17}}.x,   17, 'can find attributes from table')
	assertNil(style:match('z[x=17]').op,                    'attributes must not ignore other selectors')
	assertEqual(style:match{type='t', data={x=5}}.op,  '=', '[@foo=42] works')
	assertEqual(style:match('t[x=5]').op,              '=', '[@foo=42] works')
	assertEqual(style:match{type='t', data={x=9}}.op,  '>', '[@foo>42] works')
	assertEqual(style:match('t[x=9]').op,              '>', '[@foo>42] works')
	assertEqual(style:match{type='t', data={x=1}}.op,  '<', '[@foo<42] works')
	assertEqual(style:match('t[x=1]').op,              '<', '[@foo<42] works')
end

function test.parsing_functions()
	local style = zss:new():constants{ x=function(t) return t end }:add[[
		a, b[@x] {
			res: x{ a=1, ['b']=2, [3]=3,
              [false]=4 }
		}
	]]
	assertTableEquals(style:match('a').res, {a=1, b=2, [3]=3, [false]=4})
end

function test.invalid_selectors()
	local style = zss:new():add[[
		t, t2     { x:'OK' }
		t[5<@x]   { x:'no' }
		t[5=@x]   { x:'no' }
		t[5>@x]   { x:'no' }
		t[true]   { x:'no' }
		t[17]     { x:'no' }
		t['@x<5'] { x:'no' }
		!t2!      { x:'no' }
		!t2       { x:'no' }
		t2!       { x:'no' }
	]]
	assertEqual(style:match('t').x,      'OK', 'invalid selectors should be ignored (1)')
	assertEqual(style:match('t[x]').x,   'OK', 'invalid selectors should be ignored (2)')
	assertEqual(style:match('t[x=1]').x, 'OK', 'invalid selectors should be ignored (3)')
	assertEqual(style:match('t2').x,     'OK', 'invalid selectors should be ignored (4)')
end

function test.lua_expressions()
	local bar = {}
	function bar:jim(x) return x end
	local style = zss:new():constants{bar=bar}:add [[
		a { foo:bar:jim(1) }
		b { foo:bar:jim(2); too: bar:jim(3); zoo:bar:jim(4); }
		c { tbl: {
					a=1,
					b = "two",
					c = bar:jim(5)
			}}
		d { tb2:bar:jim{d='{e}'}}
		/* e { tb3:bar:jim{e='{e'}} */
		/* f { tb4:bar:jim{e='e}'}} */
	]]
	assertEqual(style:match('a').foo, 1)
	assertEqual(style:match('b').foo, 2)
	assertEqual(style:match('b').too, 3)
	assertEqual(style:match('b').zoo, 4)
	assertTableEquals(style:match('c').tbl, {a=1, b="two", c=5})
	assertTableEquals(style:match('d').tb2, {d='{e}'})
	-- assertTableEquals(style:match('e').tb3, {d='{e'})
	-- assertTableEquals(style:match('f').tb4, {d='e}'})
end

function test.sketchy_parser()
	local style = zss:new():add [[
		a { a:'}' }
		b { b:';'; c:'c' }
	]]
	assertEqual(style:match('b').c, 'c', 'should be able to parse declaration after ";" seen')
	assertEqual(style:match('a').a, '}', 'should be able to parse declaration with "}" in string')
	assertEqual(style:match('b').b, ';', 'should be able to parse declaration with ";" in string')
end

function test.per_sheet_constants()
	local s = zss:new()
	local _,id1 = s:add[[
		@vars  { a:1; b:2 }
		sheet1 { a:a; b:b; c:c; d:!d; e:!e }
		@vars  { c:3; d:4 }
	]]
	assertEqual(s:match('sheet1').a, 1,   '@vars should add variables as constants')
	assertEqual(s:match('sheet1').b, 2,   '@vars should add variables as constants')
	assertEqual(s:match('sheet1').c, 3,   'static declaration before @vars still sees the vars on initial read')
	assertEqual(s:match('sheet1').d, 4,   'dynamic declaration before @vars works')
	assertEqual(s:match('sheet1').e, nil, 'dynamic declaration cleanly fails for missing @vars')

	local _,id2 = s:add[[
		@vars  { b:20; c:30; q:d and d+1 or 'fresh'; e:50 }
		sheet2 { a:a; b:b; c:c; q:!q; e:!e }
	]]
	assertEqual(s:match('sheet1').b, 2,   'static declarations using @vars are not affected by loading a later sheet')
	assertEqual(s:match('sheet1').d, 4,   'dynamic declarations in earlier sheet do NOT access constants in later sheets')
	assertEqual(s:match('sheet1').e, nil, 'dynamic declarations in earlier sheet do NOT access constants in later sheets')

	assertEqual(s:match('sheet2').a, 1,   'static declarations can read constants from earlier sheets')
	assertEqual(s:match('sheet2').b, 20,  'new static declarations can read new constants')
	assertEqual(s:match('sheet2').c, 30,  'new static declarations can read new constants')
	assertEqual(s:match('sheet2').q, 5,   '@vars can read values from previously-loaded sheets')
	assertEqual(s:match('sheet2').e, 50)

	local _,id3 = s:add[[
		sheet3 { a:a; b:b; c:c; d:!d; e:!e; q:q }
	]]
	assertEqual(s:match('sheet3').a, 1,  'declarations have access to constants from previously-loaded sheets')
	assertEqual(s:match('sheet3').b, 20, 'declarations have access to constants from previously-loaded sheets')
	assertEqual(s:match('sheet3').c, 30, 'declarations have access to constants from previously-loaded sheets')
	assertEqual(s:match('sheet3').d, 4,  'declarations have access to constants from previously-loaded sheets')
	assertEqual(s:match('sheet3').e, 50, 'declarations have access to constants from previously-loaded sheets')
	assertEqual(s:match('sheet3').q, 5,  'declarations have access to constants from previously-loaded sheets')

	s:disable(id1)
	assertTableEmpty(s:match('sheet1'),       'disabling a sheet removes its rules')
	assertEqual(s:match('sheet2').a, nil)
	assertEqual(s:match('sheet2').a, nil,     'disabling a sheet prevents access to the constants from that sheet, and forces reevaluation of static declarations')
	assertEqual(s:match('sheet2').b, 20,      'constants are still visible')
	assertEqual(s:match('sheet2').c, 30,      'constants are still visible')
	assertEqual(s:match('sheet2').q, 'fresh')
	assertEqual(s:match('sheet2').q, 'fresh', 'constants are re-evaluated when an earlier sheet is disabled')
	assertEqual(s:match('sheet2').e, 50)

	assertEqual(s:match('sheet3').a, nil,     'disabling a sheet prevents access to the constants from that sheet, and forces reevaluation of static declarations')
	assertEqual(s:match('sheet3').b, 20,      'inherited constants are still visible')
	assertEqual(s:match('sheet3').c, 30,      'inherited constants are still visible')
	assertEqual(s:match('sheet3').q, 'fresh', 'inherited constants are still visible')
	assertEqual(s:match('sheet3').e, 50,      'inherited constants are still visible')

	s:enable(id1)

	assertEqual(s:match('sheet2').a, 1,   'static declarations can read constants from earlier sheets')
	assertEqual(s:match('sheet2').b, 20,  'new static declarations can read new constants')
	assertEqual(s:match('sheet2').c, 30,  'new static declarations can read new constants')
	assertEqual(s:match('sheet2').q, 5,   '@vars can read values from previously-loaded sheets')
	assertEqual(s:match('sheet2').e, 50)

	s:disable(id2)

	assertEqual(s:match('sheet1').a, 1,   're-enabling a sheet allows vars to work')
	assertEqual(s:match('sheet1').b, 2,   're-enabling a sheet allows vars to work')
	assertEqual(s:match('sheet1').c, 3,   're-enabling a sheet still evaluates correctly')
	assertEqual(s:match('sheet1').d, 4,   're-enabling a sheet allows dynamic declarations to work')
	assertEqual(s:match('sheet1').e, nil, 're-enabling a sheet still does not allow access to constants in later sheets')

	assertEqual(s:match('sheet3').a, 1,   'disabling a sheet prevents access to the constants from that sheet, and forces reevaluation of static declarations')
	assertEqual(s:match('sheet3').b, 2,   'inherited constants are still visible')
	assertEqual(s:match('sheet3').c, 3,   'inherited constants are still visible')
	assertEqual(s:match('sheet3').d, 4,   'inherited constants are still visible')
	assertEqual(s:match('sheet3').e, nil, 'inherited constants are still visible')

	local css = "@vars {cats:42} house {cats:cats; veryfine:true}"
	local s1 = zss:new():add(css)
	assertTableEquals(s1:match('house'), {cats=42, veryfine=true}, 'Adding CSS through add() can read per-sheet constants')

	local s2 = zss:new{basecss=css}
	assertTableEquals(s2:match('house'), {cats=42, veryfine=true}, 'Adding CSS through basecss can read per-sheet constants')
end

function test.function_call_parse()
	local s = zss:new():constants{
		echo = function(t) return t end
	}:add[[
		s1 { a:1; b:2; t:echo{'abc', x=1, y=2, z=3, s='more'} }
		s2 { t:echo{'abc', x=1, y=2, z=3, s='more'}; a:1; b:2}
		s4 {
			a: 1;
			t: echo{'abc', x=1, y=2, z=3, s='more'};
			b: 2;
		}
		s3 { a:1;
			t: echo{'abc', x=1, y=2, z=3, s='more'}
			; b:2
		}
	]]
	local expected = {a=1, b=2, t={'abc', x=1, y=2, z=3, s='more'}}
	assertTableEquals(s:match('s1'), expected)
	assertTableEquals(s:match('s2'), expected)
	assertTableEquals(s:match('s3'), expected)
	assertTableEquals(s:match('s4'), expected)
end

test{ quiet=true }