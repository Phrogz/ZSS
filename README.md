# About ZSS

ZSS is a small, simple, pure Lua library that parses simple CSS (see below for limitations) rules and then computes the declarations to apply for a given 'element'.

It is generic:

* There is no assumption about the set of element types (names), ids, classes, or attributes allowed.
* There is no enforcement about the set of legal declaration names or values.
* It supports user-specified mappings to convert value keywords to Lua values.  
  For example, you can make `{ fill:none }` in CSS turn into `{fill=false}` in Lua.
* It supports user-specified mappings to convert function calls to Lua values.  
  For example, you can make `{ fill:hsv(137°, 0.5, 2.7) }` in CSS turn into `fill = {r=0, g=2.7, b=0.765}` in Lua.

It has a few simplifications/limitations:

* It assumes a **flat, unordered data model**. This means that there are no hierarchical selectors (no descendants, no children), no sibling selectors, and no pseudo-elements related to position.
* Other than mapping keywords to values, it only supports numbers, strings, and function calls as data types. There is currently no support for custom units on numbers.
* It only supports a few data attribute queries (currently attribute presence, =, <, and >).
* It does not (currently) provide access to the element/attributes when resolving functions. (This allows all functions known to be run once at parse time, with the resulting value cached.)
* Due to a simple parser, you must not have a `{` character inside a selector, or a `}` character inside a rule.



# Example Usage

```lua
ZSS = require'zss'

color = require'color'
local function hsv(h,s,v)
	return color{ h=h, s=s, v=v }
end
local function rgb(r,g,b)
	return color{ r=r, g=g, b=b }
end

local values = { none=false, transparent=false, visible=true }
setmetatable(values,{__index=color.predefined})

local sheet = ZSS:new{
	values   = values,
	handlers = { rgb=rgb, hsv=hsv },
	basecss  = [[
		@font-face { font-family:main; src:'Arial.ttf' }
		@font-face { font-family:bold; src:'Arial-Bold.ttf' }
		* { fill:none; stroke:white; size:20 }
		text { font:main; fill:white; stroke:none }
	]]
 }

sheet:load('my.css')
--> my.css has the contents
-->
--> @font-face { font-family:main; src:'DINPro-Light.ttf' }
--> @font-face { font-family:bold; src:'DINPro-Medium.ttf' }
--> #title { font:bold }
--> .important { fill:hsv(60,1,1) }
--> .debug, .boring { fill:white; opacity:0.2 }
--> text.debug, text.boring { opacity:0.5 }
--> *.danger { fill:rgb(2,0,0); opacity:1 }
--> text.negative { color:red }
--> *[speed>20] { effect:flash(0.5, 3) }

sheet:match{ type=line }
--> { fill=false, size=20, stroke=<color 'white'> }

sheet:match'line'
--> { fill=false, size=20, stroke=<color 'white'> }

sheet:match'text'
--> { fill=<color 'white'>, font='main', size=20, stroke=false }

sheet:match'text.important'
--> { fill=<color r=1.0 g=1.0 b=0.0 a=1.0>, font='main', size=20, stroke=false }

sheet:match'#title.danger.important'
--> { fill=<color r=2.0 g=0.0 b=0.0 a=1.0>, font='bold', opacity=1, size=20,
-->   stroke=<color 'white'> }

sheet:match{ type=text, tags={debug=1}, data={speed=37} }
--> { effect={ func='flash', params={ 0.5, 3 }  },
-->   fill=<color 'white'>, opacity=0.2, size=20, stroke=<color 'white'> }
```



# Descriptor Tables versus Strings

As seen in the example above, you can describe an 'element' to find declarations for using either a table or a string. The two are equivalent in terms of _functionality_:

```lua
sheet:match{ type='line', id='forecast', tags={tag1=1,tag2=1}, data={ clouds=85 } }
sheet:match'line#forecast.tag1.tag2[clouds=85]'
```

They differ in terms of performance and memory implications, however:

* The table form is roughly 3–4× faster than the string form the _first_ time it is used. It causes a new table of computed declarations to be computed each time; this table is not retained by the library.
* The string form is roughly 40× faster than the table form when the _exact_ same string has previously been seen. The string form causes the computed declarations table to be cached _forever_ in the library.

If you have elements with roughly the same tags or data value that you use repeatedly throughout the lifespan of your application, pass a string to `match()`.

If you have elements whose tags or (notably) attribute values are constantly changing, and unlikely to be seen again, pass a table to `match()`.



# License & Contact

ZSS is copyright ©2018 by Gavin Kistner and is licensed under the [MIT License](MIT License). See the LICENSE.txt file for more details.

For bugs or feature requests please [open issues on GitHub](https://github.com/Phrogz/ZSS/issues). For other communication you can [email the author directly](mailto:!@phrogz.net?subject=ZSS).