package.path = '../?.lua;' .. package.path
local print=print

-- Hide all output from the library
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
	assertTableEquals(style:match{type='a1'}, expected)
	assertTableEquals(style:match{type='b1'}, expected)
	assertTableEquals(style:match{type='c1'}, expected)
	assertTableEquals(style:match{type='d1'}, expected)
	assertTableEquals(style:match{type='e1'}, expected)

	local expected = { b=1, c=2, d={x=1, y=2}, e=3 }
	assertTableEquals(style:match{type='a2'}, expected)
	assertTableEquals(style:match{type='b2'}, expected)
	assertTableEquals(style:match{type='c2'}, expected)
	assertTableEquals(style:match{type='d2'}, expected)
	assertTableEquals(style:match{type='e2'}, expected)
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
	assertEqual(style:match{type='a'}.a, 1)
	assertEqual(style:match{type='b'}.b, 2)
	assertEqual(style:match{type='a', tags={foo=1}}.foo, 2)
	assertEqual(style:match{type='b', tags={foo=1}}.foo, 1)
	assertTableEmpty(style:match{type='z'})
end

function test.extend_a_style()
	local null = function() return {} end
	local style1, id1 = zss:new{constants={fx=null, rgba=null}}:add('a {a:1} b {b:1}')
	local style2, id2 = style1:extend():add('a {a:2}')
	assert(id2, 'style:add() must return an id')
	assertNotEqual(id1, id2, 'style:add() must return unique ids')
	assertEqual(style1:match{type='a'}.a, 1)
	assertEqual(style1:match{type='b'}.b, 1)
	assertEqual(style2:match{type='a'}.a, 2)
	assertEqual(style2:match{type='b'}.b, 1, 'extended styles must inherit from their parent')

	local style3 = style1:extend('danger.css')
	assertEqual(style3:match{tags={danger=1}}.size, 18, 'should be able to pass filenames to load to extend')

	assertNil(style1.tmpSpecialName, 'ensure that we have a clean slate for the next test')
	assertNil(style2.tmpSpecialName, 'ensure that we have a clean slate for the next test')
	style1.tmpSpecialName = 42
	assertEqual(style2.tmpSpecialName, 42, 'extended styles must inherit properties from the original')
end

function test.extensions_and_values()
	local style1 = zss:new{constants={a=1, b=2}, basecss='a {a:a} b {b:b} c {c:c}'}
	local style2 = style1:extend():constants{b=3, c=4}:add('j {a:a} k {b:b} l {c:c}')
	assertEqual(style1:match{type='a'}.a, 1)
	assertEqual(style1:match{type='b'}.b, 2)
	assertEqual(style1:match{type='c'}.c, nil)
	assertEqual(style2:match{type='a'}.a, 1, 'extension styles can still resolve old rules with old values')
	assertEqual(style2:match{type='b'}.b, 2, 'new values in an extension style do not change values in already-loaded rules') -- is this really desirable?
	assertEqual(style2:match{type='c'}.c, nil, 'new values in an extension style do not change values in already-loaded rules') -- is this really desirable?
	assertEqual(style2:match{type='j'}.a, 1, 'extension styles must resolve using base values')
	assertEqual(style2:match{type='k'}.b, 3, 'extension styles use new values when loading new rules')
	assertEqual(style2:match{type='l'}.c, 4)
end

function test.disable_own_sheet()
	local style = zss:new()
	local _, id1 = style:add'a {a:1}'
	local _, id2 = style:add'a {a:2}'
	assertEqual(style:match{type='a'}.a, 2)
	style:disable(id2)
	assertEqual(style:match{type='a'}.a, 1)
	style:enable(id2)
	assertEqual(style:match{type='a'}.a, 2)
end

function test.disable_in_parent()
	local style1, id1 = zss:new():add('a {a:1} b {b:1}')
	local style2, id2 = style1:extend():add('a {a:2}')
	assertEqual(style2:match{type='a'}.a, 2)
	assertEqual(style2:match{type='b'}.b, 1, '')
	style1:disable(id1)
	assertEqual(style2:match{type='a'}.a, 2)
	assertNil(style2:match{type='b'}.b)
	style1:enable(id1)
	assertEqual(style2:match{type='b'}.b, 1)
end

