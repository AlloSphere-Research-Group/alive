local av = require "av"
local vec = require "vec"
local query = require "query"
local Tag = query.Tag
local notify = require "notify"
local notify_register = notify.register
local notify_unregister = notify.unregister
local E = require "expr"
local eval = E.eval
local app = av.app

local sin, cos = math.sin,math.cos
local abs, floor = math.abs, math.floor
local table_remove = table.remove
local random = math.random
local srandom = function() return random() * 2 - 1 end

local Agent = {
	agents = {},
	pool = {},
}
Agent.__index = Agent

function Agent:tag(...)
	local name, more = ...
	-- skip if already inserted?
	if not self._tags[name] then
		-- add to set:
		local tag = Tag(name)
		tag:add(self)
		-- note to self:
		self._tags[name] = tag
	end
	-- curry
	if more then
		self:tag(select(2, ...))
	end
end

function Agent:untag(...)
	local name, more = ...
	local tag = self._tags[name]
	-- skip if already removed:
	if tag then 
		-- remove from tag:
		tag:remove(self)
		-- clear from self:
		self._tags[name] = nil
	end
	-- curry
	if more then
		self:tag(select(2, ...))
	end
end

function Agent:enable(b)
	if b == false or b == 0 then
		self._object.enable = 0
	else
		self._object.enable = 1
	end
	return self
end

function Agent:halt()
	self._object.velocity = 0
	self._object.turn:set(0, 0, 0)
	return self
end

function Agent:home()
	self._object.position:set(0, 0, 0)
	return self
end

function Agent:move(z)
	self._object.velocity = eval(z)
	return self
end

function Agent:color(r, g, b)
	self._object.color.r = eval(r)
	self._object.color.g = eval(g)
	self._object.color.b = eval(b)
end

function Agent:turn(a, e, b)
	self._object.turn:set(eval(e), eval(a), eval(b))
	return self
end

-- audio properties:
function Agent:freq(f)
	self._voice.freq = eval(f)
	return self
end

function Agent:notify(k, ...)
	local handler = self._handlers[k]
	if handler then
		handler(self, k, ...)
	else
		-- if this happens, probably shoudl unregister it:
		notify_unregister(k, self)
	end
end

function Agent:die()
	self.enable = 0
	self:reset()
	Agent.pool[#Agent.pool+1] = self.id
end

function Agent:reset()
	-- unregister notifications:
	for k in pairs(self._handlers) do
		notify_unregister(k, self)
		self._handlers[k] = nil
	end
	-- remove from tags:
	for name, tag in pairs(self._tags) do
		-- remove from tag:
		tag:remove(self)
		-- clear from self:
		self._tags[name] = nil
	end
end

function Agent:on(event, handler)
	-- 1. store the handler for this event
	self._handlers[event] = handler
	-- 2. register for notification of this event
	notify_register(event, self)
end

setmetatable(Agent, {
	__call = function(self, ...)
		-- grab an agent (stealing if necessary)
		local id = table_remove(self.pool)
		local agent
		if id then 
			agent = self.agents[id]
		else
			-- steal active agent if necessary:
			id = random(av.MAX_AGENTS-1) 
			agent = self.agents[id]
			-- reset this agent:
			self.agents[id]:reset()
			
		end
		agent:enable()
		agent:tag("*", ...)
		-- return agent:
		return agent
	end,
})

-- initialize:
for i = 0, av.MAX_AGENTS-1 do
	local o = {
		id = i,
		_object = app.agents[i],
		_voice = app.voices[i],
		
		_handlers = {},
		_tags = {},
	}
	-- store in all-agent list:
	Agent.agents[i] = setmetatable(o, Agent)
	-- add ID to pool:
	Agent.pool[i] = i
end

function Agent:update(dt)
	--print("update", self, dt)
	
	-- this is where all the per-agent processes would be invoked.
	
end

go(function()
	while true do
		local dt = wait("update")
		for i = 0, av.MAX_AGENTS-1 do
			local a = Agent.agents[i]
			if a and a._object.enable ~= 0 then
				-- run the per-agent update:
				a:update(dt)
			end
		end
	end
end)

return {
	Agent = Agent,
	Tag = Tag,
}