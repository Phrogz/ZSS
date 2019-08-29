# About ZSS

ZSS is a small, simple, pure Lua library that parses simple CSS (see below for limitations) rules and then computes the declarations to apply for a given 'element'.

## Features:

* There is no assumption about the set of element types (names), ids, classes, or attributes allowed.
* There is no enforcement about the set of legal declaration names or values.
* It supports handlers to process "at-rules" as they are seen.
* It uses arbitrary Lua expressions for property values, with a sandbox table for resolving values and functions.
  * _For example, you can make_ `{ fill:none }` _in CSS turn into_ `{fill=false}` _in Lua._
  * _For example, you can make_ `{ fill:hsv(137, 0.5, 2.7) }` _in CSS turn into_ `fill = {r=0, g=2.7, b=0.765}` _in Lua._
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

    local props = style:match{type='circle'}
    inspect(props)
    --> { fill=<color 'white'>, radius=3 }

    local rnd=math.random
    for r=1,4 do
      local props = style:match{type='circle', r=r, hue=rnd(360) }
      inspect(props)
    end
    --> { fill=<color r=1.0 g=0.0 b=1.0 a=1.0>, radius=1 }
    --> { fill=<color r=0.0 g=1.0 b=0.4 a=1.0>, radius=2 }
    --> { fill=<color r=0.7 g=0.0 b=1.0 a=1.0>, radius=3 }
    --> { fill=<color r=0.8 g=0.0 b=1.0 a=1.0>, radius=4 }
    ```


## Simplifications/Limitations:

* ZSS assumes a **flat, unordered data model**. This means that there are no hierarchical selectors (no descendants, no children), no sibling selectors, and no pseudo-elements related to position.
* Using Lua to parse property expressions means there is no support for custom units on numbers using CSS syntax, or hexadecimal colors. You would need to wrap these in function calls like `len(5,cm)` or `color('#ff0033')`.
* Due to a simple parser:
  * you must not have a `{` character inside a selector. (Then again, when would you?)
  * you must not have a `;` character inside your declarations.
  * you must not have a `@` character inside your declarations.
  * you must not have an _unpaired_ `}` character inside your declarations.

The following CSS is currently unparsable in many ways:

```css
boo[a=='{'] { str:'nope'         } /* The { causes the selector to stop being parsed too soon    */
boo2        { no1:';'; ok:1      } /* The ; causes the value to stop being parsed too soon       */
boo3        { email:'me@here';   } /* The value get destroyed and becomes 'me_data_.here'        */
boo4        { no2:'}'            } /* The } causes the declaration to stop being parsed too soon */
yay         { tbl:{ a={b='ok'} } } /* Having { and } paired is OK, however                       */
```

If you need to have one of these characters inside a string, you can escape them using their hexadecimal escape equivalent:

* `;` — \x3B
* `@` — \x40
* `{` — \x7B
* `}` — \x7D

```css
person   { text:'me\x40company.com'       } /* me@company.com    */
message  { text:'tl\x3Bdr: this works'    } /* tl;dr: this works */
mustache { normal:':\x7B'; wicked:':\x7D' } /*    :{     :}      */
```


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

style:match{ type='text' }
--> {fill=<color 'white'>, font="main", size=20, stroke=false}

style:match{ type='text', tags={important=1} }
--> {fill={1, 1, 0}, font="main", size=20, stroke=false}

style:match{ id='title' }
--> {fill={1, 1, 0}, font="bold", size=20, stroke=<color 'white'>}

style:match{ type='text', tags={debug=1}, speed=37 }
--> {fill=<color 'red'>, font="main", opacity=1, size=20, stroke=false}
```


# Per-sheet Variables

ZSS adds a custom `@vars` directive handler that allows each sheet loaded into a style to have its own set of variables expressed as declarations, that can be used in other rules. For example:

```css
@vars  { baseFontSize:30 }
body   { fontSize: baseFontSize   }
header { fontSize: baseFontSize*2 }
```

