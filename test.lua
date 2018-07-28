local i = require'inspect'
function p(...) for _,o in ipairs{...} do print(i(o)) end end
p(z)

ZSS = require'zss'
z = ZSS:new()
z:load('test2.css')
-- p( z:match'jorb' )
-- p( z:match'foo' )

s = ZSS.parse_selector 'a.c[y>1.3]'
e = ZSS.parse_selector 'a#foo.b.a.c[y = 2][x=1.4]'

p(s)
p(e)
p( ZSS.matches(s,e) )