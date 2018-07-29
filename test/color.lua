local Color = {}
Color.__index = Color

local fmt = string.format
Color.__tostring = function(c)
	return c.name and fmt("<color '%s'>", c.name) or fmt("<color r=%.1f g=%.1f b=%.1f a=%.1f>", table.unpack(c))
end

local function hsv2rgb(hsv)
	local h,s,v = hsv.h%360, hsv.s, hsv.v
	local r,g,b = v,v,v
	local i,f,p,q,t
	if s~=0 then
		h = h / 60
		i = math.floor(h)
		f = h-i
		p = v*(1-s)
		q = v*(1-s*f)
		t = v*(1-s*(1-f))
		if     i==0 then r,g,b = v,t,p
		elseif i==1 then r,g,b = q,v,p
		elseif i==2 then r,g,b = p,v,t
		elseif i==3 then r,g,b = p,q,v
		elseif i==4 then r,g,b = t,p,v
		elseif i==5 then r,g,b = v,p,q
		end
	end
	return { r, g, b, hsv.a or 1 }
end

local clamp255 = function(n) return math.floor(math.min(1,n)*255 + 0.5) end

-- colordata may be:
-- * a hex string: '#fa3', '#ffaa33', '#ffaa3399'
-- * a named string: 'darkorchid', 'limegreen'
-- * a table with HSV/HSVA values: {h=120, s=1.0, v=2.8, a=0.5}
-- * a table with RGB/RGBA values: {r=0.0, g=2.8, b=0.0, a=0.5}
-- * an existing color object to copy (rgba in array, e.g. {0.0, 2.8, 0.0, 0.5})
-- If an alpha value is not supplied, it is assumed to be 1.0 (fully opaque)
-- HSV and RGB values may be HDR; hex values are limited to the range [0.0, 1.0]
function Color:new(colordata)
	local color
	local datatype = type(colordata)
	if 'string'==datatype then
		if Color[datatype] then return Color[datatype] end
			-- Use magenta if a color cannot be found by name
		if '#'~=string.sub(colordata,1,1) then colordata = '#ff00ff' end
		colordata = string.sub(colordata,2)
		if #colordata==3 then colordata=string.gsub(colordata, '(.)(.)(.)', '%1%1%2%2%3%3') end
		if #colordata==6 then colordata=colordata..'ff' end
		color = {
			tonumber(string.sub(colordata, 1, 2), 16)/255,
			tonumber(string.sub(colordata, 3, 4), 16)/255,
			tonumber(string.sub(colordata, 5, 6), 16)/255,
			tonumber(string.sub(colordata, 7, 8), 16)/255
		}
	elseif 'table'==datatype then
		if colordata.h then
			color = hsv2rgb(colordata)
		elseif colordata.r then
			color = { colordata.r, colordata.g, colordata.b, colordata.a or 1 }
		elseif colordata[1] then
			color = { colordata[1], colordata[2], colordata[3], colordata[4] or 1 }
		end
	end
	return setmetatable(color, Color)
end
setmetatable(Color,{__call=Color.new})

function Color:tohsva()
	local r,g,b = table.unpack(self)
	local min,max = math.min(r,g,b), math.max(r,g,b)
	local d = max-min
	local v = max
	local s = max>0 and d/max or 0
	local h = s==0 and 0 or 60*((r==max) and (g-b)/d or ((g==max) and 2+(b-r)/d or 4+(r-g)/d)) % 360
	return { h=h, s=s, v=v, a=self[4] or 1 }
end

function Color:torgba()
	return { r=self[1], g=self[2], b=self[3], a=self[4] or 1 }
end

function Color:tohex()
	return string.format('#%02x%02x%02x', clamp255(self[1]), clamp255(self[2]), clamp255(self[3]))
end

function Color:tohexa()
	return self:tohex() .. string.format('%02x', clamp255(self[4]))
end

function Color:alpha(a)
	self[4] = a
	return self
end

