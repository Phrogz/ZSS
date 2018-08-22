local i=function(x) print(require('inspect')(x)) end
package.path = '../?.lua;' .. package.path
zss = require'zss'
ZSS = zss
color = require'color'

local style = ZSS:new()
style:directives{ vars = function(me, props) me:constants(props) end }
style:add[[
  @vars { uiscale:1.5; fg:'white' }
  text { font-size:12*uiscale; fill:fg }
]]
i(style:match 'text')
