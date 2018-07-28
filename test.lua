local i = require'inspect'
function p(...) for _,o in ipairs{...} do print(i(o)) end end
p(z)

ZSS = require'zss'
z = ZSS:new [[
	.bar , .jim { rank:med1; bar:true; }
	a { rank:low1; a1:true; }
	.a.b { rank:42; dota:true; dotb:true; }
	a { rank:low2; a2:42; }
	* { rank:none; star:true; }
]]
z:load('test.css')

p( z:match'a' )
p( z.directives )

-- s = ZSS.parse_selector('.a.b')
-- e = ZSS.parse_selector('.a')

-- p( ZSS.matches(s,e) )
