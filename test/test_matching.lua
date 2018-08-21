package.path = '../?.lua;' .. package.path
zss = require'../zss'

_ENV = require('lunity')('ZSS Selector Matching Tests')

function test.matching()
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

test()