function test.disable_ancestor_sheet_in_self()
	local style1, id1 = zss:new():add('a {a:1} b {b:1}')
	local style2, id2 = style1:extend():add('a {a:2}')
	assertEqual(style2:match{type='a'}.a, 2)
	assertEqual(style2:match{type='b'}.b, 1)
	style2:disable(id1)
	assertEqual(style1:match{type='a'}.a, 1)
	assertEqual(style1:match{type='b'}.b, 1)
	assertEqual(style2:match{type='a'}.a, 2)
	assertNil(style2:match{type='b'}.b)
	style2:enable(id1)
	assertEqual(style2:match{type='b'}.b, 1)
end

function test.at_rules()
	local style = zss:new():add[[
		@foo-bar { a:1 }
	]]
	assertEqual(style:match{type='@foo-bar'}.a, 1)
	assertNil(  style:match{type='bork'}.a, 'atrules must not be mistaken for * selectors')
	assertNil(  style:match{type='foo-bar'}.a, 'atrules must not be mistaken for type selectors')
	assertNil(  style:match{id='foo-bar'}.a, 'atrules must not be mistaken for #selectors')
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
	assertEqual(style:match{type='text'}.size, 18)
	assertEqual(style:match{type='text'}.fill, 'white')
end

function test.vars()
	local style = zss:new()
	style:constants{ a=17 }
	style:add[[
	  @vars { b:25; c:(a or 0)+25; d:(a or 0) + (b or 0); e:f; f:99; }
	  zzz { a:a; b:b; c:c; d:d; e:e; f:f; m:m; n:n; }
	  @vars { m:42; n:(a or 0)+(b or 0) }
	]]
	assertEqual(style:match{type='zzz'}.a, 17, 'styles can read from constants (a)')
	assertEqual(style:match{type='zzz'}.b, 25, 'styles can read from @vars (b)')
	assertEqual(style:match{type='zzz'}.c, 42, '@vars can read constants (c)')

	-- The behavior of variables in the same sheet depending on one another is undefined
	-- assertEqual(style:match{type='zzz'}.d, 42, '@vars can use variables already declared in the same block (d)')
	-- assertNil(style:match{type='zzz'}.e, '@vars CANNOT use variables declared later in the same block (e)')
	-- assertEqual(style:match{type='zzz'}.n, 42, '@vars can read from @vars declared previously in the same sheet (n)')

	-- Whether rules can use variables declared later in the sheet is undefined
	-- assertEqual(style:match{type='zzz'}.m, 42, 'styles can read from @vars declared later in the same sheet (m)') -- sketchy

	style:constants{ a=1 }
	assertEqual(style:match{type='zzz'}.a, 1,  'constants are updated (a2)')
	assertEqual(style:match{type='zzz'}.b, 25, '@vars not referencing constants are unaffected by constant changes (b2)')
	assertEqual(style:match{type='zzz'}.c, 26, '@vars reading constants are updated (c2)')

	-- The behavior of variables in the same sheet depending on one another is undefined
	-- assertEqual(style:match{type='zzz'}.d, 26, '@vars can use variables already declared in the same block (d2)')
	-- assertNil(style:match{type='zzz'}.e, '@vars CANNOT use variables declared later in the same block (e2)')
	-- assertEqual(style:match{type='zzz'}.n, 26, '@vars can read from @vars declared previously in the same sheet (n2)')

	-- Whether rules can use variables declared later in the sheet is undefined
	-- assertEqual(style:match{type='zzz'}.m, 42, 'styles can read from @vars declared later in the same sheet (m2)') -- sketchy

	-- Test for issue #4 edge case
	style = zss:new{basecss = [[@vars {v:c} xxx {c:c; v:v}]]}
	assertEqual(style:match{type='xxx'}.c, nil, 'constants added before parsing are nil')
	assertEqual(style:match{type='xxx'}.v, nil, 'constants added before parsing are nil')
	style:constants{ c=42 }
	assertEqual(style:match{type='xxx'}.c, 42, 'constants added after parsing update rules')
	assertEqual(style:match{type='xxx'}.v, 42, 'constants added after parsing update @vars')
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
	assertEqual(#style:match{type='a'}.p, 0)
	assertTableEquals(style:match{type='b'}.p, {1,2,3})
	assertTableEquals(style:match{type='c'}.p, {17,false,nil,true,'yy'})
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
	assertEqual(style:match{type='a'}.p, 42, 'add() function works on flat values')
	assertEqual(style:match{type='b'}.p, 42, 'nested non-placeholder functions are properly parsed and run')
	assertEqual(style:match{type='c', x=17, y=16, z=15}.p, 48, 'nested placeholder functions are properly parsed and run')
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
	assertEqual(style:match{type='x'}.p1, 3,  'simple functions work')
	assertEqual(style:match{type='y'}.p2, 17, 'placeholder functions "work" even without data passed')
	assertEqual(style:match{type='z'}.p3, 25, 'placeholder functions "work" even without data passed')
	assertEqual(style:match{type='e'}.p4, nil, 'placeholder functions receive no parameter if no data')
	assertEqual(style:match{type='e', foo=42}.p4, 42, 'placeholder functions receive data by name from attributes')
	assertEqual(style:match{type='y', r=25}.p2, 42, 'values work through descriptor strings')
	assertEqual(style:match{type='z', s=17}.p3, 42, 'values work through descriptor strings')
	assertEqual(style:match{type='y', r=4}.p2, 21, 'new values produce new results')

	-- assertEqual(ct1,                   1), 'parsing the rules invokes non-placeholder functions')
	assertEqual(style:match{type='ct1'}.p5, 1, 'non-placholder functions do not get re-invoked')
	assertEqual(ct1,                   1, 'non-placholder functions do not get re-invoked')

	assertEqual(ct2,                             0, 'placholder functions do not get invoked during parsing')
	assertEqual(style:match{type='ct2'}.p6,      1, 'placholder functions get invoked each time, regardless of data')
	assertEqual(style:match{type='ct2', x=1}.p6, 2, 'placholder functions get invoked each time, regardless of data')
	assertEqual(style:match{type='ct2'}.p6,      3, 'placholder functions get invoked each time, regardless of data')
	assertEqual(style:match{type='ct2', x=2}.p6, 4, 'placholder functions get invoked each time, regardless of data')

	local style = zss:new{
		constants = { add=function(a,b) return a+b end },
		basecss   = [[
			a[@x==17] { p1:add(25,@x) }
			a[@x==25] { p2:add(17,@x) }
		]]
	}
	assertEqual(style:match{type='a', x=17}.p1, 42)
	assertEqual(style:match{type='a', x=25}.p2, 42)
	assertEqual(style:match{type='a', x=17}.p1, 42)
	assertEqual(style:match{type='a', x=25}.p2, 42)

	local style = zss:new():add("type[@attr] { prop:'yay'; echo:@attr }")
	assertEqual(style:match{type='type', attr=17}.prop,       'yay')
	assertEqual(style:match{type='type', attr=17}.echo,       17)
	assertEqual(style:match{type='type', attr='x'}.prop,      'yay')
	assertEqual(style:match{type='type', attr='x'}.echo,      'x')
	assertEqual(style:match{type='type', attr='x'}.prop,      'yay')
	assertEqual(style:match{type='type', attr='x'}.echo,      'x')
	assertEqual(style:match{type='type', attr={a=42}}.prop,   'yay')
	assertEqual(style:match{type='type', attr={a=42}}.echo.a, 42)
	assertEqual(style:match{type='type', attr=true}.prop,     'yay')
	assertEqual(style:match{type='type', attr=true}.echo,     true)
	assertEqual(style:match{type='type', attr=false}.prop,    'yay')
	assertEqual(style:match{type='type', attr=false}.echo,    false)
	assertEqual(style:match{type='type', attr=nil}.prop,      nil)
	assertEqual(style:match{type='type', attr=nil}.echo,      nil)
