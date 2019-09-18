--[=========================================================================[
   ZSS v1.0.1
   See http://github.com/Phrogz/ZSS for usage documentation.
   Licensed under MIT License.
   See https://opensource.org/licenses/MIT for details.
--]=========================================================================]

local ZSS = { VERSION="1.0.1", debug=print, info=print, warn=print, error=print, ANY_VALUE={}, NIL_VALUE={} }

local updaterules, updateconstantschain, dirtyblocks

-- ZSS:new{
--   constants  = { none=false, transparent=processColor(0,0,0,0), color=processColor },
--   directives = { ['font-face']=processFontFaceRule },
--   basecss    = [[...css code...]],
--   files      = { 'a.css', 'b.css' },
-- }
function ZSS:new(opts)
	local style = {
		_directives  = {}, -- map from name of at rule (without @) to function to invoke
		_constants   = {}, -- value literal strings mapped to equivalent values (e.g. "none"=false)
		_sheets      = {}, -- array of sheetids, also mapping sheetid to its active state
		_sheetconst  = {}, -- map of sheetid to table of constants for that sheet
		_sheetblocks = {}, -- map of sheetid to table of blocks underlying the constants
		_envs        = {}, -- map of sheetid to table that mutates to evaluate functions
		_rules       = {}, -- map of sheetids to array of rule tables, each sorted by document order
		_lookup      = {}, -- rules for active sheets indexed by type, then by id (with 'false' indicating no type or id)
		_kids        = setmetatable({},{__mode='k'}), -- set of child tables mapped to true
		_parent      = nil, -- reference to the style instance that spawned this one
	}
	style._envs[1] = setmetatable({},{__index=style._constants})
	setmetatable(style,{__index=self})
	style:directives{
		-- Process @vars { foo:42 } with sheet ordering and chaining
		vars = function(self, values, sheetid, blocks)
			local consts = self._sheetconst[sheetid]
			local blocksforthissheet = self._sheetblocks[sheetid]
			if not blocksforthissheet then
				blocksforthissheet = {}
				self._sheetblocks[sheetid] = blocksforthissheet
			end
			-- iterate over blocks instead of values, in case a value is nil
			for k,v in pairs(blocks) do
				consts[k] = values[k]
				blocksforthissheet[k] = blocks[k]
			end
		end
	}

	if opts then
		if opts.constants  then style:constants(opts.constants,true) end
		if opts.directives then style:directives(opts.directives)    end
		if opts.basecss    then style:add(opts.basecss, 'basecss')   end
		if opts.files      then style:load(table.unpack(opts.files)) end
	end

	updaterules(style)
	return style
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

-- Usage: myZSS:constants{ none=false, transparent=color(0,0,0,0), rgba=color.makeRGBA }
function ZSS:constants(valuemap, preserveCaches)
	for k,v in pairs(valuemap) do self._constants[k]=v end
	if not preserveCaches then dirtyblocks(self) end
	return self
end

function ZSS:directives(handlermap)
	for k,v in pairs(handlermap) do self._directives[k]=v end
	return self
end

-- Turn Lua code into function blocks that return the value
function ZSS:compile(str, sheetid, property)
	local dynamic = str:find('@[%a_][%w_]*') or str:find('^!')
	local env = self._envs[sheetid] or self._envs[1]
	local func,err = load('return '..str:gsub('@([%a_][%w_]*)','_data_.%1'):gsub('^!',''), str, 't', env)
	if not func then
		self.error(("Error compiling CSS expression for '%s' in '%s': %s"):format(property, sheetid, err))
	else
		-- [1] will hold the actual cached value (deferred until the first request)
		-- [2] is whether or not a cached value exists in [1] (needed in case the computed value is nil)
		-- [3] is the environment of the function (cached for convenient lookup)
		-- [4] is the function that produces the value
		-- [5] indicates if the block must be computed each time, or may be cached
		-- [6] is the sheetid (used for evaluation error messages)
		-- [7] is the name of the property being evaluated (used for evaluation error messages)
		return {nil,false,env,func,dynamic,sheetid,property,zssblock=true}
	end
