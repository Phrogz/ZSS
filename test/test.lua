local i=function(x) print(require('inspect')(x)) end
package.path = '../?.lua;' .. package.path
zss = require'zss'
ZSS = zss
color = require'color'
local lerp = require'lerp'

local style = ZSS:new()
style:constants{lerp=lerp}:directives{ vars = function(me, props) me:constants(props) end }
style:add[[
  @vars   { uiscale:1.5; fg:'white'; dlerp:lerp.linear{in1=0, in2=10, out1=100, out2=200}; yes:'very' }
  text    { font-size:12*uiscale; fill:fg }
  foo[@x] { bar:dlerp(@x); yes:yes }
]]
i(style:match 'foo[x=3]')