end

function test.functions_with_extensions()
	local t1,t2 = {},{}
	function t1.a() return 1 end
	function t1.b() return 2 end
	function t2.b() return 3 end
	function t2.c() return 4 end
	local style1 = zss:new{constants=t1, basecss='a {a:a()} b {b:b()} c {c:c()}'}
	local style2 = style1:extend():constants(t2):add('j {a:a()} k {b:b()} l {c:c()}')
	assertEqual(style1:match{type='a'}.a, 1)
	assertEqual(style1:match{type='b'}.b, 2)
	assertEqual(style1:match{type='c'}.c, nil)
	assertEqual(style2:match{type='a'}.a, 1)
	assertEqual(style2:match{type='b'}.b, 2)
	assertEqual(style2:match{type='c'}.c, nil, 'extension styles do not use new functions for old rules')
	assertEqual(style2:match{type='j'}.a, 1, 'extension styles must have access to handlers from the base')
	assertEqual(style2:match{type='k'}.b, 3, 'extension styles must use redefined handlers if they conflict')
	assertEqual(style2:match{type='l'}.c, 4, 'extension styles must have access to their own handlers')
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
	assertEqual(style:match{type='a'}.a,1)
	assertNil(style:match{type='a'}.ab)
	assertNil(style:match{type='a'}.aa)
	assertNil(style:match{type='aa'}.a)
	assertNil(style:match{type='a'}.c)
	assertNil(style:match{tags={b=1}}.ab)
	assertEqual(style:match{tags={b=1}}.b,1)
	assertEqual(style:match{type='a', tags={b=1}}.ab,1)
	assertEqual(style:match{type='a', tags={b=1}}.a,1)
	assertEqual(style:match{type='a', tags={b=1}}.b,1)
	assertEqual(style:match{type='a', tags={b=1}, id='c'}.abc,1)
	assertEqual(style:match{type='a', tags={b=1}, id='c'}.c,1)
	assertEqual(style:match{type='a', tags={b=1}, id='c'}.b,1)
	assertEqual(style:match{type='a', tags={b=1}, id='c'}.a,1)
	assertEqual(style:match{id='c'}.c,1)
	assertNil(style:match{id='c'}.abc)
	assertNil(style:match{id='c'}.bc)
	assertNil(style:match{id='c', tags={b=1}}.abc)
	assertEqual(style:match{id='c', tags={b=1}}.bc,1)
	assertEqual(style:match{id='c', tags={b=1}}.b,1)
	assertEqual(style:match{id='c', tags={b=1}}.c,1)
	assertEqual(style:match{tags={e=1,d=1}}.d,1)
	assertEqual(style:match{tags={e=1,d=1}}.e,1)
	assertEqual(style:match{tags={e=1,d=1}}.de,1)
	assertNil(style:match{tags={d=1}}.de)
