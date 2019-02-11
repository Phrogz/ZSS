# Terminology

A **style** is an instance of ZSS.

An **extension** is a style that inherits from another, _**base**_ style.

A single style may load multiple **sheet** (aka **stylesheets**): text blocks with CSS-like syntax.

A sheet is composed of **directives** (aka **at-rules**) (e.g. `@vars { x:25 }`) and **rules** (e.g. `foo, bar { a:17; b:x+a }`):

* A directive is composed of a name (`@vars`) and one or more **declarations** (e.g. `x:25`).
* A rule is comprised of **selector(s)** (e.g. `foo, bar`) and **declarations** (e.g. `a:17; b:x+a`).
   * _Selectors use mostly the same syntax as CSS._
   * _Declarations use mostly Lua syntax._

A single style has a set of **constants** associated with it: named values that are made available during evaluation of declarations. Each sheet loaded into a style also has its own set of **constants**.

A sheet may be **disabled**, causing it to no longer be considered during matches on the style. It may later be **enabled**.

A **block** is a Lua function generated from a declaration, used to evaluate the code into a concrete value, along with a cached known value for the block (and some other housekeeping flags related to caching and evaluation).

An **environment** is a table used as the context to evaluate blocks under.


# Evaluation

When a style is created, a single **constants** table (`_constants`) and an **environment** table (`_envs[1]`) are created for the style.

When a sheet is loaded into a style, a new **constants** table and **environment** table are created for that sheet. These tables are set up in a cascading inheritance:

* The sheet's environment inherits from the sheet's constants.
* The sheet's constants inherits from the last-loaded-and-active sheet's contants.
* The first sheet's constants inherit from the style's constants.

When each declaration is parsed, it is turned into block. This block is compiled to use the `environment` for the sheet. Per the above, this environment falls back to the constants for this sheet, and from there backwards through the active sheets in reverse-loaded order, finishing at the constants for the style.

When a block used in a match, its cached value is returned if available. If not available, the block's function is run to generate a value. That value is cached unless the block is marked as do-not-cache.

* Blocks are marked do-not-cache if the expression leads with an exclamation point (as a feature).
* Blocks are marked do-not-cache if the expression includes an `@data` reference (under the assumption that the data variables will change frequently).
* Blocks' caches are invalidated when sheets are disabled or enabled (in case the block happens to rely on a sheet variable from a previous sheet).
* Blocks' caches are invalidated when style constants change (in case the block happens to rely on a style constant). 


# Future Possibilities

We could allow variables to reference other variables in the same block if we ordered the blocks passed to @vars, and stored the blocks in order.

We could detect exactly which blocks reference exactly which sheet and style variables via custom `__index` functions that are used only during initial block setup. Then instead of invalidating **all** downstream block caches during enable()/disable()/constants(), we could invalidate only the dependent block caches.