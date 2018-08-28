--[=========================================================================[
   ZSS v0.9.2
   See http://github.com/Phrogz/ZSS for usage documentation.
   Licensed under MIT License.
   See https://opensource.org/licenses/MIT for details.
--]=========================================================================]

local ZSS = { VERSION="0.9.2", debug=print, info=print, warn=print, error=print }
ZSS.__index = ZSS

local updaterules

-- ZSS:new{
--   constants  = { none=false, transparent=processColor(0,0,0,0), color=processColor },
--   directives = { ['font-face']=processFontFaceRule },
--   basecss    = [[...css code...]],
--   files      = { 'a.css', 'b.css' },
-- }
function ZSS:new(opts)
	local zss = {
		atrules     = {}, -- array of @font-face et. al, in document order; also indexed by rule name to array of declarations
		_directives = {}, -- map from name of at rule (without @) to function to invoke
		_constants  = {}, -- value literal strings mapped to equivalent values (e.g. "none"=false)
		_rules      = {}, -- map of doc ids to array of rule tables, each sorted by document order
		_active     = {}, -- array of rule tables for active documents, sorted by specificity (rank)
		_docs       = {}, -- array of document names, with each name mapped its active state
		_computed   = {}, -- cached element signatures mapped to computed declarations
		_kids       = setmetatable({},{__mode='k'}), -- set of child tables mapped to true
		_parent     = nil, -- reference to the sheet that spawned this one
		_env        = {},  -- table that mutates and changes to evaluate functions
	}
	setmetatable(zss._env,{__index=zss._constants})
	setmetatable(zss,ZSS)
	if opts then
		if opts.constants  then zss:constants(opts.constants)      end
		if opts.directives then zss:directives(opts.directives)    end
		if opts.basecss    then zss:add(opts.basecss)              end
		if opts.files      then zss:load(table.unpack(opts.files)) end
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

function ZSS:valueFunctions(...)
	self.debug("ZSS:valueFunctions() is deprecated; use ZSS:constants() instead")
	self:constants(...)
end

function ZSS:valueConstants(...)
	self.debug("ZSS:valueConstants() is deprecated; use ZSS:constants() instead")
	self:constants(...)
end

-- Usage: myZSS:mapValues{ none=false, transparent=Color(0,0,0,0), rgba=color.makeRGBA }
function ZSS:constants(valuemap)
	for k,v in pairs(valuemap) do self._constants[k]=v end
	return self
end

function ZSS:directives(handlermap)
	for k,v in pairs(handlermap) do self._directives[k]=v end
	return self
end

