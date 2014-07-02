#!/usr/bin/env luajit
local ffi = require "ffi"
local av = require "av"
local world = require "world"
local expr = require "expr"
expr:globalize()

local table_remove = table.remove
local random = math.random
local min, max = math.min, math.max
local format = string.format

shared = world.app_get()
----------------------------------------------------------------------------------------

local tag = {}

local function newtag(s, attrs)
	local t = setmetatable({
		_name = s,
		_agents = {},
		_attrs = attrs or {},
	}, tag)
	return t
end

function tag_add(self, a)
	if not self._agents[a] then
		self._agents[a] = true
		self._agents[#self._agents + 1] = a
	end
	return self
end

function tag_remove(self, a)
	if self._agents[a] then
		self._agents[a] = nil
		for i, v in ipairs(self._agents) do
			if v == a then
				table.remove(self._agents, i)
				break
			end
		end
	end
	return self
end

function tag_set(self, attrs)
	for k, v in pairs(attrs) do
		self[k] = v
	end
end

function tag:__index(k)
	return self._attrs[k]
end

function tag:__newindex(k, v)
	self._attrs[k] = v
	-- apply to all members:
	for i, a in ipairs(self._agents) do
		a[k] = v
	end
	return self
end

local Tag_mt = {}

function Tag_mt:__index(s)
	local t = rawget(self, s)
	if not t then
		-- create a new tag:
		t = newtag(s)
		rawset(self, s, t)
	end
	return t
end	

function Tag_mt:__newindex(s, def)
	local t = rawget(self, s)
	if t then
		-- apply def to t._attrs
		tag_set(t, def)
	else
		-- create a new tag:
		t = newtag(s, def)
		rawset(self, s, t)
	end
	return t
end	

-- Tag("foo") or Tag("foo", def)
function Tag_mt:__call(s, def)
	Tag[s] = def
end

Tag = setmetatable({}, Tag_mt)

local function hastag(a, name)
	return Tag[name][a]
end

local agent = {}
agent.__index = agent

local agents = {}

function agent:tag(s, more, ...)
	tag_add(Tag[s], self)
	if more then self:tag(more, ...) end
	return self
end

function agent:untag(s, more, ...)
	tag_remove(Tag[s], self)
	if more then self:untag(more, ...) end
	return self
end

function Agent(tag, ...)
	-- TODO: id & voice stealing
	local self = setmetatable({
		-- TODO: link to C lib
	}, agent)
	agents[self] = true
	return self	
end

local query = {}
query.__index = query

function query:__tostring()
	return format("query(%d)", #self)
end

-- beep -> beep
-- "beep" -> tags.beep
-- "~beep" -> all "*" minus "beep"
-- q(beep) -> q.base
local
function totag(o)
	if type(o) == "string" then
		if o:sub(1, 1) == "~" then
			local name = o:sub(2)
			-- exclusion:
			local all = agents
			local exclusion = {}
			for i, v in ipairs(all) do
				if not hastag(v, name) then
					exclusion[#exclusion+1] = v
				end
			end
			return exclusion
		end
		return Tag[o]
	elseif type(o) == "table" then
		return o
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
	return setmetatable(base, query)
end

-- expose as a method too:
query.union = union
query.__add = union

function query_new(list)
	local self = setmetatable({}, query)
	self:add(list)
	return self
end

function query:add(list)
	for i, a in ipairs(list) do
		self[#self+1] = a
	end
	return self
end

function query:tag(s, more, ...)
	-- maybe allow other types than Tag?
	self:add(Tag[s])
	if more then self:tag(more, ...) end
	return self
end

function query:last()
	return query_new{ self[#self] }
end

function query:first()
	return query_new{ self[1] }
end

function query:odd()
	local list = {}
	for i = 1, #self, 2 do
		list[#list+1] = self[i]
	end
	return query_new(list)
end

function query:even()
	local list = {}
	for i = 2, #self, 2 do
		list[#list+1] = self[i]
	end
	return query_new(list)
end

-- sub-selects random items
-- if n == nil, it returns one item
-- if n < 1, it is interpreted as a probability
-- else it returns n items (or less if there are less to pick from)
function query:pick(n)
	if n then
		if n < 1 then
			-- pick with a probability:
			local list = {}
			for i = 1, #self do
				if random() < n then
					list[#list+1] = self[i]
				end
			end
			return query_new(list)
		else
			-- pick n items:
			-- (not more than what exist)
			n = max(1, min(#self, n))
			-- (don't pick the same one multiple times)
			local bag = { unpack(self) }
			local list = {}
			for i = 1, n do
				list[i] = table_remove(bag, random(#bag))
			end
			return query_new(list)
		end
	else
		-- just pick one item:
		return query_new{ self[random(#self)] }
	end
end

function query:has(k)
	local list = {}
	for i, a in ipairs(self) do
		if a[k] ~= nil then
			list[#list+1] = a
		end
	end
	return query_new(list)
end

function query:__newindex(k, v)
	-- apply property to all members:
	for i, a in ipairs(self) do
		a[k] = v
	end
	return self
end

--function query:__index(k)

function query:die() for i, a in ipairs(self) do a:die() end end
function query:halt() for i, a in ipairs(self) do a:halt() end end

function Q(s, ...)
	local base, more = ...
	if more then
		return union(...)
	elseif base then
		base = totag(base)
		return setmetatable({}, query):add(base)
	else
		return setmetatable({}, query):add(agents)
	end
end



----------------------------------------------------------------------------------------
-- create an agent associated with two tags:
a = Agent("foo", "bar")
-- modify the foo tag (and thus all "foo" agents):
Tag.foo.amp = 0.5
-- modify the tags the agent associates with:
a:untag("bar")
a:tag("baz")

-- set "amp" of the most recent foo-tagged agent:
Q("foo"):last().amp = 0.3
-- terminate all agents with a "chorus" property:
Q():has("chorus"):die()
-- set the frequency of about 50% of all agents:
Q():pick(0.5).freq = 200
-- set "freq" of four random "spin" agents:
Q("spin"):pick(4).freq = 500
-- stop one randomly chosen agent from moving:
Q():pick():halt()

print(Random(10) + 1)

-- construct an expression:
e = (Max(Random(10), Random(10)) + 2) * 100
-- assign to "mod" for all agents tagged "foo"
-- (each receives distinct evaluations of Random)
Q("foo").mod = e

--------------------------------------------------------------------------------------

print("simulator is running")
world.av_audio_start()
av.run()