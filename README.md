# About ZSS

ZSS is a small, simple, pure Lua library that parses simple CSS (see below for limitations) rules and then computes the declarations to apply for a given 'element'.

## Features:

* There is no assumption about the set of element types (names), ids, classes, or attributes allowed.
* There is no enforcement about the set of legal declaration names or values.
* It supports handlers to process "at-rules" as they are seen.
* It uses arbitrary Lua expressions for property values, with a sandbox table for resolving values and functions.
  * _For example, you can make_ `{ fill:none }` _in CSS turn into_ `{fill=false}` _in Lua._
  * _For example, you can make_ `{ fill:hsv(137°, 0.5, 2.7) }` _in CSS turn into_ `fill = {r=0, g=2.7, b=0.765}` _in Lua._
* Value expressions can use placeholder values that are deferred and resolved against data supplied with a query. For example:
    ```lua
    local C = require'color'

    local style=zss:new():constants{
      white = C.white,
      hsv   = function(h,s,v) return C:new{h=h,s=s,v=v} end
    }:add[[
      circle          { fill:white; r:3      }
      circle[@r]      { radius:@r            }
      circle[@hue]    { fill:hsv(@hue, 1, 1) }
    ]]

    local props = style:match('circle')
    for k,v in pairs(props) do print(k,v) end
    --> fill <color 'white'>
    --> radius 3

    local rnd=math.random
    for r=1,4 do
      local attrs = { r=r, hue=rnd(360) }
      local props = style:match{type='circle', data=attrs}
      for k,v in pairs(props) do print(k,v) end
    end
    --> fill <color r=1.0 g=0.0 b=1.0 a=1.0>
    --> radius 1
    --> fill <color r=0.0 g=1.0 b=0.4 a=1.0>
    --> radius 2
    --> fill <color r=0.7 g=0.0 b=1.0 a=1.0>
    --> radius 3
    --> fill <color r=0.8 g=0.0 b=1.0 a=1.0>
    --> radius 4
    ```


## Simplifications/Limitations:

* It assumes a **flat, unordered data model**. This means that there are no hierarchical selectors (no descendants, no children), no sibling selectors, and no pseudo-elements related to position.
* Using Lua to parse property expressions means there is no support for custom units on numbers using CSS syntax, or hexadecimal colors. You would need to wrap these in function calls like `len(5,cm)` or `color('#ff0033')`.
* It only supports simple data attribute queries in selectors: attribute presence (`[@foo]`), and simple value comparisons (`[@foo<7.3]`, `[@foo=12]`, `[@foo>0.9]`).
* Due to a simple parser, you must not have a `{` character inside a selector. (Then again, when would you?)


## Example Usage

```lua
ZSS   = require'zss'
color = require'color'

local style = ZSS:new{
  constants = {
    none        = false,
    transparent = false,
    visible     = true,
    rgb=function(r,g,b) return color{ r=r, g=g, b=b } end,
    hsv=function(h,s,v) return color{ h=h, s=s, v=v } end
  }
}

-- load additional constants into the data model for resolution
-- before parsing any CSS that might use them
style:constants(color.predefined)

style:add [[
  @font-face { font-family:'main'; src:'Arial.ttf' }
  @font-face { font-family:'bold'; src:'Arial-Bold.ttf' }
  *    { fill:none; stroke:white; size:20 }
  text { font:'main'; fill:white; stroke:none }
]]

style:load('my.css')
--> my.css has the contents
-->
--> @font-face      { font-family:'main'; src:'DINPro-Light.ttf' }
--> @font-face      { font-family:'bold'; src:'DINPro-Medium.ttf' }
--> #title          { font:'bold' }
--> .important      { fill:hsv(60,1,1) }
--> .debug, .boring { fill:white; opacity:0.2 }
--> text.debug,
--> text.boring     { opacity:0.5 }
--> text[@speed>20] { fill:red; opacity:1 }

style:match{ type='line' }
--> {fill=false, size=20, stroke=<color 'white'>}

style:match'line'
--> {fill=false, size=20, stroke=<color 'white'>}

style:match'text'
--> {fill=<color 'white'>, font="main", size=20, stroke=false}

style:match'text.important'
--> {fill={1, 1, 0}, font="main", size=20, stroke=false}

style:match'#title.important'
--> {fill={1, 1, 0}, font="bold", size=20, stroke=<color 'white'>}

style:match{ type='text', tags={debug=1}, data={speed=37} }
--> {fill=<color 'red'>, font="main", opacity=1, size=20, stroke=false}
```

# Descriptor Tables versus Strings

As seen in the example above, you can describe an 'element' to find declarations for using either a table or a string. The two are equivalent in terms of _functionality_:

