# History

## v1.0.1 — September 17th, 2019

* Speed improvement to matching (2✕ in the common case)


## v1.0 — August 29th, 2019

### New Features
* Conditions in CSS selectors may now use arbitrary Lua expressions,
  referencing attributes of the element, constants in the sheet, and full operators.
  * Old: `foo[@bar<17], foo[@bar=17] { /* hack around lack of <= support */ }`
  * New: `foo[17>=@bar][@baz<sheetconstant][@jim~=true] { /* so much power */ }`

### Backwards-Incompatible Changes
* All _matching_ takes place using only table 'elements' instead of 'descriptor' strings.
  * Old: `style:match('foo#bar.jim.jam[@v1=17][@v2=42]')`
  * New: `style:match{type='foo', id='bar', tags={jim=1, jam=1}, v1=17, v2=42}`
  * This update removes any computed match caching.
    There isn't a convenient string to hang the cache off of,
    and caching based on element tables will break if the table is mutated.
* All property-equality tests in conditions CSS selectors must now use two equals signs,
  as a single equals sign in a Lua expression is an assignment instead of a test.
  * Old: `foo[@bar=17] { … }`
  * New: `foo[@bar==17] { … }`
* All property names in conditions in CSS selectors must be prefixed with an `@` sign,
  now that the conditions support arbitrary expressions and may reference sheet constants.
  * Old: `foo[bar>42] { … }`
  * New: `foo[@bar<42] { … }`
