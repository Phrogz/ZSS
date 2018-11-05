--[=========================================================================================================[
0One selector vs.     0Unique keys vs.   0Type vs.  0ID vs.  05 classes   0Data selector  0string vs.
1many selectors vs.   1Colliding         1No Type   1None    1vs. none    1vs. none       1call() vs.
2many sheets                                                                              2@data vs.
                                                                                          4!dynamic
s String selector
t vs. Table

d Data values
n vs. none
--]=========================================================================================================]

-- test_0000000s
local tests = {
  {name='0000010d', descriptor={type='s1', id='foo', tags={a=1,b=1,c=1,d=1,e=1}}, expected={p1='s1',p2='s1',p3='s1',p4='s1',p5='s1'}, n=13157 },
  {name='0000010s', descriptor='s1#foo.a.b.c.d.e', expected={p1='s1',p2='s1',p3='s1',p4='s1',p5='s1'}, n=120450 },
  {name='0000110d', descriptor={type='s11', id='foo'}, expected={p1='s1',p2='s1',p3='s1',p4='s1',p5='s1'}, n=13793 },
  {name='0000110s', descriptor='s11#foo', expected={p1='s1',p2='s1',p3='s1',p4='s1',p5='s1'}, n=123592 },
  {name='0001010d', descriptor={type='s4', tags={a=1,b=1,c=1,d=1,e=1}}, expected={p1='s1',p2='s1',p3='s1',p4='s1',p5='s1'}, n=13489 },
  {name='0001010s', descriptor='s4.a.b.c.d.e', expected={p1='s1',p2='s1',p3='s1',p4='s1',p5='s1'}, n=126262 },
  {name='0001110d', descriptor={type='s14'}, expected={p1='s1',p2='s1',p3='s1',p4='s1',p5='s1'}, n=14084 },
  {name='0001110s', descriptor='s14', expected={p1='s1',p2='s1',p3='s1',p4='s1',p5='s1'}, n=124677 },
  {name='0010010d', descriptor={id='id1', tags={a=1,b=1,c=1,d=1,e=1}}, expected={p1='s1',p2='s1',p3='s1',p4='s1',p5='s1'}, n=13355 },
  {name='0010010s', descriptor='#id1.a.b.c.d.e', expected={p1='s1',p2='s1',p3='s1',p4='s1',p5='s1'}, n=127272 },
  {name='0010100s', descriptor='#idstr[@d=17]', expected={p1='str2'}, n=336699 },
  {name='0010101s', descriptor='#idfun[@d=17]', expected={p1=17},     n=341463 },
  {name='0010102s', descriptor='#iddat[@d=17]', expected={p1=17},     n=285713 },
  {name='0010103s', descriptor='#idvar[@d=17]', expected={p1=17},     n=344912 },
  {name='0010104s', descriptor='#iddyn[@d=17]', expected={p1=17},     n=278689 },
  {name='0010110d', descriptor={id='id4'}, expected={p1='s1',p2='s1',p3='s1',p4='s1',p5='s1'}, n=14219 },
  {name='0010110s', descriptor='#id4', expected={p1='s1',p2='s1',p3='s1',p4='s1',p5='s1'}, n=126903 },
  {name='0010110s', descriptor='#idstr', expected={p1='str'},     n=351757 },
  {name='0010111s', descriptor='#idfun', expected={p1=42},        n=349998 },
  {name='0010112s', descriptor='#iddat[@d=42]', expected={p1=42}, n=290214 },
  {name='0010113s', descriptor='#idvar', expected={p1=42},        n=351757 },
  {name='0010114s', descriptor='#iddyn', expected={p1=42},        n=277281 },
  {name='0011010d', descriptor={tags={a1=1,b1=1,c1=1,d1=1,e1=1}}, expected={p1='s1',p2='s1',p3='s1',p4='s1',p5='s1'}, n=13332 },
  {name='0011010s', descriptor='.a1.b1.c1.d1.e1', expected={p1='s1',p2='s1',p3='s1',p4='s1',p5='s1'}, n=126638 },
  {name='1000010d', descriptor={type='s2', id='foo', tags={a=1,b=1,c=1,d=1,e=1}}, expected={p1='v1',p2='v2',p3='v3',p4='v4',p5='v5'}, n=11477 },
  {name='1000010s', descriptor='s2#foo.a.b.c.d.e', expected={p1='v1',p2='v2',p3='v3',p4='v4',p5='v5'}, n=126638 },
  {name='1000110d', descriptor={type='s12', id='foo'}, expected={p1='v1',p2='v2',p3='v3',p4='v4',p5='v5'}, n=12949 },
  {name='1000110s', descriptor='s12#foo', expected={p1='v1',p2='v2',p3='v3',p4='v4',p5='v5'}, n=126759 },
  {name='1001010d', descriptor={type='s5', tags={a=1,b=1,c=1,d=1,e=1}}, expected={p1='v1',p2='v2',p3='v3',p4='v4',p5='v5'}, n=11485 },
  {name='1001010s', descriptor='s5.a.b.c.d.e', expected={p1='v1',p2='v2',p3='v3',p4='v4',p5='v5'}, n=126125 },
  {name='1001110d', descriptor={type='s15'}, expected={p1='v1',p2='v2',p3='v3',p4='v4',p5='v5'}, n=13099 },
  {name='1001110s', descriptor='s15', expected={p1='v1',p2='v2',p3='v3',p4='v4',p5='v5'}, n=126759 },
  {name='1010010d', descriptor={id='id2', tags={a=1,b=1,c=1,d=1,e=1}}, expected={p1='v1',p2='v2',p3='v3',p4='v4',p5='v5'}, n=11744 },
  {name='1010010s', descriptor='#id2.a.b.c.d.e', expected={p1='v1',p2='v2',p3='v3',p4='v4',p5='v5'}, n=126261 },
  {name='1010110d', descriptor={id='id5'}, expected={p1='v1',p2='v2',p3='v3',p4='v4',p5='v5'}, n=13118 },
  {name='1010110s', descriptor='#id5', expected={p1='v1',p2='v2',p3='v3',p4='v4',p5='v5'}, n=125391 },
  {name='1011010d', descriptor={tags={a2=1,b2=1,c2=1,d2=1,e2=1}}, expected={p1='v1',p2='v2',p3='v3',p4='v4',p5='v5'}, n=11893 },
  {name='1011010s', descriptor='.a2.b2.c2.d2.e2', expected={p1='v1',p2='v2',p3='v3',p4='v4',p5='v5'}, n=126759 },
  {name='1100010d', descriptor={type='s3', id='foo', tags={a=1,b=1,c=1,d=1,e=1}}, expected={p1='v1',p2='v2',p3='v3',p4='v4',p5='v5'}, n=11156 },
  {name='1100010s', descriptor='s3#foo.a.b.c.d.e', expected={p1='v1',p2='v2',p3='v3',p4='v4',p5='v5'}, n=126125 },
  {name='1100110d', descriptor={type='s13', id='foo'}, expected={p1='v1',p2='v2',p3='v3',p4='v4',p5='v5'}, n=12407 },
  {name='1100110s', descriptor='s13#foo', expected={p1='v1',p2='v2',p3='v3',p4='v4',p5='v5'}, n=126903 },
  {name='1101010d', descriptor={type='s6', tags={a=1,b=1,c=1,d=1,e=1}}, expected={p1='v1',p2='v2',p3='v3',p4='v4',p5='v5'}, n=11234 },
  {name='1101010s', descriptor='s6.a.b.c.d.e', expected={p1='v1',p2='v2',p3='v3',p4='v4',p5='v5'}, n=126126 },
  {name='1101110d', descriptor={type='s16'}, expected={p1='v1',p2='v2',p3='v3',p4='v4',p5='v5'}, n=12392 },
  {name='1101110s', descriptor='s16', expected={p1='v1',p2='v2',p3='v3',p4='v4',p5='v5'}, n=125391 },
  {name='1110010d', descriptor={id='id3', tags={a=1,b=1,c=1,d=1,e=1}}, expected={p1='v1',p2='v2',p3='v3',p4='v4',p5='v5'}, n=11348 },
  {name='1110010s', descriptor='#id3.a.b.c.d.e', expected={p1='v1',p2='v2',p3='v3',p4='v4',p5='v5'}, n=124998 },
  {name='1110110d', descriptor={id='id6'}, expected={p1='v1',p2='v2',p3='v3',p4='v4',p5='v5'}, n=12754 },
  {name='1110110s', descriptor='#id6', expected={p1='v1',p2='v2',p3='v3',p4='v4',p5='v5'}, n=126125 },
  {name='1111010d', descriptor={tags={a3=1,b3=1,c3=1,d3=1,e3=1}}, expected={p1='v1',p2='v2',p3='v3',p4='v4',p5='v5'}, n=11551 },
  {name='1111010s', descriptor='.a3.b3.c3.d3.e3', expected={p1='v1',p2='v2',p3='v3',p4='v4',p5='v5'}, n=125498 },
}
package.path = '../?.lua'      local zss = require 'zss'
local style = zss:new()
style:constants{
  echo=function(n) return n end,
  global=25,
}
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
            msg = "Tables not equal; missing expected key '"..table.concat(keyPath,'.').."'."
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
      if not msg then msg = "Tables not equal; found unexpected key '"..table.concat(keyPath,'.').."."..tostring(k).."'" end
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
  local elapsed = os.clock()-start
  tableEquals(results, t.expected)
  print(('done (%.1fms) %d'):format(1000*elapsed, math.floor(t.n*0.2/elapsed)))
end