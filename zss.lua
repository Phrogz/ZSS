local ZSS = {}
ZSS.__index = ZSS

function ZSS:new(...)
	local zss = setmetatable({rules={}, directives={}, computed={}},ZSS)
	for _,css in ipairs{...} do zss:parse(css) end
	return zss
end

function ZSS:load(filename)
	local file = io.open(filename)
	if file then
		self:parse(file:read('*all'))
		file:close()
	end
	return self
end

local function value(str)
	local result = tonumber(str)
	if not result then
		str = str:gsub("^'(.-)'$", '%1'):gsub('^"(.-)"$', '%1')
		if     str=='true'  then result=true
		elseif str=='false' then result=false
		else                     result=str
		end
	end
	return result
end

function ZSS.parse_selector(selector_str, from_data)
	if selector_str:match('^@[%a_][%w_-]*$') then
		return {directive=selector_str}
	else
		local selector = {
			type = selector_str:match('^[%a_][%w_-]*'),
			id  = selector_str:match('#([%a_][%w_-]*)'),
			tags={}, data={}
		}

		for name in selector_str:gmatch('%.([%a_][%w_-]*)') do
			selector.tags[name] = true
			if not from_data then
				selector.tags[#selector.tags+1] = name
			end
		end
		if not from_data then
			table.sort(selector.tags)
		end

		if not from_data then
			for name in selector_str:gmatch('%[%s*([%a_][%w_-]*)%s*%]') do
				selector.data[name] = true
				selector.data[#selector.data+1] = name
			end
		end

		for name, op, val in selector_str:gmatch('%[%s*([%a_][%w_-]*)%s*([<=>])%s*(.-)%s*%]') do
			if from_data then
				if op=='=' then
					selector.data[name] = value(val)
				end
			else
				selector.data[name] = { op=op, value=value(val) }
				selector.data[#selector.data+1] = name
			end
		end
		if not from_data then
			table.sort(selector.data)
		end

		return selector
	end
end

function ZSS:parse(css)
	for rule_str in css:gsub('/%*.-%*/',''):gmatch('[^%s].-}') do
		-- Convert declarations into a table mapping property to value
		local decl_str = rule_str:match('{%s*(.-)%s*}')
		local declarations = {}
		for key,val in decl_str:gmatch('([^%s]+)%s*:%s*([^;}]+)') do
			declarations[key] = value(val)
		end

		-- Create a unique rule for each selector in the rule
		local selectors_str = rule_str:match('(.-)%s*{')
		for selector_str in selectors_str:gmatch('%s*([^,]+)') do
			local selector = ZSS.parse_selector(selector_str:match "^%s*(.-)%s*$")
			if selector.directive then
				selector.declarations = declarations
				table.insert(self.directives, selector)
			else
				selector.rank = {
					selector.id and 1 or 0,
					#selector.tags + #selector.data,
					selector.type and 1 or 0,
					#self.rules
				}
				table.insert(self.rules, {selector=selector, declarations=declarations})
			end
		end
	end
	self.computed = {}
	self:sortrules()
	return self
end
ZSS.add = ZSS.parse

function ZSS:sortrules()
	table.sort(self.rules, function(r1, r2)
		r1,r2 = r1.selector.rank,r2.selector.rank
		if     r1[1]<r2[1] then return true elseif r1[1]>r2[1] then return false
		elseif r1[2]<r2[2] then return true elseif r1[2]>r2[2] then return false
		elseif r1[3]<r2[3] then return true elseif r1[3]>r2[3] then return false
		elseif r1[4]<r2[4] then return true else                    return false
		end
	end)
	return self
end

function ZSS:match(el)
	local signagure
	if type(el)=='string' then
		signature = el
		if self.computed[signature] then
			return self.computed[signature]
		else
			el = ZSS.parse_selector(signature, true)
		end
	end

	local computed = {}
	for _,rule in ipairs(self.rules) do
		if ZSS.matches(rule.selector, el) then
			for k,v in pairs(rule.declarations) do
				computed[k] = v
			end
		end
	end

	if signature then
		self.computed[signature] = computed
	end

	return computed
end

function ZSS.matches(selector, el)
	if selector.type and el.type~=selector.type then return false end
	if selector.id   and el.id~=selector.id     then return false end
	for _,tag in ipairs(selector.tags) do
		if not (el.tags and el.tags[tag]) then return false end
	end
	for _,name in ipairs(selector.data) do
		local val = el.data and el.data[name]
		if not val then return false end

		local attr = selector.data[name]
		if attr~=true then
			if     attr.op=='=' then if attr.value~=val then return false end
			elseif attr.op=='<' then if attr.value<=val then return false end
			elseif attr.op=='>' then if attr.value>=val then return false end
			end
		end
	end
	return true
end

return ZSS