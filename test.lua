local i = require'inspect'
function p(o) print(i(o)) end
p(z)

ZSS = require'zss'
z = ZSS:new()
z:load('test2.css')
p( 'jorb', z:match'jorb' )
p( 'foo', z:match'jorb' )
