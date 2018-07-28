local ZSS = {}
ZSS.__index = ZSS

function ZSS:new(...)
	local zss = setmetatable({docs={}, rules={}, directives={}, computed={}},ZSS)
	for _,css in ipairs{...} do zss:parse(css) end
	return zss
end

function ZSS:load(filename)
	local file = io.open(filename)
	if file then
		self:parse(file:read('*all'), filename)
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

function ZSS.parse_selector(selector_str)
	if selector_str:match('^@[%a_][%w_-]*$') then
		return {directive=selector_str}
	else
		local selector = {
			type = selector_str:match('^[%a_][%w_-]*'),
			id  = selector_str:match('#([%a_][%w_-]*)'),
			classes={}, attributes={}
		}

		-- https://www.w3.org/TR/2018/CR-selectors-3-20180130/#specificity
		-- with document number and rule number appended

		for class in selector_str:gmatch('%.([%a_][%w_-]*)') do
			selector.classes[class] = true
			selector.classes[#selector.classes+1] = class
		end
		table.sort(selector.classes)

		for name in selector_str:gmatch('%[%s*([%a_][%w_-]*)%s*%]') do
			selector.attributes[name] = true
			selector.attributes[#selector.attributes+1] = name
		end

		for name, op, val in selector_str:gmatch('%[%s*([%a_][%w_-]*)%s*([<=>])%s*(.-)%s*%]') do
			selector.attributes[name] = { op=op, value=value(val) }
			selector.attributes[#selector.attributes+1] = name
		end
		table.sort(selector.attributes)

		return selector
	end
end

function ZSS:parse(css, docname)
	table.insert(self.docs, docname or "(raw string)")

	local rulenum = 1
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
					#selector.classes + #selector.attributes,
					selector.type and 1 or 0,
					#self.docs,
					rulenum
				}
				table.insert(self.rules, {selector=selector, declarations=declarations})
			end
		end
		rulenum = rulenum + 1
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
		elseif r1[4]<r2[4] then return true elseif r1[4]>r2[4] then return false
		elseif r1[5]<r2[5] then return true else                      return false
		end
	end)
	return self
end

function ZSS:match(el)
	local signature
	if type(el)=='string' then
		signature = el
	else
		signature = el.type or '*'
		if el.id then
			signature = signature..'#'..el.id
		end
		if el.classes[1] then
			signature = signature..'.'..table.concat(el.classes,'.')
		end
		if el.attributes[1] then
			for _,name in ipairs(el.attributes) do
				local attr = el.attributes[name]
				signature = signature..'['..name
				if attr.op then signature = signature..attr.op..attr.value end
				signature = signature..']'
			end
		end
	end

	if not self.computed[signature] then
		if type(el)=='string' then
			el = ZSS.parse_selector(signature)
		end
		local decls = {}
		for _,rule in ipairs(self.rules) do
			if ZSS.matches(rule.selector, el) then
				for k,v in pairs(rule.declarations) do
					decls[k] = v
				end
			end
		end
		self.computed[signature] = decls
	end

	return self.computed[signature]
end

function ZSS.matches(selector, el)
	if selector.type and el.type~=selector.type then return false end
	if selector.id  and el.id~=selector.id   then return false end
	for _,class in ipairs(selector.classes) do
		if not el.classes[class] then return false end
	end
	for _,name in ipairs(selector.attributes) do
		if not el.attributes[name] then return false end
		local sattr = selector.attributes[name]
		local eattr = el.attributes[name]
		if sattr.op then
			if sattr.op=='=' then
				if sattr.value~=eattr.value then return false end
			elseif sattr.op=='<' then
				if sattr.value<=eattr.value then return false end
			elseif sattr.op=='>' then
				if sattr.value>=eattr.value then return false end
			end
		end
	end
	return true
end

return ZSS