-- Parse and evaluate values in declarations
function ZSS:eval(str, sheetid)
	if str:find('@') then
		local f,err = load('return '..str:gsub('@','_data_.'), nil, 't', self._env)
		if not f then
			self.error(err)
		else
			return {_zssfunc=f}
		end
	else
		local f,err = load('return '..str, nil, 't', self._constants)
		if f then
			local ok,result = pcall(f)
			if ok then
				return result
			else
				self.error(('Error when evaluating %s: %s'):format(sheetid, result))
			end
		else
			self.error(('Error compiling %s: %s'):format(sheetid, result))
		end
	end
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

		-- Find all the tags
		for name in selector_str:gmatch('%.([%a_][%w_-]*)') do
			selector.tags[name] = true
			if not from_data then
				selector.tags[#selector.tags+1] = name
			end
		end
		if not from_data then table.sort(selector.tags) end

		-- Find all attribute sections, e.g. [@attr], [@attr<17], [attr=12], …
		for attr in selector_str:gmatch('%[%s*(.-)%s*%]') do
			local attr_name_only = attr:match('^@?([%a_][%w_-]*)$')
			if attr_name_only then
				selector.data[attr_name_only] = true
				if not from_data then table.insert(selector.data, attr_name_only) end
			elseif from_data then
				local name, op, val = attr:match('^@?([%a_][%w_-]*)%s*(=)%s*(.-)$')
				if not name or op~='=' then
					self.warn(("ZSS ignoring invalid data assignment '%s' in item descriptor '%s'"):format(attr, selector_str))
				else
					selector.data[name] = self:eval(val, selector_str)
				end
			else
				local name, op, val = attr:match('^@?([%a_][%w_-]*)%s*([<=>])%s*(.-)$')
				if not name then
					self.warn(("WARNING: invalid attribute selector '%s' in '%s'; must be like [@name < 42]"):format(attr, selector_str))
					return nil
				else
					selector.data[name] = { op=op, value=self:eval(val, selector_str) }
					table.insert(selector.data, name)
				end
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

	for rule_str in css:gsub('/%*.-%*/',''):gmatch('[^%s][^{]+%b{}') do

		-- Convert declarations into a table mapping property to value
		local decl_str = rule_str:match('[^{]*(%b{})'):sub(2,-2)
		local declarations = {}
		for key,val in decl_str:gmatch('([^%s:]+)%s*:%s*([^;]+)') do
			declarations[key] = self:eval(val, sheetid)
		end

		-- Create a unique rule for each selector in the rule
		local selectors_str = rule_str:match('(.-)%s*{')
		for selector_str in selectors_str:gmatch('%s*([^,]+)') do
			local selector = self:parse_selector(selector_str:match "^%s*(.-)%s*$")
			if selector then
				if selector.directive then
					selector.declarations = declarations
					table.insert(self.atrules, selector)
					self.atrules[selector.directive] = self.atrules[selector.directive] or {}
					table.insert(self.atrules[selector.directive], declarations)
					local handler = self._directives[string.sub(selector.directive,2)]
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
	local descriptor, computed, placeholders, data

	-- See if we previously saved off the computed result
	if type(el)=='string' then
		descriptor = el
		local compdata = self._computed[descriptor]
		if compdata then
			computed,placeholders,data = compdata[1],compdata[2],compdata[3]
		else
			-- We didn't have one saved, so we need to parse the descriptor to an element table
			el = self:parse_selector(descriptor, true)
			data = el.data
		end
	end

	if not computed then
		computed = {}
		for _,rule in ipairs(self._active) do
			if ZSS.matches(rule.selector, el) then
				for k,v in pairs(rule.declarations) do
					computed[k] = v
				end
			end
		end
		for prop,value in pairs(computed) do
			if type(value)=='table' and value._zssfunc then
				if not placeholders then
					placeholders = {}
				end
				placeholders[prop] = value._zssfunc
			end
		end
	end

	-- Cache the rules, placeholders, and environment if a string was used as the `el` descriptor
	if descriptor and not self._computed[descriptor] then
		self._computed[descriptor] = {computed,placeholders,data}
	end

	-- If some of the values are code that needs to be evaluated, do so
	if placeholders then
		local result = {}
		self._env._data_ = data or el.data or {}
		for k,v in pairs(computed) do
			if placeholders[k] then
				local ok,res = pcall(v._zssfunc)
				if ok then
					v=res
				else
					self.error('CSS error calculating "'..k..'": '..res)
					v=nil
				end
			end
			result[k] = v
		end
		return result
	else
		return computed
	end
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
	setmetatable(kid._constants,{__index=self._constants})
	setmetatable(kid._directives,{__index=self._directives})
	self._kids[kid] = true
	kid:load(...)
	return kid
end

function ZSS:sheetids()
	local ids = self._parent and self._parent:sheetids() or {}
	table.move(self._docs, 1, #self._docs, #ids+1, ids)
	for _,id in ipairs(self._docs) do ids[id] = true end
	return ids
end

function ZSS:disable(sheetid)
	local ids = self:sheetids()
	if ids[sheetid] then
		self._docs[sheetid] = false
		updaterules(self)
	else
		local quote='%q'
		for i,id in ipairs(ids) do ids[i] = quote:format(id) end
		self.warn(("Cannot disable() CSS with id '%s' (no such sheet loaded).\nAvailable sheet ids: %s"):format(sheetid, table.concat(ids, ", ")))
	end
end

function ZSS:enable(sheetid)

	if self._rules[sheetid] then
		self._docs[sheetid] = true
		updaterules(self)
	elseif self._docs[sheetid]~=nil then
		-- wipe out a local override that may have been disabling an ancestor
		self._docs[sheetid] = nil
		updaterules(self)
	else
		local disabled = {}
		local quote='%q'
		for id,state in pairs(self._docs) do
			if state==false then table.insert(disabled, quote:format(id)) end
		end
		if #disabled==0 then
			self.warn(("Cannot enable() CSS with id '%s' (no sheets are disabled)."):format(sheetid))
		else
			self.warn(("Cannot enable() CSS with id '%s' (no such sheet disabled).\nDisabled ids: %s"):format(sheetid, table.concat(disabled, ", ")))
		end
	end
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