Color.predefined = {
	-- https://en.wikipedia.org/wiki/X11_color_names
	aliceblue            = '#f0f8ff',
	antiquewhite         = '#faebd7',
	aqua                 = '#00ffff',
	aquamarine           = '#7fffd4',
	azure                = '#f0ffff',
	beige                = '#f5f5dc',
	bisque               = '#ffe4c4',
	black                = '#000000',
	blanchedalmond       = '#ffebcd',
	blue                 = '#0000ff',
	blueviolet           = '#8a2be2',
	brown                = '#a52a2a',
	burlywood            = '#deb887',
	cadetblue            = '#5f9ea0',
	chartreuse           = '#7fff00',
	chocolate            = '#d2691e',
	coral                = '#ff7f50',
	cornflowerblue       = '#6495ed',
	cornsilk             = '#fff8dc',
	crimson              = '#dc143c',
	cyan                 = '#00ffff',
	darkblue             = '#00008b',
	darkcyan             = '#008b8b',
	darkgoldenrod        = '#b8860b',
	darkgray             = '#a9a9a9',
	darkgreen            = '#006400',
	darkkhaki            = '#bdb76b',
	darkmagenta          = '#8b008b',
	darkolivegreen       = '#556b2f',
	darkorange           = '#ff8c00',
	darkorchid           = '#9932cc',
	darkred              = '#8b0000',
	darksalmon           = '#e9967a',
	darkseagreen         = '#8fbc8f',
	darkslateblue        = '#483d8b',
	darkslategray        = '#2f4f4f',
	darkturquoise        = '#00ced1',
	darkviolet           = '#9400d3',
	deeppink             = '#ff1493',
	deepskyblue          = '#00bfff',
	dimgray              = '#696969',
	dodgerblue           = '#1e90ff',
	firebrick            = '#b22222',
	floralwhite          = '#fffaf0',
	forestgreen          = '#228b22',
	fuchsia              = '#ff00ff',
	gainsboro            = '#dcdcdc',
	ghostwhite           = '#f8f8ff',
	gold                 = '#ffd700',
	goldenrod            = '#daa520',
	gray                 = '#808080',
	green                = '#008000',
	greenyellow          = '#adff2f',
	honeydew             = '#f0fff0',
	hotpink              = '#ff69b4',
	indianred            = '#cd5c5c',
	indigo               = '#4b0082',
	ivory                = '#fffff0',
	khaki                = '#f0e68c',
	lavender             = '#e6e6fa',
	lavenderblush        = '#fff0f5',
	lawngreen            = '#7cfc00',
	lemonchiffon         = '#fffacd',
	lightblue            = '#add8e6',
	lightcoral           = '#f08080',
	lightcyan            = '#e0ffff',
	lightgoldenrodyellow = '#fafad2',
	lightgray            = '#d3d3d3',
	lightgreen           = '#90ee90',
	lightpink            = '#ffb6c1',
	lightsalmon          = '#ffa07a',
	lightseagreen        = '#20b2aa',
	lightskyblue         = '#87cefa',
	lightslategray       = '#778899',
	lightsteelblue       = '#b0c4de',
	lightyellow          = '#ffffe0',
	lime                 = '#00ff00',
	limegreen            = '#32cd32',
	linen                = '#faf0e6',
	magenta              = '#ff00ff',
	maroon               = '#800000',
	mediumaquamarine     = '#66cdaa',
	mediumblue           = '#0000cd',
	mediumorchid         = '#ba55d3',
	mediumpurple         = '#9370db',
	mediumseagreen       = '#3cb371',
	mediumslateblue      = '#7b68ee',
	mediumspringgreen    = '#00fa9a',
	mediumturquoise      = '#48d1cc',
	mediumvioletred      = '#c71585',
	midnightblue         = '#191970',
	mintcream            = '#f5fffa',
	mistyrose            = '#ffe4e1',
	moccasin             = '#ffe4b5',
	navajowhite          = '#ffdead',
	navy                 = '#000080',
	oldlace              = '#fdf5e6',
	olive                = '#808000',
	olivedrab            = '#6b8e23',
	orange               = '#ffa500',
	orangered            = '#ff4500',
	orchid               = '#da70d6',
	palegoldenrod        = '#eee8aa',
	palegreen            = '#98fb98',
	paleturquoise        = '#afeeee',
	palevioletred        = '#db7093',
	papayawhip           = '#ffefd5',
	peachpuff            = '#ffdab9',
	peru                 = '#cd853f',
	pink                 = '#ffc0cb',
	plum                 = '#dda0dd',
	powderblue           = '#b0e0e6',
	purple               = '#800080',
	red                  = '#ff0000',
	rosybrown            = '#bc8f8f',
	royalblue            = '#4169e1',
	saddlebrown          = '#8b4513',
	salmon               = '#fa8072',
	sandybrown           = '#f4a460',
	seagreen             = '#2e8b57',
	seashell             = '#fff5ee',
	sienna               = '#a0522d',
	silver               = '#c0c0c0',
	skyblue              = '#87ceeb',
	slateblue            = '#6a5acd',
	slategray            = '#708090',
	snow                 = '#fffafa',
	springgreen          = '#00ff7f',
	steelblue            = '#4682b4',
	tan                  = '#d2b48c',
	teal                 = '#008080',
	thistle              = '#d8bfd8',
	tomato               = '#ff6347',
	turquoise            = '#40e0d0',
	violet               = '#ee82ee',
	wheat                = '#f5deb3',
	white                = '#ffffff',
	whitesmoke           = '#f5f5f5',
	yellow               = '#ffff00',
	yellowgreen          = '#9acd32',

	-- NVIDIA color names
	nv                   = '#76B900',
	nvgreen              = '#76B900',
	emerald              = '#008564',
	amethyst             = '#5d1682',
	lapis                = '#0c34bd',
	rhodomine            = '#bb29bb',
	pyrite               = '#fbe122',
	ruby                 = '#ba0c2f',
	jade                 = '#0c9e82',
	iolite               = '#8737aa',
	sapphire             = '#00a5db',
	garnet               = '#a2175f',
	fluorite             = '#fac200',
	citrine              = '#fc8817',
	transparent          = '#00000000',
}
for name,hex in pairs(Color.predefined) do
	Color.predefined[name] = Color(hex)
	Color.predefined[name].name = name
end

return Color