end

function test.matching_attr()
	local style = zss:new():constants{x=42}:add[[
		*        { c:true }
		*[@x]    { x:@x   }
		t[@x<5]  { op:'<' }
		t[@x>5]  { op:'>' }
		t[@x==5] { op:'=' }
		t[5<@x]  { po:'>' }
		t[5>@x]  { po:'<' }
		t[5==@x] { po:'=' }
	]]

	assertEqual(style:match{type='z'}.c, true)
	assertNil(style:match{type='z'}.x,              'constants must not leak as attributes')
	assertEqual(style:match{type='z', x=17}.x,  17, 'can find attributes')
	assertNil(style:match{type='z', x=17}.op,       'attributes must not ignore other selectors')
	assertEqual(style:match{type='t', x=5}.op, '=', '[@foo==42] works')
	assertEqual(style:match{type='t', x=9}.op, '>', '[@foo>42] works')
	assertEqual(style:match{type='t', x=1}.op, '<', '[@foo<42] works')
	assertEqual(style:match{type='t', x=5}.po, '=', '[42==@foo] works')
	assertEqual(style:match{type='t', x=9}.po, '>', '[42<@foo] works')
	assertEqual(style:match{type='t', x=1}.po, '<', '[42>@foo] works')
end

function test.parsing_functions()
	local style = zss:new():constants{ x=function(t) return t end }:add[[
		a, b[@x] {
			res: x{ a=1, ['b']=2, [3]=3,
              [false]=4 }
		}
	]]
	assertTableEquals(style:match{type='a'}.res, {a=1, b=2, [3]=3, [false]=4})
end

