local ZSS = {}
ZSS.__index = ZSS

-- ZSS:new{
--   handlers = {color=processColor, url=processURL },
--   values   = {none=false, ['true']=true, ['false']=false, transparent=processColor(0,0,0,0) },
--   basecss  = [[...css code...]],
--   files    = {'a.css', 'b.css'},
-- }
function ZSS:new(opts)
	local zss = {
		rules     = {}, -- array of rule tables, sorted by rank (specificity)
		atrules   = {}, -- array of @font-face et. al, in document order
		_computed = {}, -- cached element signatures mapped to computed declarations
		_handlers = {}, -- function names (e.g. "url") mapped to function to process arguments into value
		_values   = {}, -- value literal strings mapped to equivalent values (e.g. "none"=false)
	}
	setmetatable(zss,ZSS)
	if opts then
		if opts.handlers then zss:handlers(opts.handlers)        end
		if opts.values   then zss:values(opts.values)            end
		if opts.basecss  then zss:add(opts.basecss)              end
		if opts.files    then zss:load(table.unpack(opts.files)) end
	end
	return zss
end

-- Usage: myZSS:load( 'file1.css', 'file2.css', ... )
function ZSS:load(...)
	for _,filename in ipairs{...} do
		local file = io.open(filename)
		if file then
			self:add(file:read('*all'))
			file:close()
		else
			error("Could not load CSS file '"..file.."'.")
		end
	end
	return self
end

-- Usage: myZSS:handlers{ color=processColor, url=processURL }
function ZSS:handlers(handlers)
	for k,f in pairs(handlers) do self._handlers[k]=f end
	return self
end

-- Usage: myZSS:values{ none=false, false=false, transparent=Color(0,0,0,0) }
function ZSS:values(valuemapping)
	self._values = valuemapping
	return self
end

-- Resolve values in declarations based on values and handlers
function ZSS:eval(str)
	local result = self._values[str]
	if result==nil then result = tonumber(str) end
	if result==nil then
		result = str:match('^"(.-)"$') or str:match("^'(.-)'$")
		if result==nil then
			local func, params = str:match('^([%a_][%w_-]*)%(%s*(.-)%s*%)$')
			if func then
				local p={}
				for param in params:gmatch('%s*([^,]+),?') do
					table.insert(p,self:eval(param:gsub('%s+$','')))
				end
				if self._handlers[func] then
					result = self._handlers[func](table.unpack(p))
				else
					result = { func=func, params=p }
				end
			else
				result = str
			end
		end
	end
	return result
end

-- Convert a selector string into its component pieces;
-- from_data=true parses an element descriptor (skips some steps)
function ZSS:parse_selector(selector_str, from_data)
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
		if not from_data then table.sort(selector.tags) end

		if not from_data then
			for name in selector_str:gmatch('%[%s*([%a_][%w_-]*)%s*%]') do
				selector.data[name] = true
				selector.data[#selector.data+1] = name
			end
		end

		for name, op, val in selector_str:gmatch('%[%s*([%a_][%w_-]*)%s*([<=>])%s*(.-)%s*%]') do
			if from_data then
				if op=='=' then
					selector.data[name] = self:eval(val)
				end
			else
				selector.data[name] = { op=op, value=self:eval(val) }
				selector.data[#selector.data+1] = name
			end
		end
		if not from_data then table.sort(selector.data) end

		return selector
	end
end

-- Add a block of raw CSS rules (as a single string) to the style sheet
function ZSS:add(css)
	for rule_str in css:gsub('/%*.-%*/',''):gmatch('[^%s].-}') do
		-- Convert declarations into a table mapping property to value
		local decl_str = rule_str:match('{%s*(.-)%s*}')
		local declarations = {}
		for key,val in decl_str:gmatch('([^%s]+)%s*:%s*([^;}]+)') do
			declarations[key] = self:eval(val)
		end

		-- Create a unique rule for each selector in the rule
		local selectors_str = rule_str:match('(.-)%s*{')
		for selector_str in selectors_str:gmatch('%s*([^,]+)') do
			local selector = self:parse_selector(selector_str:match "^%s*(.-)%s*$")
			if selector.directive then
				selector.declarations = declarations
				table.insert(self.atrules, selector)
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
	self._computed = {}

	-- sort the rules by rank
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

-- Given an element descriptor string or table, compute the declarations that apply. For example:
-- local values = myZSS:match '.ped'
-- local values = myZSS:match 'text#accel.label'
-- local values = myZSS:match 'text#accel.value.negative[val=0.3]'
-- local values = myZSS:match{ type='text', id='accel', tags={value=1, negative=1}, data={value=0.3} }
--
-- Using a string will cache the result. Later requests that use the same string are 40x faster.
--
-- Use an element descriptor will not use the cache (either for lookup or storing the result).
-- Use element descriptors when you have data values that change.
function ZSS:match(el)
	local descriptor
	if type(el)=='string' then
		descriptor = el
		if self._computed[descriptor] then
			return self._computed[descriptor]
		else
			el = self:parse_selector(descriptor, true)
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

	if descriptor then
		self._computed[descriptor] = computed
	end

	return computed
end

-- Test to see if an element descriptor table matches a specific selector table
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