Loading multiple stylesheets into the same style allows later stylesheets to use variables defined in an earlier stylesheet. Further, disabling and enabling a stylesheet disables its variables. Combining these allows you to load and control 'theme' stylesheets. For example:

**day.css**

```css
@vars {
  background: 'white';
  foreground: 'black';
}
```

**night.css**

```css
@vars {
  background: 'darkblue';
  foreground: 'lightblue';
}
```

**content.css**

```css
body { bgColor:background; textColor:foreground }
```

```lua
local body = {type='body'}
local style = zss:new{ files={'day.css', 'night.css', 'content.css'} }
print(style:match(body).bgColor) --> darkblue

style:disable('night.css')
print(style:match(body).bgColor) --> white

style:disable('day.css')
print(style:match(body).bgColor) --> nil
```

Multiple `@vars { … }` directives may appear anywhere in a stylesheet, and safely rely on variables from previously-loaded stylesheets as well as [constants](#myzssconstantsvalue_map) set for the style. However, the following behavior is undefined:

* Placing a rule that uses a variable before the `@vars { … }` directive that defines the variable.

    ```css
    /* this rule should be after the @vars */
    bad { size:x }
    @vars { x:20 }
    ```


* Referencing the value of a variable defined in the same stylesheet:

    ```css
    @vars {
       x : 25;
       y : x + 17; /* regardless of order, do not rely on another variable… */
    }
    @vars {
       z : x * 2; /* …not even in a later @vars block in the same sheet */
    }
    ```

    _A future release may allow later @vars blocks to refer to earlier blocks reliably._



# API

* [`ZSS:new()`](#zssnewopts) — create a style (aggregating many sheets and rules)
* [`myZSS:constants()`](#myzssconstantsvalue_map) — set value lookups
* [`myZSS:directives()`](#myzssdirectiveshandlers) — set at-rule handlers
* [`myZSS:add()`](#myzssaddcss) — parse CSS from string
* [`myZSS:load()`](#myzssload) — load CSS from file
* [`myZSS:match()`](#myzssmatchelement) — compute the declarations that apply to an element
* [`myZSS:extend()`](#myzssextend) — create a new style that derives from this one
* [`myZSS:disable()`](#myzssdisablesheetid) — stop using rules from a particular set of CSS
* [`myZSS:enable()`](#myzssenablesheetid) — resume using rules from a particular set of CSS


## ZSS:new(opts)

`opts` is a table with any of the following string keys (all optional):

* `constants` — a table mapping string literals (that might appear as values or functions in declarations) to the Lua value you would like them to have instead.
* `directives` — a table mapping the string name of an "at-rule" (without the `@`) to a function that should be invoked each time it is seen.
* `basecss` — a string of CSS rules to initially parse for the style.
* `files` — an array of string file names to load and parse (after the `basecss`).

### Example:

```lua
URL  = require'urlhandler'
FONT = require'myfontlib'
ZSS  = require'zss'
local style = ZSS:new{
   constants = {
      none  = false,
      color = require('color'),
      url   = URL.processURL,
   },
   directives = {
      -- e.g. @font-face { font-family='bold'; src:'fonts/Arial-bold.ttf' }
      ['font-face'] = function(style, props)
         FONT.createFont(props['font-family'], props.src)
      end
   },
   basecss = [[...css code...]],
   files   = {'a.css', 'b.css'},
}
```

Constants can be added to later using the `constants()` method.
Additional directives can be added later using the `directives()` method.
Additional raw CSS can be parsed later using the `add()` method.
Additional CSS files can be loaded by name later using the `load()` method.


## myZSS:constants(value_map)

Add key/value pairs to the literal value mappings used when parsing declaration values.

`value_map` is a table mapping string literals (that might appear as values or functions in declarations) to the Lua value you would like them to have instead.

The return value is the invoking ZSS style instance (for method chaining).

**Note**: constants are resolved when rules are added/loaded, unless there is a deferred reference in the value (e.g. `@foo`). Invoking the `constants()` method after CSS has been loaded will only affect CSS added/loaded after the call…or the evaluation of deferred values.

### Example:

```lua
local style = ZSS:new()
style:constants{ none=false, white={1,1,1}, red={1,0,0} }
style:add('* { a:none; b:white; c:red; d:orange } ')
style:match{ id='foo' }
--> {a=false, b={1,1,1}, c={1,0,0}, d=nil}
```

## myZSS:directives(handlers)

Add to the handler functions used when an at-rule is encountered during parsing.

`handlers` is a table mapping the name of the at-rule (without the leading `@`) to a Lua function to invoke. The function will be passed a reference to the ZSS style instance, and a table mapping property names to values seen in the declaration.

The return value is the invoking ZSS style instance (for method chaining).

### Example:

```lua
local myfontlib = require'somefontlib'
local style = ZSS:new()
style:directives{
  font = function(me, props)
    me:constants{ [props.name]=myfontlib.loadFont(props.src) }
  end
}
style:add[[
  @font { name:'mainFont'; src:'my.ttf' }
  text { font:mainFont }
]]
```


## myZSS:add(css)

Add CSS rules to the style (specified as a string of CSS).

**Notes**:

* You should invoke this method only after setting up any `constants` and `directives` mappings for the style.
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

The first return value is the invoking ZSS style instance (for method chaining).

The second return value is a unique identifier that may be used to later `disable()` and `enable()` the rules loaded in this CSS.


## myZSS:load(...)

Add CSS rules to the style, loaded from one or more files specified by file name.

### Example:

```lua
local style = ZSS:new()
style:constants(myconstants)
style:load('a.css', 'b.css', 'c.css')
```


## myZSS:match(element)

Use all rules in the style to compute the declarations that apply to described element.

`element` must be a table using any/all/none of the keys `type`, `id`, and `tags`, and may include arbitrary additional data properties:
`{type='mytype', id='myid', tags={tag1=1, tag2=1}, var1=42, var2=3.8}`.


### Example:

```lua
local style = ZSS:new():add[[
  *          { fill:none;  stroke:white; opacity:1.0 }
  text       { fill:white; stroke:none }
  .important { weight:bold; fill:red }
  .debug     { opacity:0.5 }
]]
local m1 = style:match{ type='text', tags={important=1} }
--> { fill='red', opacity=1.0, stroke='none', weight='bold' }

local m2 = style:match{ type='line', tags={debug=1} }
--> { fill='none', opacity=0.5, stroke='white' }

local m3 = style:match{}
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

Prevent a specific set of CSS from being used in the style (and all descendants created via `clone()`). For files, the `sheetid` is the path passed to `load()`; for CSS strings added via the `add()` method, the `sheetid` is the second string returned from `add()`. For css added using the `basecss` option to `new()`, use the string `"basecss"`.

### Example:

```lua
local main   = ZSS:new{ files={'base.css', 'day.css'} }
local style1 = main:clone():load('style1a.css')
local _, bID = style1:add('#additional { rules:here }')

style1:match(…) --> uses base.css, day.css, style1a.css, and additional rules loaded during add()

style1:disable(bID)
style1:match(…) --> uses base.css, day.css, style1a.css

main:disable('day.css')
style1:match(…) --> uses base.css and style1a.css
main:match(…)   --> uses base.css only

main:enable('day.css')
style1:match(…) --> uses base.css, day.css, and style1a.css
main:match(…)   --> uses base.css and day.css

style1:disable('day.css')
style1:match(…) --> uses base.css and doc1a.css
main:match(…)   --> uses base.css and day.css
```

**Note**: As shown in the last lines of the example above, a cloned style may disable rules _loaded_ in its parent; however, doing so does not disable them for the parent (or other clones of the parent).

## myZSS:enable(sheetid)

Re-enable CSS previously disabled with `disable()`. (See `disable()` for an example.)


# License & Contact

ZSS is copyright ©2018–2019 by Gavin Kistner and is licensed under the [MIT License](https://opensource.org/licenses/MIT). See the LICENSE.txt file for more details.

For bugs or feature requests please [open issues on GitHub](https://github.com/Phrogz/ZSS/issues). For other communication you can [email the author directly](mailto:!@phrogz.net?subject=ZSS).