function test.invalid_selectors()
	local style = zss:new():add[[
		t, t2     { x:'OK' }
		t[5!@x]   { x:'no' }
		t[5=@x]   { x:'no' }
		t[@x=5]   { x:'no' }
		t[5>@x]   { x:'no' }
		t[true]   { x:'OK' }
		t[17]     { x:'OK' }
		t['@x<5'] { x:'OK' }
		!t2!      { x:'no' }
		!t2       { x:'no' }
		t2!       { x:'no' }
	]]
	assertEqual(style:match{type='t'}.x,      'OK', 'invalid selectors should be ignored (1)')
	assertEqual(style:match{type='t', x=1}.x, 'OK', 'invalid selectors should be ignored (2)')
	assertEqual(style:match{type='t2'}.x,     'OK', 'invalid selectors should be ignored (3)')
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
	assertEqual(style:match{type='a'}.foo, 1)
	assertEqual(style:match{type='b'}.foo, 2)
	assertEqual(style:match{type='b'}.too, 3)
	assertEqual(style:match{type='b'}.zoo, 4)
	assertTableEquals(style:match{type='c'}.tbl, {a=1, b="two", c=5})
	assertTableEquals(style:match{type='d'}.tb2, {d='{e}'})
	-- assertTableEquals(style:match{type='e'}.tb3, {d='{e'})
	-- assertTableEquals(style:match{type='f'}.tb4, {d='e}'})
end

function test.sketchy_parser()
	local style = zss:new():add [[
		e  { semi:'tl\x3Bdr'; right:'\x7D'; left:':\x7B'; at:'me\x40here.com' }
		q[@v=='\x7B\x40\x3B\x40\x7D'] { worked:true }
		a  { a:'}' }
		b  { b:';'; c:'c' }
	]]
	assertEqual(style:match{type='b'}.c, 'c', 'should be able to parse declaration after ";" seen')

	assertEqual(style:match{type='e'}.semi, 'tl;dr', 'parsing accepts escaped semicolon')
	assertEqual(style:match{type='e'}.right, '}', 'parsing accepts escaped right brace')
	assertEqual(style:match{type='e'}.left, ':{', 'parsing accepts escaped left brace')
	assertEqual(style:match{type='e'}.at, 'me@here.com', 'parsing accepts escaped at symbol')
	assertEqual(style:match{type='q', v='{@;@}'}.worked, true, 'should be able to parse declaration with escaped characters in the selector')

	assertEqual(style:match{type='a'}.a, '}', 'should be able to parse declaration with "}" in string')
	assertEqual(style:match{type='b'}.b, ';', 'should be able to parse declaration with ";" in string')
	assertNil(style:match{type='e'}.c, 'there should be no bleed over from other selectors')
end

