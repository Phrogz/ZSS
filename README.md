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

## Descriptor Tables versus Strings

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


# API

* [`ZSS:new()`](#zssnewopts) — create a sheet
* [`myZSS:values()`](#myzssvaluesvalue_map) — set value replacements
* [`myZSS:handlers()`](#myzsshandlershandler_map) — set function handlers
* [`myZSS:add()`](#myzssaddcss) — parse CSS from string
* [`myZSS:load()`](#myzssload) — load CSS from file
* [`myZSS:match()`](#myzssmatchelement_descriptor) — compute the declarations that apply to an element


## ZSS:new(opts)

`opts` is a table with any of the following string keys (all optional):

* `values` — a table mapping string literals (that might appear as values in declarations) to the Lua value you would like them to have instead.
* `handlers` — a table mapping string function names (that might appear as values in declarations) to a function that will process the argument(s) and return a Lua value to use.
* `basecss` — a string of CSS rules to initially parse for the stylesheet.
* `files` — an array of string file names to load and parse after the `basecss`.

### Example:

```lua
ZSS = require'zss'
local sheet = ZSS:new{
  values   = {none=false, ['true']=true, ['false']=false, transparent=processColor(0,0,0,0) },
  handlers = {color=processColor, url=processURL },
  basecss  = [[...css code...]],
  files    = {'a.css', 'b.css'},
}
```

Values can be set (replaced) later using the `values()` method.  
Handlers can be updated (added to) later using the `handlers()` method.  
You can parse additional raw CSS at any time using the `add()` method.  
You can load CSS files by name at any time using the `load()` method.


## myZSS:values(value_map)

Set (replace) the literal value mapping used when parsing declaration values.

`value_map` is a table mapping string literals (that might appear as values in declarations) to the Lua value you would like them to have instead.

The return value is the invoking ZSS stylesheet instance (for method chaining).

**Note**: values are resolved when a stylesheet is first loaded and parsed. Invoking this method after CSS has been loaded for a stylesheet will only affect future parsing of element descriptors.

### Example:

```lua
local sheet = ZSS:new()
sheet:values{ none=false, white={1,1,1}, red={1,0,0} }
sheet:add('* {a:none; b:white; c:red; d:orange } ')
sheet:match 'x'
--> { a=false, b={1,1,1}, c={1,0,0}, d='orange' }
```


## myZSS:handlers(handler_map)

Add additional function mappings to the stylesheet. When a function matching a name in the map is encountered, it will be passed the values specified in the declaration, and the return value of the function used as the value of the rule.

`handler_map` is a table mapping string function names (that might appear as values in declarations) to the Lua function to invoke.

The return value is the invoking ZSS stylesheet instance (for method chaining).

**Note**: values are resolved when a stylesheet is first loaded and parsed. Invoking this method after CSS has been loaded for a stylesheet will only affect any additional CSS that is loaded.

### Example:

```lua
function lerpColors(c1, c2, pct)
  local result={}
  for i=1,3 do result[i] = c1[i]+(c2[i]-c1[i])*pct end
  return result
end

local sheet = ZSS:new()
sheet:values{ white={1,1,1}, red={1,0,0} }
sheet:handlers{ blend=lerpColors }
sheet:add('.step1 { fill:blend(red, white, 0.2) } ')
sheet:match{ tags={step1=1} }
--> { fill={ 1.0, 0.2, 0.2 } }
```

As seen above, values of parameters are resolved (using `values` and `handlers`) prior to passing them to the function.


## myZSS:add(css)

Add CSS rules to the sheet (specified as a string of CSS).

**Notes**:

* You should invoke this method only after setting up any `values` and `handlers` mappings for the sheet.
* Invoking this method resets the computed rules cache (as new rules may invalidate cached computations).

### Example:

```lua
local sheet = ZSS:new()
sheet:add[[
  /* CSS comments are recognized and ignored */
  @some-rule { note:'at rules are supported' }
  #special   { x:1; y:2.0; z:'three'; q:sum(1,2,1) }
]]
```


## myZSS:load(...)

Add CSS rules to the stylesheet, loaded from one or more files specified by file name.

### Example:

```lua
local sheet = ZSS:new()
sheet:load( 'a.css', 'b.css', 'c.css' )
```


## myZSS:match(element_descriptor)

Use all rules in the stylesheet to compute the declarations that apply to described element.

`element_descriptor` may be a selector-like string describing the element—e.g. `type.tag1.tag2`, `#someid[var1=42][var2=3.8]`—or a table using any/all/none of the keys: `{ type='mytype', id='myid', tags={tag1=1, tag2=1}, data={var1=42, var2=3.8}}`.

See the section _[Descriptor Tables versus Strings](#descriptor-tables-versus-strings)_ above for a discussion on the implications of using strings versus tables.

_Tip_: while tag, id, and attribute order doesn't matter for computing the declarations that apply, each unique string will recompute the applicable declarations instead of using the cache. For example, the following five strings all produce the same results, but require the table to be recomputed five times instead of cached:

```lua
local d1 = sheet:match'foo#bar.jim.jam[a=7]'
local d2 = sheet:match'foo#bar.jam.jim[a=7]'
local d3 = sheet:match'foo.jim#bar.jam[a=7]'
local d4 = sheet:match'foo[a=7]#bar.jim.jam'
local d5 = sheet:match'foo[a=7].jim.jam#bar'
```

Consequently, it is advisable to establish a convention when crafting your strings. The author of ZSS recommends `type#id.t1.t2[a1=1][a2=2]`, where tags and attributes are ordered alphabetically.

### Example:

```lua
local sheet = ZSS:new():add[[
  * { fill:none; stroke:white; opacity:1.0 }
  text { fill:white; stroke:none }
  .important { weight:bold; fill:red }
  .debug     { opacity:0.5 }
]]
local m1 = sheet:match('text.important')
--> { fill='red', opacity=1.0, stroke='none', weight='bold' }

local m2 = sheet:match{ type='line', tags={debug=1} }
--> { fill='none', opacity=1.0, stroke='white' }
```


# License & Contact

ZSS is copyright ©2018 by Gavin Kistner and is licensed under the [MIT License](MIT License). See the LICENSE.txt file for more details.

For bugs or feature requests please [open issues on GitHub](https://github.com/Phrogz/ZSS/issues). For other communication you can [email the author directly](mailto:!@phrogz.net?subject=ZSS).