end

-- Compute the value for a block
function ZSS:eval(block, data, ignorecache)
	if block[2] and not ignorecache then return block[1] end
	block[3]._data_ = data -- may be nil; important to clear out from previous eval
	local ok,valOrError = pcall(block[4])
	if ok then
		if not block[5] then
			block[2]=true
			block[1]=valOrError
		end
		return valOrError
	else
		self.error(("Error evaluating CSS value for '%s' in '%s': %s"):format(block[7], block[6], valOrError))
	end
end

-- Convert a selector string into its component pieces;
function ZSS:parse_selector(selector_str, sheetid)
	local selector = {
		type = selector_str:match('^@?[%a_][%w_-]*') or false,
		id  = selector_str:match('#([%a_][%w_-]*)') or false,
		tags={}, data={}
	}
	local tagrank = 0

	-- Find all the tags
	for name in selector_str:gmatch('%.([%a_][%w_-]*)') do
		selector.tags[name] = true
		tagrank = tagrank + 1
	end

	-- Find all attribute sections, e.g. [@attr], [@attr<17], [attr=12], …
	for attr in selector_str:gmatch('%[%s*(.-)%s*%]') do
		local attr_name_only = attr:match('^@?([%a_][%w_-]*)$')
		if attr_name_only then
			selector.data[attr_name_only] = ZSS.ANY_VALUE
			tagrank = tagrank + 1
		else
			local name, op, val = attr:match('^@([%a_][%w_-]*)%s*(==)%s*(.-)$')
			if name then
				local value = self:eval(self:compile(val, sheetid, selector_str))
				selector.data[name] = value==nil and ZSS.NIL_VALUE or value
			else
				selector.data[attr] = self:compile(attr, sheetid, selector_str)
			end
			-- attribute selectors with comparisons count slightly more than bare attributes or tags
			tagrank = tagrank + 1.001
		end
	end

	selector.rank = {
		selector.id and 1 or 0,
		tagrank,
		selector.type and 1 or 0,
		0 -- the document order will be determined during updaterules()
	}

	return selector
end