```lua
style:match{ type='line', id='forecast', tags={tag1=1,tag2=1}, data={ clouds=85 } }
style:match'line#forecast.tag1.tag2[clouds=85]'
```

They differ in terms of performance and memory implications, however:

* The table form is roughly 3–4× faster than the string form the _first_ time it is used. It causes a new table of computed declarations to be computed each time; this table is not retained by the library.
* The string form is roughly 40× faster than the table form when the _exact_ same string has previously been seen. The string form causes the computed declarations table to be cached _forever_ in the library.

If you have elements with roughly the same tags or data value that you use repeatedly throughout the lifespan of your application, pass a string to `match()`.

If you have elements whose tags or (notably) attribute values are constantly changing, and unlikely to be seen again, pass a table to `match()`.


# API

* [`ZSS:new()`](#zssnewopts) — create a style (aggregating many sheets and rules)
* [`myZSS:constants()`](#myzssconstantsvalue_map) — set value lookups
* [`myZSS:directives()`](#myzssdirectiveshandlers) — set at-rule handlers
* [`myZSS:add()`](#myzssaddcss) — parse CSS from string
* [`myZSS:load()`](#myzssload) — load CSS from file
* [`myZSS:match()`](#myzssmatchelement_descriptor) — compute the declarations that apply to an element
* [`myZSS:extend()`](#myzssextend) — create a new sheet that derives from this one
* [`myZSS:disable()`](#myzssdisablesheetid) — stop using rules from a particular set of CSS
* [`myZSS:enable()`](#myzssenablesheetid) — resume using rules from a particular set of CSS


## ZSS:new(opts)

`opts` is a table with any of the following string keys (all optional):

* `constants` — a table mapping string literals (that might appear as values or functions in declarations) to the Lua value you would like them to have instead.
* `basecss` — a string of CSS rules to initially parse for the stylesheet.
* `directives` — a table mapping the string name of an "at-rule" (without the `@`) to a function that should be invoked each time it is seen.
* `files` — an array of string file names to load and parse after the `basecss`.

### Example:

```lua
URL  = require'urlhandler'
FONT = require'myfonts'
ZSS  = require'zss'
local style = ZSS:new{
  constants  = {
    none      = false,
    ['true']  = true,
    ['false'] = false,
    color     = require('color'),
    url       = URL.processURL,
  },
  directives = {
    -- e.g. @font-face { font-family='bold'; src:'fonts/Arial-bold.ttf' }
    ['font-face'] = function(style, props)
      FONT.createFont(props['font-family'], props.src)
    end
  },
  basecss  = [[...css code...]],
  files    = {'a.css', 'b.css'},
}
```

Constants can be added to later using the `constants()` method.  
You can parse additional raw CSS later using the `add()` method.  
You can load CSS files by name later using the `load()` method.  
You can add additional directives later using the `handleDirectives()` method.


## myZSS:constants(value_map)

Add to the literal value mappings used when parsing declaration values.

`value_map` is a table mapping string literals (that might appear as values or functions in declarations) to the Lua value you would like them to have instead.

The return value is the invoking ZSS stylesheet instance (for method chaining).

**Note**: constants are resolved when rules are added/loaded, unless there is a deferred reference in the value (e.g. `@foo`). Invoking this method after CSS has been loaded will only affect rules added/loaded after this calls, or the evaluation of deferred values.

### Example:

```lua
local style = ZSS:new()
style:constants{ none=false, white={1,1,1}, red={1,0,0} }
style:add('* {a:none; b:white; c:red; d:orange } ')
style:match 'x'
--> {a=false, b={1,1,1}, c={1,0,0}, d=nil}
```

## myZSS:directives(handlers)

Add to the handler functions used when an at-rule is experienced during parsing.

`handlers` is a table mapping the name of the at-rule (without the leading `@`) to a Lua function to invoke. The function will be passed a reference to the ZSS style instance, and a table mapping property names to values seen in the declaration.

The return value is the invoking ZSS stylesheet instance (for method chaining).

### Example:

```lua
local style = ZSS:new()
style:directives{
  vars = function(me, props) me:constants(props) end
}
style:add[[
  @vars { uiscale:1.5; fg:'white' }
  text { font-size:12*uiscale; fill:fg }
]]
style:match 'text'
--> { fill="white", ["font-size"]=18.0 }
```


## myZSS:add(css)

Add CSS rules to the style (specified as a string of CSS).

**Notes**:

* You should invoke this method only after setting up any `values` and `handlers` mappings for the sheet.
* Invoking this method resets the computed rules cache (as new rules may invalidate cached computations).

### Example:

```lua
local style = ZSS:new()
style:add[[
  /* CSS comments are recognized and ignored */
  @some-rule { note:'at rules are supported' }
  #special   { x:1; y:2.0; z:'three'; q:sum(1,2,1) }
]]
```


## myZSS:load(...)

Add CSS rules to the stylesheet, loaded from one or more files specified by file name.

### Example:

```lua
local style = ZSS:new()
style:load('a.css', 'b.css', 'c.css')
```


## myZSS:match(element_descriptor)

Use all rules in the stylesheet to compute the declarations that apply to described element.

`element_descriptor` may be a selector-like string describing the element—e.g. `type.tag1.tag2`, `#someid[var1=42][var2=3.8]`—or a table using any/all/none of the keys: `{ type='mytype', id='myid', tags={tag1=1, tag2=1}, data={var1=42, var2=3.8}}`.

See the section _[Descriptor Tables versus Strings](#descriptor-tables-versus-strings)_ above for a discussion on the implications of using strings versus tables.

_Tip_: while tag, id, and data order doesn't matter for computing the declarations that apply, each unique string will recompute the applicable declarations instead of using the cache. For example, the following five strings all produce the same results, but require the table to be recomputed five times instead of cached:

```lua
local d1 = style:match'foo#bar.jim.jam[a=7]'
local d2 = style:match'foo#bar.jam.jim[a=7]'
local d3 = style:match'foo.jim#bar.jam[a=7]'
local d4 = style:match'foo[a=7]#bar.jim.jam'
local d5 = style:match'foo[a=7].jim.jam#bar'
```

Consequently, it is advisable to establish a convention when crafting your strings. The author of ZSS recommends type/id/tags/data, where tags and data are ordered alphabetically. For example: `type#id.t1.t2[a1=1][a2=2]`.

### Example:

```lua
local style = ZSS:new():add[[
  * { fill:none; stroke:white; opacity:1.0 }
  text { fill:white; stroke:none }
  .important { weight:bold; fill:red }
  .debug     { opacity:0.5 }
]]
local m1 = style:match('text.important')
--> { fill='red', opacity=1.0, stroke='none', weight='bold' }

local m2 = style:match{ type='line', tags={debug=1} }
--> { fill='none', opacity=1.0, stroke='white' }
```


## myZSS:extend(...)

Creates a new ZSS style that derives from this style, while retaining a live link to its state. Rules in the new style supercede rules in the 'parent' style (for the same rank). If you pass any filenames, they will be passed to `load()`. (In other words, `local b = a:extend('a.css', 'b.css')` is a shorthand for `local b = a:extend():load('a.css', 'b.css')`.)

### Example:

```lua
local main   = ZSS:new{ files={'base.css', 'day.css'} }
local style1 = main:extend():load('style1.css') -- style1:match() uses base.css, day.css, and style1.css
local style2 = main:extend('style2.css')        -- style2:match() uses base.css, day.css, and style2.css
main:disable('day.css')
main:load('night.css')
--> now style1:match() uses base.css, **night.css**, and style1.css
```

## myZSS:disable(sheetid)

Prevent a specific set of CSS from being used in the sheet (and all descendants created via `clone()`). For files, the `sheetid` is the path passed to `load()`; for CSS strings added via the `add()` method, the `sheetid` is the second string returned from `add()`.

### Example:

```lua
local main   = ZSS:new{ files={'base.css', 'day.css'} }
local style1 = main:clone():load('style1a.css')
local _, bID = style1:add('#additional { rules:here }')

style1:match() --> uses base.css, day.css, style1a.css, and additional rules loaded during add()

style1:disable(bID)
style1:match() --> uses base.css, day.css, style1a.css

main:disable('day.css')
style1:match() --> uses base.css and style1a.css
main:match() --> uses base.css only

main:enable('day.css')
style1:match() --> uses base.css, day.css, and style1a.css
main:match() --> uses base.css and day.css

style1:disable('day.css')
style1:match() --> uses base.css and doc1a.css
main:match() --> uses base.css and day.css
```

**Note**: As shown in that last lines of the example above, a cloned sheet may disable rules loaded in its parent, but that does not disable them for the parent (or other clones of the parent).

## myZSS:enable(sheetid)

Re-enable CSS previously disabled with `disable()`. (See `disable()` for an example.)



# License & Contact

ZSS is copyright ©2018 by Gavin Kistner and is licensed under the [MIT License](https://opensource.org/licenses/MIT). See the LICENSE.txt file for more details.

For bugs or feature requests please [open issues on GitHub](https://github.com/Phrogz/ZSS/issues). For other communication you can [email the author directly](mailto:!@phrogz.net?subject=ZSS).
