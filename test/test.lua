package.path = '../?.lua;' .. package.path
zss = require'zss'

local style1, id1 = zss:new():add('a {a:1} b {b:c(@no*@bar)}')
style1:match('b')


