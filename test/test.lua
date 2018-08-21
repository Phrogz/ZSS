package.path = '../?.lua;' .. package.path
zss = require'zss'

local style1, id1 = zss:new():add('a {a:1} b {b:1}')
local style2, id2 = style1:extend():add('a {fill:none}')

