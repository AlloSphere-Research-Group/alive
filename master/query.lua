local table_remove = table.remove
local random = math.random
local min, max = math.min, math.max
local format = string.format

local E = require "expr"
local isexpr = E.isexpr
local eval = E.eval



-- query examples:
--[[

red = q("red")		-- a basic query object

-- filters:
:pick()
:odd()
:first, :last, :has, etc...

__newindex:
red:pick(0.5).foo = value | expr | func
	for i, v ...
		v.foo = ...

__index + __call:
red:pick(0.5):method(value | expr | func)
	

red:pick(0.5):attr{ k, v pairs }

agent = red:spawn()
	Agent("red") ...

--]]


local q = {}

function q:size() 
	return #self 
end

function query(base)
	if base and type(base) == "table" then
		return setmetatable({
			base = base,
		}, q)
	else
		return empty_query
	end
end

local empty_query = query{}

function q:__tostring()
	return format("query(%d)", #rawget(self, "base"))
end

-- set a property:
-- e.g. red:pick(0.5).foo = value | expr | func
function q:__newindex(k, value)
	local base = rawget(self, "base")
	for i, v in ipairs(base) do
		-- coerce
		v[k] = eval(value)
	end
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
	for i, v in ipairs(base) do
		-- TODO: should args be coerced? or is that the property setter's job?
		if o == parent then
			-- method call
			v[key](v, ...)
		else
			v[key](o, ...)
		end
	end	
	-- return parent query to allow chaining:
	return parent
end

-- get a property / method:
function q:__index(k)
	local meta = rawget(q, k)
	if meta then 
		return meta 
	else
		local base = rawget(self, "base")
		return setmetatable({
			query = self,
			base = base,
			key = k,
		}, p)
	end
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

return query