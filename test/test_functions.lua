package.path = '../?.lua;' .. package.path
zss = require'../zss'

_ENV = require('lunity')('ZSS Generator Function Tests')

function test.placeholder_functions()
	local style = zss:new()
	local ct1, ct2 = 0,0
	style:valueFunctions{
		ct1  = function() ct1=ct1+1 return ct1 end,
		ct2  = function() ct2=ct2+1 return ct2 end,
		add  = function(a,b) return (tonumber(a) or 0)+(tonumber(b) or 0) end,
		echo = function(n) return n end
	}
	style:add [[
		x   { p:add(1,2) }
		y   { p:add(@r,17) }
		z   { p:add(25,@s) }
		e   { p:echo(@foo) }
		ct1 { p:ct1()   }
		ct2 { p:ct2(@x) }
	]]
	assertEqual(style:match('x').p, 3,  'simple functions work')
	assertEqual(style:match('y').p, 17, 'placeholder functions "work" even without data passed')
	assertEqual(style:match('z').p, 25, 'placeholder functions "work" even without data passed')
	assertEqual(style:match('e').p, '@foo', 'placeholder functions receive their parameter name if no data')
	assertEqual(style:match('e',{}).p, '@foo', 'placeholder functions receive their parameter name if not in data')
	assertEqual(style:match('e',{foo=42}).p, 42, 'placeholder functions receive data by name')
	assertEqual(style:match('y',{r=25}).p,   42)
	assertEqual(style:match('z',{s=17}).p,   42)
	assertEqual(style:match('y',{r=4}).p,    21)

	assertEqual(ct1, 1, 'parsing the rules should invoke non-placeholder functions')
	assertEqual(style:match('ct1').p, 1)
	assertEqual(style:match('ct1').p, 1, 'non-placholder functions do not get re-invoked')

	assertEqual(ct2, 0, 'placholder functions do not get invoked during parsing')
	assertEqual(style:match('ct2').p,       1, 'placholder functions get invoked each time, regardless of data')
	assertEqual(style:match('ct2',{x=1}).p, 2, 'placholder functions get invoked each time, regardless of data')
	assertEqual(style:match('ct2').p,       3, 'placholder functions get invoked each time, regardless of data')
	assertEqual(style:match('ct2',{x=2}).p, 4, 'placholder functions get invoked each time, regardless of data')
end

function test.extensions_and_functions()
	local f1,f2 = {},{}
	function f1.a() return 1 end
	function f1.b() return 2 end
	function f2.b() return 3 end
	function f2.c() return 4 end
	local style1 = zss:new{functions=f1, basecss='a {a:a()} b {b:b()} c {c:c()}'}
	local style2 = style1:extend():valueFunctions(f2):add('j {a:a()} k {b:b()} l {c:c()}')
	assertEqual(style1:match('a').a, 1)
	assertEqual(style1:match('b').b, 2)
	assertTableEquals(style1:match('c').c, {func='c', params={}})
	assertEqual(style2:match('a').a, 1)
	assertEqual(style2:match('b').b, 2)
	assertTableEquals(style2:match('c').c, {func='c', params={}}, 'extension styles do not use new functions for old rules')
	assertEqual(style2:match('j').a, 1, 'extension styles must have access to handlers from the base')
	assertEqual(style2:match('k').b, 3, 'extension styles must use redefined handlers if they conflict')
	assertEqual(style2:match('l').c, 4, 'extension styles must have access to their own handlers')
end

test()
