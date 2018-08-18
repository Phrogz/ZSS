--[=========================================================================[
   ZSS v0.5
   See http://github.com/Phrogz/ZSS for usage documentation.
   Licensed under MIT License.
   See https://opensource.org/licenses/MIT for details.
--]=========================================================================]

local ZSS = { VERSION="0.5" }
ZSS.__index = ZSS

local updaterules

-- ZSS:new{
--   functions  = {color=processColor, url=processURL },
--   constants  = {none=false, ['true']=true, ['false']=false, transparent=processColor(0,0,0,0) },
--   directives = { ['font-face']=processFontFaceRule },
--   basecss    = [[...css code...]],
--   files      = {'a.css', 'b.css'},
-- }
function ZSS:new(opts)
	local zss = {
		functions  = {}, -- function names (e.g. "url") mapped to function to process arguments into value
		constants  = {}, -- value literal strings mapped to equivalent values (e.g. "none"=false)
		directives = {}, -- map from name of at rule (without @) to function to invoke
		atrules    = {}, -- array of @font-face et. al, in document order; also indexed by rule name to array of declarations
		_rules     = {}, -- map of doc ids to array of rule tables, each sorted by document order
		_active    = {}, -- array of rule tables for active documents, sorted by specificity (rank)
		_docs      = {}, -- array of document names, with each name mapped its active state
		_computed  = {}, -- cached element signatures mapped to computed declarations
		_kids      = setmetatable({},{__mode='k'}), -- set of child tables mapped to true
		_parent    = nil, -- reference to the sheet that spawned this one
	}
	setmetatable(zss,ZSS)
	if opts then
		if opts.functions  then zss:valueFunctions(opts.functions)    end
		if opts.constants  then zss:valueConstants(opts.constants)    end
		if opts.basecss    then zss:add(opts.basecss)                 end
		if opts.files      then zss:load(table.unpack(opts.files))    end
		if opts.directives then zss:handleDirectives(opts.directives) end
	end
	updaterules(zss)
	return zss
end

-- Usage: myZSS:load( 'file1.css', 'file2.css', ... )
function ZSS:load(...)
	self._deferupdate = true
	for _,filename in ipairs{...} do
		local file = io.open(filename)
		if file then
			self:add(file:read('*all'), filename)
			file:close()
		else
			error("Could not load CSS file '"..filename.."'.")
		end
	end
	updaterules(self)
	self._deferupdate = false
	return self
end

-- Usage: myZSS:valueFunctions{ color=processColor, url=processURL }
function ZSS:valueFunctions(handlermap)
	for k,f in pairs(handlermap) do self.functions[k]=f end
	return self
end

-- Usage: myZSS:mapValues{ none=false, false=false, transparent=Color(0,0,0,0) }
function ZSS:valueConstants(valuemap)
	for k,v in pairs(valuemap) do self.constants[k]=v end
	return self
end

function ZSS:handleDirectives(handlermap)
	for k,v in pairs(handlermap) do self.directives[k]=v end
	return self
end

-- Resolve values in declarations based on values and handlers
function ZSS:eval(str)
	local result = self.constants[str]
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
				if self.functions[func] then
					result = self.functions[func](table.unpack(p))
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
-- Returns the sheet itself (for chaining) and id associated with the css (for later enable/disable)
function ZSS:add(css, sheetid)
	sheetid = sheetid or 'loaded css #'..(self._parent and #self._parent._docs or 0) + #self._docs + 1
	table.insert(self._docs, sheetid)
	self._docs[sheetid] = true
	local docrules = {}
	self._rules[sheetid] = docrules

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
				self.atrules[selector.directive] = self.atrules[selector.directive] or {}
				table.insert(self.atrules[selector.directive], declarations)
				local handler = self.directives[string.sub(selector.directive,2)]
				if handler then handler(self, declarations) end
			else
				selector.rank = {
					selector.id and 1 or 0,
					#selector.tags + #selector.data,
					selector.type and 1 or 0,
					0 -- the document order will be determined during updaterules()
				}
				local rule = {selector=selector, declarations=declarations, doc=sheetid}
				table.insert(docrules, rule)
			end
		end
	end

	-- sort rules and determine active based on rank
	if not self._deferupdate then updaterules(self) end

	return self, sheetid
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
	for _,rule in ipairs(self._active) do
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

function ZSS:extend(...)
	local kid = ZSS:new()
	kid._parent = self
	setmetatable(kid.constants,{__index=self.constants})
	setmetatable(kid.functions,{__index=self.functions})
	setmetatable(kid.directives,{__index=self.directives})
	self._kids[kid] = true
	kid:load(...)
	return kid
end

function ZSS:disable(sheetid)
	-- TODO: check if I, or any of my ancestors, have this sheet before disabling it
	self._docs[sheetid] = false
	updaterules(self)
end

function ZSS:enable(sheetid)
	if self._rules[sheetid] then
		self._docs[sheetid] = true
	else
		-- wipe out any override that might have been disabling an ancestor
		self._docs[sheetid] = nil
	end
	updaterules(self)
end

updaterules = function(self)
	-- reset the computed and active rule list
	self._computed = {}
	self._active = {}

	-- assume that the parent's active is already up-to-date
	if self._parent then
		for i,rule in ipairs(self._parent._active) do
			-- do not use parent's active if we overrode it
			if self._docs[rule.doc]~=false then
				table.insert(self._active, rule)
			end
		end
	end

	-- add all the rules from the active documents
	for _,sheetid in ipairs(self._docs) do
		if self._docs[sheetid] then
			for _,rule in ipairs(self._rules[sheetid]) do
				table.insert(self._active, rule)
				rule.selector.rank[4] = #self._active
			end
		end
	end

	-- sort the active rules by rank
	table.sort(self._active, function(r1, r2)
		r1,r2 = r1.selector.rank,r2.selector.rank
		if     r1[1]<r2[1] then return true elseif r1[1]>r2[1] then return false
		elseif r1[2]<r2[2] then return true elseif r1[2]>r2[2] then return false
		elseif r1[3]<r2[3] then return true elseif r1[3]>r2[3] then return false
		elseif r1[4]<r2[4] then return true else                    return false
		end
	end)

	-- ensure that any extended children are updated
	for kid,_ in pairs(self._kids) do
		updaterules(kid)
	end
end

return ZSS