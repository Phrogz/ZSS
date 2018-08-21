package.path=package.path .. ";../?.lua"
ZSS=require 'zss'
local p=require'pprint'

function lerpColors(c1, c2, pct)
  local result={}
  for i=1,3 do result[i] = c1[i]+(c2[i]-c1[i])*pct end
  return result
end

local sheet = ZSS:new()
sheet:values{ white={1,1,1}, red={1,0,0} }
sheet:handlers{ blend=lerpColors }
sheet:add('.step1 { fill:blend(red, white, 0.2) } ')
p( sheet:match{ tags={step1=1} } )

local sheet = ZSS:new()
sheet:values{ white={1,1,1}, red={1,0,0} }
sheet:handlers{ blend=lerpColors }
sheet:add'.step1 { fill:blend(red, white, 0.2) }'
sheet:add'.step2 { fill:blurn(red) }'
p( sheet:match{ tags={step2=1} } )
