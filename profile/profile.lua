--[=========================================================================================================[
0One selector vs.     0Unique keys vs.   0Type vs.  0ID vs.  05 classes   0Data selector  0string vs.
1many selectors vs.   1Colliding         1No Type   1None    1vs. none    1vs. none       1call() vs.
2many sheets                                                                              2@data vs.
                                                                                          3varkey+const vs.
                                                                                          4!dynamic
s String selector
t vs. Table

d Data values
n vs. none
--]=========================================================================================================]


-- test_0000000s
local tests = {
  {name='0000010s', descriptor='s1#foo.a.b.c.d.e', expected={p1='s1',p2='s1',p3='s1',p4='s1',p5='s1'}, n=5e4 },
  {name='0000010d', descriptor={type='s1', id='foo', tags={a=1,b=1,c=1,d=1,e=1}}, expected={p1='s1',p2='s1',p3='s1',p4='s1',p5='s1'}, n=2e4 },

  {name='1000010s', descriptor='s2#foo.a.b.c.d.e', expected={p1='v1',p2='v2',p3='v3',p4='v4',p5='v5'}, n=5e4 },
  {name='1000010d', descriptor={type='s2', id='foo', tags={a=1,b=1,c=1,d=1,e=1}}, expected={p1='v1',p2='v2',p3='v3',p4='v4',p5='v5'}, n=2e4 },

  {name='1100010s', descriptor='s3#foo.a.b.c.d.e', expected={p1='v1',p2='v2',p3='v3',p4='v4',p5='v5'}, n=5e4 },
  {name='1100010d', descriptor={type='s3', id='foo', tags={a=1,b=1,c=1,d=1,e=1}}, expected={p1='v1',p2='v2',p3='v3',p4='v4',p5='v5'}, n=2e4 },
}

package.path = '../?.lua'
local zss = require 'zss'
local style = zss:new()
style:load('sheet1.css')

local function tableEquals(actual, expected, msg, keyPath)
  if not keyPath then keyPath = {} end

  if type(actual) ~= 'table' then
    if not msg then msg = "Value passed to tableEquals() was not a table." end
    error(msg, 2 + #keyPath)
  end

  -- Ensure all keys in t1 match in t2
  for key,expectedValue in pairs(expected) do
    keyPath[#keyPath+1] = tostring(key)
    local actualValue = actual[key]
    if type(expectedValue)=='table' then
      if type(actualValue)~='table' then
        if not msg then
          msg = "Tables not equal; expected "..table.concat(keyPath,'.').." to be a table, but was a "..type(actualValue)
        end
        error(msg, 1 + #keyPath)
      elseif expectedValue ~= actualValue then
        tableEquals(actualValue, expectedValue, msg, keyPath)
      end
    else
      if actualValue ~= expectedValue then
        if not msg then
          if actualValue == nil then
            msg = "Tables not equal; missing key '"..table.concat(keyPath,'.').."'."
          else
            msg = "Tables not equal; expected '"..table.concat(keyPath,'.').."' to be "..tostring(expectedValue)..", but was "..tostring(actualValue)
          end
        end
        error(msg, 1 + #keyPath)
      end
    end
    keyPath[#keyPath] = nil
  end

  -- Ensure actual doesn't have keys that aren't expected
  for k,_ in pairs(actual) do
    if expected[k] == nil then
      if not msg then
        msg = "Tables not equal; found unexpected key '"..table.concat(keyPath,'.').."."..tostring(k).."'"
      end
      error(msg, 2 + #keyPath)
    end
  end

  return true
end

io.stdout:setvbuf("no")

for _,t in ipairs(tests) do
  io.write('Running '..t.name..'...')
  local results
  local start = os.clock()
  for i=1,t.n do results = style:match(t.descriptor) end
  local stop = os.clock()
  tableEquals(t.expected, results)
  print(('done (%.1fms)'):format(1000*(stop-start)))
end