local i = require'inspect'
function p(...) for _,o in ipairs{...} do print(i(o)) end end
p(z)

ZSS = require 'zss'

-- parse raw CSS from a string
rules = ZSS:new [[
	@font-face { font-family:'main'; src:'DINPro.otf';  }
	@font-face { font-family:'bold'; src:'DINPro-Bold.otf' }

  /* Make things stand out as ugly, to encourage adding necessary data */

	*    { fill:false; stroke:'magenta';
	       stroke-width:1; font:'main' }

	text { font:'main'; fill:'white'; stroke:false; size:12; opacity:0.5 }

	text.detection { size:8; fill:green }
	.detection { fill:'#ffff0033'; stroke:'yellow'; stroke-width:2 }

	.danger { fill:rgba(2,0,0); size:18; effect:glow(yellow,3) }
	.pedestrian { fill:purple; fill-opacity:0.3 }
	.child      { fill-opacity:0.8 }

	*[ttc<1.5]  { effect:flash(0.2) }
	bbox { fill:false; stroke-opacity:0.2 }
	*[speed] { speed:true }
	#accel { stroke:color('green') }
]]

-- add a second document (can also load from a file)
rules:add [[
	@font-face { font-family:'main'; src:'DINPro-Light.otf';  }
	@font-face { font-family:'bold'; src:'DINPro-Medium.otf'; }
	text { fill:orange }
]]

p( rules:match{ } )
p( rules:match{ id='accl', type='text', tags={danger=1,debug=1}, data={speed=-5} } )

