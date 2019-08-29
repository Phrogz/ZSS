# History

## v1.0 — August 20th, 2019

### Backwards-Incompatible Changes
* All matching takes place using elements instead of 'descriptors'.
  * Old: `style:match('foo#bar.jim.jam[@v1=12][@v2=24])`
  * New: `style:match{type='foo', id='bar', tags={jim=1, jam=1}, v1=12, v2=24}`
  * This update removes any computed match caching.
    There isn't a convenient string to hang the cache off of,
    and caching based on element tables will break if the table is mutated.

### Bug Fixes