function test.per_sheet_constants()
	local s = zss:new()
	local _,id1 = s:add[[
		@vars  { a:1; b:2 }
		sheet1 { a:a; b:b; c:c; d:!d; e:!e }
		@vars  { c:3; d:4 }
	]]
	assertEqual(s:match{type='sheet1'}.a, 1,   '@vars should add variables as constants')
	assertEqual(s:match{type='sheet1'}.b, 2,   '@vars should add variables as constants')
	assertEqual(s:match{type='sheet1'}.c, 3,   'static declaration before @vars still sees the vars on initial read')
	assertEqual(s:match{type='sheet1'}.d, 4,   'dynamic declaration before @vars works')
	assertEqual(s:match{type='sheet1'}.e, nil, 'dynamic declaration cleanly fails for missing @vars')

	local _,id2 = s:add[[
		@vars  { b:20; c:30; q:d and d+1 or 'fresh'; e:50 }
		sheet2 { a:a; b:b; c:c; q:!q; e:!e }
	]]
	assertEqual(s:match{type='sheet1'}.b, 2,   'static declarations using @vars are not affected by loading a later sheet')
	assertEqual(s:match{type='sheet1'}.d, 4,   'dynamic declarations in earlier sheet do NOT access constants in later sheets')
	assertEqual(s:match{type='sheet1'}.e, nil, 'dynamic declarations in earlier sheet do NOT access constants in later sheets')

	assertEqual(s:match{type='sheet2'}.a, 1,   'static declarations can read constants from earlier sheets')
	assertEqual(s:match{type='sheet2'}.b, 20,  'new static declarations can read new constants')
	assertEqual(s:match{type='sheet2'}.c, 30,  'new static declarations can read new constants')
	assertEqual(s:match{type='sheet2'}.q, 5,   '@vars can read values from previously-loaded sheets')
	assertEqual(s:match{type='sheet2'}.e, 50)

	local _,id3 = s:add[[
		sheet3 { a:a; b:b; c:c; d:!d; e:!e; q:q }
	]]
	assertEqual(s:match{type='sheet3'}.a, 1,  'declarations have access to constants from previously-loaded sheets')
	assertEqual(s:match{type='sheet3'}.b, 20, 'declarations have access to constants from previously-loaded sheets')
	assertEqual(s:match{type='sheet3'}.c, 30, 'declarations have access to constants from previously-loaded sheets')
	assertEqual(s:match{type='sheet3'}.d, 4,  'declarations have access to constants from previously-loaded sheets')
	assertEqual(s:match{type='sheet3'}.e, 50, 'declarations have access to constants from previously-loaded sheets')
	assertEqual(s:match{type='sheet3'}.q, 5,  'declarations have access to constants from previously-loaded sheets')

	s:disable(id1)
	assertTableEmpty(s:match{type='sheet1'},       'disabling a sheet removes its rules')
	assertEqual(s:match{type='sheet2'}.a, nil)
	assertEqual(s:match{type='sheet2'}.a, nil,     'disabling a sheet prevents access to the constants from that sheet, and forces reevaluation of static declarations')
	assertEqual(s:match{type='sheet2'}.b, 20,      'constants are still visible')
	assertEqual(s:match{type='sheet2'}.c, 30,      'constants are still visible')
	assertEqual(s:match{type='sheet2'}.q, 'fresh')
	assertEqual(s:match{type='sheet2'}.q, 'fresh', 'constants are re-evaluated when an earlier sheet is disabled')
	assertEqual(s:match{type='sheet2'}.e, 50)

	assertEqual(s:match{type='sheet3'}.a, nil,     'disabling a sheet prevents access to the constants from that sheet, and forces reevaluation of static declarations')
	assertEqual(s:match{type='sheet3'}.b, 20,      'inherited constants are still visible')
	assertEqual(s:match{type='sheet3'}.c, 30,      'inherited constants are still visible')
	assertEqual(s:match{type='sheet3'}.q, 'fresh', 'inherited constants are still visible')
	assertEqual(s:match{type='sheet3'}.e, 50,      'inherited constants are still visible')

	s:enable(id1)

	assertEqual(s:match{type='sheet2'}.a, 1,   'static declarations can read constants from earlier sheets')
	assertEqual(s:match{type='sheet2'}.b, 20,  'new static declarations can read new constants')
	assertEqual(s:match{type='sheet2'}.c, 30,  'new static declarations can read new constants')
	assertEqual(s:match{type='sheet2'}.q, 5,   '@vars can read values from previously-loaded sheets')
	assertEqual(s:match{type='sheet2'}.e, 50)

	s:disable(id2)

	assertEqual(s:match{type='sheet1'}.a, 1,   're-enabling a sheet allows vars to work')
	assertEqual(s:match{type='sheet1'}.b, 2,   're-enabling a sheet allows vars to work')
	assertEqual(s:match{type='sheet1'}.c, 3,   're-enabling a sheet still evaluates correctly')
	assertEqual(s:match{type='sheet1'}.d, 4,   're-enabling a sheet allows dynamic declarations to work')
	assertEqual(s:match{type='sheet1'}.e, nil, 're-enabling a sheet still does not allow access to constants in later sheets')

	assertEqual(s:match{type='sheet3'}.a, 1,   'disabling a sheet prevents access to the constants from that sheet, and forces reevaluation of static declarations')
	assertEqual(s:match{type='sheet3'}.b, 2,   'inherited constants are still visible')
	assertEqual(s:match{type='sheet3'}.c, 3,   'inherited constants are still visible')
	assertEqual(s:match{type='sheet3'}.d, 4,   'inherited constants are still visible')
	assertEqual(s:match{type='sheet3'}.e, nil, 'inherited constants are still visible')

	local css = "@vars {cats:42} house {cats:cats; veryfine:true}"
	local s1 = zss:new():add(css)
	assertTableEquals(s1:match{type='house'}, {cats=42, veryfine=true}, 'Adding CSS through add() can read per-sheet constants')

	local s2 = zss:new{basecss=css}
	assertTableEquals(s2:match{type='house'}, {cats=42, veryfine=true}, 'Adding CSS through basecss can read per-sheet constants')
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
	assertTableEquals(s:match{type='s1'}, expected)
	assertTableEquals(s:match{type='s2'}, expected)
	assertTableEquals(s:match{type='s3'}, expected)
	assertTableEquals(s:match{type='s4'}, expected)
end

test{ quiet=true }