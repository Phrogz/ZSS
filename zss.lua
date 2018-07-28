
--[[
doc ::= (comment | rule)+
comment ::= '/*' text-except-comment-close '*/'
rule ::= ruleset '{' declaration? (';' declaration)* '}'
ruleset ::= selector (',' selector)*
selector ::= directive | tag? ('#' ID)? ('.' Name)* ('[' attribute ([<=>] value)? ']')*
declaration ::= property ':' value
value ::= Number | text | string
text ::= [^ \t\r\n]+
string ::= "'" [^'}] "'" | '"' [^"}] '"'
directive ::= '@' Name
tag ::= '*' | Name
attribute ::= Name
property ::= Name
ID ::= Name
Name ::= [A-Za-z] [A-Za-z_-]*
]]

--[[
rule = { selector=..., order={1,2,3,4}, declarations=... }
selector = { tag='text', ids={}, classes={ped=1, human=2}, attributes={...} }
attributes = { foo={ value=42, op='<' }, bar=true }
declarations = { ['font-family']='main', fill='transparent', stroke= }
]]

local ZSS = {}
ZSS.__index = ZSS

function ZSS:new(...)
	local zss = setmetatable({docs={}, rules={}, directives={}, computed={}},ZSS)
	for _,css in ipairs{...} do zss:parse(css) end
	return zss
end

-- https://stackoverflow.com/a/1647577/405017
local function split(str, pat)
  local st, g = 1, str:gmatch("()("..(pat or '%s+')..")")
  local function getter(segs, seps, sep, cap1, ...)
    st = sep and seps + #sep
    return str:sub(segs, (seps or 0) - 1), cap1 or sep, ...
  end
  return function() if st then return getter(st, g()) end end
end

function ZSS:load(filename)
	local file = io.open(filename)
	if file then
		self:parse(file:read('*all'), filename)
		file:close()
	end
	return self
end

function ZSS:parse(css, docname)
	table.insert(self.docs, docname or "(supplied code)")

	local rulenum = 1
	for rulestr in css:gsub('/%*.-%*/',''):gmatch('[^%s].-}') do
		-- Convert declarations into a table mapping property to value
		local declstr = rulestr:match('{%s*(.-)%s*}')
		local decls = {}
		for key,value in declstr:gmatch('([^%s]+)%s*:%s*([^;}]+)') do
			decls[key] = value
		end

		-- Create a unique rule for each selector in the rule
		local selectorstr = rulestr:match('(.-)%s*{')
		for selector in split(selectorstr, '%s*,%s*') do
			if selectorstr:match('^@[%a_][%w_-]*$') then
				table.insert(self.directives, {name=selectorstr, declarations=decls})
			else
				local selector = {
					tag = selectorstr:match('^[%a_][%w_-]*'),
					id  = selectorstr:match('#([%a_][%w_-]*)'),
					classes={}, attributes={}
				}

				-- https://www.w3.org/TR/2018/CR-selectors-3-20180130/#specificity
				-- with document number and rule number appended
				selector.rank = { selector.id and 1 or 0, 0, selector.tag and 1 or 0, #self.docs, rulenum }

				for class in selectorstr:gmatch('%.([%a_][%w_-]*)') do
					selector.classes[class] = true
					selector.rank[2] = selector.rank[2] + 1
				end

				for name in selectorstr:gmatch('%[%s*([%a_][%w_-]*)%s*%]') do
					selector.attributes[name] = true
					selector.rank[2] = selector.rank[2] + 1
				end

				for name, op, val in selectorstr:gmatch('%[%s*([%a_][%w_-]*)%s*([<=>])%s*(.-)%s*%]') do
					selector.attributes[name] = { op=op, value=val }
					selector.rank[2] = selector.rank[2] + 1
				end

				table.insert(self.rules, {selector=selector, declarations=decls})
			end
		end
		rulenum = rulenum + 1
	end
	self.computed = {}
	self:sortrules()
	return self
end

function ZSS:sortrules()
	table.sort(self.rules, function(r1, r2)
		r1,r2 = r1.selector.rank,r2.selector.rank
		if r1[1] < r2[1] then
			return true
		elseif r1[1] > r2[1] then
			return false
		elseif r1[2] < r2[2] then
			return true
		elseif r1[2] > r2[2] then
			return false
		elseif r1[3] < r2[3] then
			return true
		elseif r1[3] > r2[3] then
			return false
		elseif r1[4] < r2[4] then
			return true
		elseif r1[4] > r2[4] then
			return false
		elseif r1[5] < r2[5] then
			return true
		else
			return false
		end
	end)
	return self
end

function ZSS:match(el)
	if type(el)=='string' then
	else
		error('only strings supported')
	end

	local key = string.format(
		'%s#%s.%s%s',
		el.tag or '*',
		el.id or '*',
	)
return ZSS