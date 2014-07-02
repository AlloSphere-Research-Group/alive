local table_remove = table.remove
local random = math.random
local min, max = math.min, math.max
local format = string.format

local E = require "expr"
local isexpr = E.isexpr
local eval = E.eval

-- a map of all tags:
local Tag = {}

-- a tag is a list (array) of objects
local tag = {}

setmetatable(Tag, {
	-- a new tag name:
	__index = function(self, name)
		local o = setmetatable({
			name = name,
			properties = {},
		}, tag)
		Tag[name] = o
		return o
	end,
	__call = function(self, name, t)
		assert(name and type(name)=="string")
		local o = Tag[name]
		if t then o:set(t) end
		return o
	end,
})

function tag:__tostring()
	return format("Tag(%s,%d)", self.name, #self)
end

function tag:add(o)
	-- assumes double-entry won't happen...
	rawset(self, #self+1, o)
	-- now apply all properties in tag to the agent:
	for k, v in pairs(rawget(self, "properties")) do
		if type(v) == "table" and not isexpr(v) then
			o:setproperty(k, unpack(v))
		else
			o:setproperty(k, v)
		end
	end
end

function tag:remove(o)
	for i = 1, #self do
		if self[i] == o then 
			table_remove(self, i)
			-- assumes no double-entries
			return
		end
	end
end

function tag:__newindex(k, v)
	rawget(self, "properties")[k] = v
	-- update any members:
	for i, a in ipairs(self) do
		-- coerce
		print(i, a, k, v)
		a[k](a, v)	-- setter
	end
end

function tag:set(t)
	-- zero the existing properties:
	rawset(self, "properties", {})
	for k, v in pairs(t) do self[k] = v end
end
tag.__call = tag.set

function tag:__index(k)
	return rawget(tag, k)
		or function(self, ...)
			if select("#", ...) > 1 then
				rawget(self, "properties")[k] = { ... }
			else
				rawget(self, "properties")[k] = ...
			end
			return self
		end
end

-- a query contains a tag (in the field 'base')
local q = {}

local empty_query = setmetatable({
	base = {},
}, q)

function q:size() return #rawget(self, "base") end

-- beep -> beep
-- "beep" -> Tag.beep
-- "~beep" -> all "*" minus "beep"
-- q(beep) -> q.base
local
function totag(o)
	if type(o) == "string" then
		if o:sub(1, 1) == "~" then
			local name = o:sub(2)
			-- exclusion:
			local all = Tag("*")
			local base = {}
			for i, v in ipairs(all) do
				if not v:hastag(name) then
					base[#base+1] = v
				end
			end
			return base
		end
		return Tag(o)
	elseif type(o) == "table" then
		if getmetatable(o) == q then
			return rawget(o, "base")
		else
			return o
		end
	else
		error("not a valid query subject")
	end
end

-- create a new query as the union of two or more queries
-- ensures no duplicates
local 
function union(...)
	local base, memo = {}, {}
	for i = 1, select("#", ...) do
		local b = select(i, ...)
		local bb = totag(b)
		for _, v in ipairs(bb) do
			if not memo[v] then
				memo[v] = true
				base[#base+1] = v
			end
		end
	end
	return setmetatable({
		base = base,
	}, q)
end

-- expose as a method too:
q.union = union
q.__add = union

local
function query(...)
	local base, more = ...
	if more then
		return union(...)
	else
		if base then
			base = totag(base)
			-- allow zero-length base queries, since
			-- this could refer to an object of varying size
			--if #base > 0 then
				return setmetatable({
					base = base,
				}, q)
			--end
		else
			-- assume all agents:
			return setmetatable({
				base = totag("*"),
			}, q)
		end
	end
	return empty_query
end

function q:__tostring()
	return format("query(%d)", #rawget(self, "base"))
end

-- set a property:
-- e.g. red:pick(0.5).foo = value | expr | func
function q:__newindex(k, value)
	local base = rawget(self, "base")
	for i, v in ipairs(base) do
		-- coerce
		print(i, v, k, value)
		v[k](v, value)	-- setter
	end
end

-- the the number of elements in the query:
function q:size()
	local base = rawget(self, "base")
	return #base
end

-- set multiple properties at once:
function q:attr(t)
	local base = rawget(self, "base")
	for i, v in ipairs(base) do
		for k, value in pairs(t) do
			v[k] = eval(value)
		end
	end
end

-- metatable for properties / methods:
local p = {}
function p:__tostring()
	return format("query[%s](%d)", rawget(self, "key"), #rawget(self, "base"))
end

function p:__call(o, ...)
	local parent = rawget(self, "query")
	local base = rawget(parent, "base")
	local key = rawget(self, "key")
	
	-- duplicate base to avoid errors inserting/removing while iterating 
	-- for e.g. :die(), :tag(), :untag() etc.
	-- not very efficient, but make it work first...
	local basecopy = { unpack(base) }
	
	for i, v in ipairs(basecopy) do
		local f = v[key]
		-- TODO: should args be coerced? or is that the property setter's job?
		if o == parent then
			--print("invoked as method call", parent, v, key, ...)
			-- method call
			f(v, ...)
		else
			--print("invoked as non-method call", parent, v, key, ...)
			f(o, ...)
		end
	end	
	-- return parent query to allow chaining:
	return parent
end

-- get a property / method:
function q:__index(k)
	return rawget(q, k)
		or setmetatable({
			query = self,
			base = rawget(self, "base"),
			key = k,
		}, p)
end

-- sub-selections
function q:first()
	local base = rawget(self, "base")
	if #base == 0 then return empty_query end
	return query{ base[1] }
end
function q:last()
	local base = rawget(self, "base")
	if #base == 0 then return empty_query end
	return query{ base[#base] }
end

-- sub-selects only the odd-numbered items:
function q:odd()
	local base = rawget(self, "base")
	if #base == 0 then return empty_query end
	local list = {}
	for i = 1, #base, 2 do
		list[#list+1] = base[i]
	end
	return query(list)
end

-- sub-selects only the even-numbered items:
function q:even()
	local base = rawget(self, "base")
	if #base == 0 then return empty_query end
	local list = {}
	for i = 2, #base, 2 do
		list[#list+1] = base[i]
	end
	return query(list)
end

-- sub-selects random items
-- if n == nil, it returns one item
-- if n < 1, it is interpreted as a probability
-- else it returns n items (or less if there are less to pick from)
function q:pick(n)
	local base = rawget(self, "base")
	if #base == 0 then return empty_query end
	if n then
		if n < 1 then
			-- pick with a probability:
			local list = {}
			for i = 1, #base do
				if random() < n then
					list[#list+1] = base[i]
				end
			end
			return query(list)
		else
			-- pick n items:
			-- (not more than what exist)
			n = min(#base, n)
			-- (don't pick the same one multiple times)
			local bag = { unpack(base) }
			local list = {}
			for i = 1, n do
				list[i] = table_remove(bag, random(#bag))
			end
			return query(list)
		end
	else
		-- just pick one item:
		return query{ base[random(#base)] }
	end
end

-- sub-selects only if the object in question has a certain property name
-- value is optional, will also require equal property value
function q:has(key, value)
	local base = rawget(self, "base")
	if #base == 0 then return empty_query end
	local list = {}
	for i, v in ipairs(base) do
		if v.key ~= nil then
			if value then
				-- checking property value:
				if v.key == eval(value) then
					list[#list+1] = v
				end
			else
				-- just checking property existence:
				list[#list+1] = v
			end
		end
	end
	return query(list)
end

function q:set(t)
	for k, v in pairs(t) do
		print("set", k, v)
		self[k] = v
	end
end	



return setmetatable({
	Tag = Tag,
}, {
	__call = function(_, ...) return query(...) end,
})