-- Add a block of raw CSS rules (as a single string) to the style sheet
-- Returns the sheet itself (for chaining) and id associated with the css (for later enable/disable)
function ZSS:add(css, sheetid)
	sheetid = sheetid or 'css#'..(#self:sheetids()+1)

	local newsheet = not self._rules[sheetid]
	if newsheet then
		table.insert(self._sheets, sheetid)
		self._sheets[sheetid] = true
		self._sheetconst[sheetid] = setmetatable({},{__index=self._constants})
		self._envs[sheetid] = setmetatable({},{__index=self._sheetconst[sheetid]})
		-- inherit from the last active sheet in the chain
		for i=#self._sheets-1,1,-1 do
			if self._sheets[self._sheets[i]] then
				getmetatable(self._sheetconst[sheetid]).__index = self._sheetconst[self._sheets[i]]
				break
			end
		end
	end
	self._rules[sheetid] = {}

	for rule_str in css:gsub('/%*.-%*/',''):gmatch('[^%s][^{]+%b{}') do
		-- Convert declarations into a table mapping property to block
		local decl_str = rule_str:match('[^{]*(%b{})'):sub(2,-2)
		local blocks = {}
		for key,val in decl_str:gmatch('([^%s:;]+)%s*:%s*([^;]+)') do
			blocks[key] = self:compile(val, sheetid, key)
		end

		-- Create a unique rule for each selector in the rule
		local selectors_str = rule_str:match('(.-)%s*{')
		for selector_str in selectors_str:gmatch('%s*([^,]+)') do
			-- Check if this is a directive (at-rule) that needs processing
			local name = selector_str:match('^%s*@([%a_][%w_-]*)%s*$')
			if name and self._directives[name] then
				-- bake value blocks into values before handing off
				local values = {}
				for k,block in pairs(blocks) do values[k] = self:eval(block) end
				self._directives[name](self, values, sheetid, blocks)
			end

			local selector = self:parse_selector(selector_str:match "^%s*(.-)%s*$", sheetid)
			if selector then
				local rule = {selector=selector, declarations=blocks, doc=sheetid, selectorstr=selector_str}
				table.insert(self._rules[sheetid], rule)
			end
		end
	end

	-- sort rules and determine active based on rank
	if not self._deferupdate then updaterules(self) end

	return self, sheetid
end

-- Given an element table, compute the declaration(s) that apply. For example:
-- local values = myZSS:match{tags={ped=1}}
-- local values = myZSS:match{type='text', id='accel', tags={label=1}}
-- local values = myZSS:match{type='text', id='accel', tags={value=1, negative=1}, value=-0.3}
function ZSS:match(el)
	local placeholders, data

	local result, sortedrules, ct = {}, {}, 0

	local function checkrules(rules)
		for _,rule in ipairs(rules) do
			local sel = rule.selector
			for tag,_ in pairs(sel.tags) do
				-- TODO: handle anti-tags in the selector, where _==false
				if not (el.tags and el.tags[tag]) then goto skiprule end
			end
			for name,desired in pairs(sel.data) do
				if type(desired)=='table' and desired.zssblock then
					if not self:eval(desired, el, true) then goto skiprule end
				else
					local actual = el[name]
					if desired==ZSS.NIL_VALUE then
						if actual~=nil then goto skiprule end
					elseif desired==ZSS.ANY_VALUE then
						if actual==nil then goto skiprule end
					else
						if actual~=desired then goto skiprule end
					end
				end
			end
			ct = ct + 1
			sortedrules[ct] = rule
			::skiprule::
		end
	end

	local function addfortype(byid)
		if el.id and byid[el.id] then addforid(byid[el.id]) end
		if byid[false] then addforid(byid[false]) end
	end

	-- check rules that specify this element's type
	local byid = el.type and self._lookup[el.type]
	if byid then
		-- check rules that specify this element's id
		if el.id and byid[el.id] then checkrules(byid[el.id]) end

		-- check rules that don't care about the element id
		if byid[false] then checkrules(byid[false]) end
	end

	-- check rules that don't care about the element type
	local byid = self._lookup[false]
	if byid then
		-- check rules that specify this element's id
		if el.id and byid[el.id] then checkrules(byid[el.id]) end

		-- check rules that don't care about the element id
		if byid[false] then checkrules(byid[false]) end
	end

	if ct>1 then
		table.sort(sortedrules, function(r1, r2)
			r1,r2 = r1.selector.rank,r2.selector.rank
			if     r1[1]<r2[1] then return true elseif r1[1]>r2[1] then return false
			elseif r1[2]<r2[2] then return true elseif r1[2]>r2[2] then return false
			elseif r1[3]<r2[3] then return true elseif r1[3]>r2[3] then return false
			elseif r1[4]<r2[4] then return true else                    return false
			end
		end)
	end

	-- merge the declarations from the rules in order
	for _,rule in ipairs(sortedrules) do
		for k,block in pairs(rule.declarations) do
			result[k] = block
		end
	end

	-- Convert blocks to values (honoring cached values)
	for k,block in pairs(result) do
		result[k] = self:eval(block, el)
	end

	return result
end

function ZSS:extend(...)
	local kid = self:new()
	kid._parent = self
	-- getmetatable(kid).__index = self
	setmetatable(kid._constants, {__index=self._constants})
	setmetatable(kid._directives,{__index=self._directives})
	setmetatable(kid._envs,{__index=self._envs})
	self._kids[kid] = true
	kid:load(...)
	return kid
end

function ZSS:sheetids()
	local ids = self._parent and self._parent:sheetids() or {}
	table.move(self._sheets, 1, #self._sheets, #ids+1, ids)
	for _,id in ipairs(self._sheets) do ids[id] = true end
	return ids
end

function ZSS:disable(sheetid)
	local ids = self:sheetids()
	if ids[sheetid] then
		self._sheets[sheetid] = false
		updaterules(self)
		updateconstantschain(self)
		dirtyblocks(self,sheetid)
	else
		local quote='%q'
		for i,id in ipairs(ids) do ids[i] = quote:format(id) end
		self.warn(("Cannot disable() CSS with id '%s' (no such sheet loaded).\nAvailable sheet ids: %s"):format(sheetid, table.concat(ids, ", ")))
	end
end

function ZSS:enable(sheetid)
	if self._rules[sheetid] then
		self._sheets[sheetid] = true
		updaterules(self)
		updateconstantschain(self)
		dirtyblocks(self,sheetid)
	elseif self._sheets[sheetid]~=nil then
		-- wipe out a local override that may have been disabling an ancestor
		self._sheets[sheetid] = nil
		updaterules(self)
		updateconstantschain(self)
		dirtyblocks(self,sheetid)
	else
		local disabled = {}
		local quote='%q'
		for id,state in pairs(self._sheets) do
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
	-- reset the lookup cache
	self._lookup = {}
	local rulesadded = 0

	-- add all rules from the parent style
	if self._parent then
		for type,rulesfortype in pairs(self._parent._lookup) do
			local byid = self._lookup[type]
			if not byid then
				byid = {}
				self._lookup[type] = byid
			end
			for id,rulesforid in pairs(rulesfortype) do
				local rules = byid[id]
				if not rules then
					rules = {}
					byid[id] = rules
				end
				for i=1,#rulesforid do
					local rule = rulesforid[i]
					-- do not use rule if we set its document inactive
					if self._sheets[rule.doc]~=false then
						rules[#rules+1] = rule
						rulesadded = rulesadded + 1
					end
				end
			end
		end
	end

	-- add all the rules from this style's active sheets
	for _,sheetid in ipairs(self._sheets) do
		if self._sheets[sheetid] then
			for _,rule in ipairs(self._rules[sheetid]) do
				local byid = self._lookup[rule.selector.type]
				if not byid then
					byid = {}
					self._lookup[rule.selector.type] = byid
				end
				local rulesforid = byid[rule.selector.id]
				if not rulesforid then
					rulesforid = {}
					byid[rule.selector.id] = rulesforid
				end
				rulesforid[#rulesforid+1] = rule
				rulesadded = rulesadded + 1
				rule.selector.rank[4] = rulesadded
			end
		end
	end

	-- ensure that any extended children are updated
	for kid,_ in pairs(self._kids) do
		updaterules(kid)
	end
end

updateconstantschain = function(self)
	local lastactive = self._constants
	for _,sheetid in ipairs(self._sheets) do
		-- If the sheet is active, put it into the chain
		if self._sheets[sheetid] then
			local sheetconst = self._sheetconst[sheetid]
			getmetatable(sheetconst).__index = lastactive
			lastactive = sheetconst
		end
	end
end

dirtyblocks = function(self, sheetid)
	local dirtythissheet = not sheetid
	for _,id in ipairs(self._sheets) do
		if id==sheetid then dirtythissheet=true end
		if dirtythissheet then
			for _,rule in ipairs(self._rules[id]) do
				for k,block in pairs(rule.declarations) do block[2]=false end
			end
			if self._sheetblocks[id] then
				for k,block in pairs(self._sheetblocks[id]) do
					self._sheetconst[id][k] = self:eval(block,nil,true)
				end
			end
		end
	end
	for kid,_ in pairs(self._kids) do dirtyblocks(kid) end
end

return ZSS
