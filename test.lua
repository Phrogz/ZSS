local i = require'inspect'
function p(...) for _,o in ipairs{...} do print(i(o)) end end
p(z)

ZSS = require'zss'
z = ZSS:new([[
* { rank:none; star:true; }
a { rank:low1; a1:true; }
a { rank:low2; a2:42; }
.bar { rank:med1; bar:true; }
.a.b { rank:42; dota:true; dotb:true; }
]])

p( z:match'.a.b' )

-- s = ZSS.parse_selector('.a.b')
-- e = ZSS.parse_selector('.a')

-- p( ZSS.matches(s,e) )
