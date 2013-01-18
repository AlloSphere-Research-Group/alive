local av = require "av"
local vec = require "vec"
local query = require "query"
local Tag = query.Tag
local notify = require "notify"
local notify_register = notify.register
local notify_unregister = notify.unregister
local E = require "expr"
local eval = E.eval
local isexpr = E.isexpr
local app = av.app

local ffi = require "ffi"
local C = ffi.C

local format = string.format
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

--[[#Agent - Objects
An autonomous entity roaming a virtual world.

## Example Usage ##
`a = Agent('green')  
a:color(1,0,0)  
a:moveTo(0,0,-4)`
--]]

function Agent:__tostring()
	return format("Agent(%d)", self.id)
end

function Agent:setproperty(k, ...)
	--print("setproperty", self, k, ...)
	-- TODO: verify k is a property, coerce, etc. etc.
	local f = self[k]
	if f and type(f) == "function" then
		f(self, ...)
	end
	return self
end

local object_propertynames = {
	enable = true,
	nearest = true,
	nearest_distance = true,
	velocity = true,
	position = true,
	color = true,
	scale = true,
	turn = true,
	ux = true,
	uy = true,
	uz = true,
}

local voice_propertynames = {
	freq = true,
	amp = true,
}

--[[###Agent.get : method
**param** *name*: String. Get the value of a named property in the agent
**description**: Valid names include: enable, position, scale, color, velocity, turn, ux, uy, uz, nearest, nearest_distance, amp, freq
--]]
function Agent:get(name)
	if object_propertynames[name] then
		return self._object[name]
	elseif voice_propertynames[name] then
		return self._voice[name]
	else
		return self[name]
	end
end

--[[###Agent.amp : method
**param** *amplitude*: Number. The ampltiude of the agent's sonificaiton ranging from 0..1
--]]

function Agent:hastag(name)
	return self._tags[name]
end

--[[###Agent.nearest : method
**description**: Returns nearest agent and distance. If no agent is near, returns nil
--]]
function Agent:nearest()
	local n = self._object.nearest
	if self._object.id ~= n then
		return Agent.agents[n], self._object.nearest_distance
	end
end

--[[###Agent.tag : method
**param** *tags*: List. A comma-separated list of tags to assign to the agent
--]]
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

--[[###Agent.untag : method
**param** *tags*: List. A comma-separated list of tags to remove from the agent
--]]
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

--[[###Agent.enable : method
**param** *shouldEnable*: Boolean. This method stops (or starts) an agent from computing its values
--]]
function Agent:enable(b)
	if b == false or b == 0 then
		self._object.enable = 0
	else
		self._object.enable = 1
	end
	return self
end

--[[###Agent.halt : method
**param** *shouldEnable*: Boolean. This method stops (or starts) an agent moving. Sound and other properties are still computed.
--]]
function Agent:halt()
	self._object.velocity = 0
	self._object.turn:set(0, 0, 0)
	return self
end

--[[###Agent.home : method
**description** : Move an agent to the 0,0,0 location
--]]

function Agent:home()
	self._object.position:set(0, 0, 0)
	return self
end

--[[###Agent.move : method
**description** : Set the velocity for the agent to move at. The vector the agent is determined by the turn method.  
**param** *velocity*: Number. The movement velocity for the agent.
--]]
function Agent:move(z)
	self._object.velocity = eval(z)
	return self
end

--[[###Agent.nudge : method
**description** : Add an instantaneous force to the agent velocity.  
**param** *acceleration*: Number. The amount of instantaneous velocity to add.
--]]
function Agent:nudge(z)
	self._object.acceleration = eval(z)
	return self
end

--[[###Agent.moveTo : method
**description** : Move an agent to a given location  
**param** *x*: Number. x coordinate ranging from -24..24  
**param** *y*: Number. y coordinate ranging from -24..24  
**param** *z*: Number. z coordinate ranging from -24..24  
--]]
function Agent:moveTo(x,y,z)
	if type(x) == "table" and not isexpr(x) then x, y, z = unpack(x) end
	self._object.position:set(eval(x), eval(y), eval(z))
	return self
end

--[[###Agent.color : method
**description** : Change the color of an agent  
**param** *red*: Number. The red channel value ranging from 0..1  
**param** *green*: Number. The green channel value ranging from 0..1  
**param** *blue*: Number. The blue channel value ranging from 0..1
--]]
function Agent:color(r, g, b)
	print(r, g, b)
	if type(r) == "table" and not isexpr(r) then r, g, b = unpack(r) end
	self._object.color.r = eval(r)
	self._object.color.g = eval(g)
	self._object.color.b = eval(b)
end

--[[###Agent.scale : method
**description** : Change the size of an agent
**param** *x*: Number.   
**param** *y*: Number. 
**param** *z*: Number. 
--]]
function Agent:scale(x, y, z)
	if type(x) == "table" and not isexpr(x) then x, y, z = unpack(x) end
	self._object.scale:set(eval(x), eval(y), eval(z))
end

--[[###Agent.twist : method
**description** : Add an instantaneous rotation (angluar acceleration) 
**param** *azimuth*: Number. Rotation around agent's Y axis
**param** *elevation*: Number. Rotation around agent's X axis 
**param** *bank*: Number. Rotation around agent's Z axis
--]]
function Agent:twist(a, e, b)
	if type(a) == "table" and not isexpr(a) then a, e, b = unpack(a) end
	--print("turn", self, a, e, b)
	self._object.twist:set(eval(e), eval(a), eval(b))
	return self
end

--[[###Agent.turn : method
**description** : Set angluar velocity
**param** *azimuth*: Number. Rotation around agent's Y axis
**param** *elevation*: Number. Rotation around agent's X axis 
**param** *bank*: Number. Rotation around agent's Z axis
--]]
function Agent:turn(a, e, b)
	if type(a) == "table" and not isexpr(a) then a, e, b = unpack(a) end
	--print("turn", self, a, e, b)
	self._object.turn:set(eval(e), eval(a), eval(b))
	return self
end

-- audio properties:
--[[###Agent.amp : method
**param** *amplitude*: Number. The ampltiude of the agent's sonificaiton ranging from 0..22050
--]]
function Agent:freq(f)
	self._voice.freq = eval(f)
	return self
end

--[[###Agent.amp : method
**param** *amplitude*: Number. The ampltiude of the agent's sonificaiton ranging from 0..1
--]]
function Agent:amp(f)
	self._voice.amp = eval(f)
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

--[[###Agent.die : method
**description** : kill the agent
--]]
function Agent:die()
	self:enable(0)
	self:reset()
	Agent.pool[#Agent.pool+1] = self.id
end

--[[###Agent.reset : method
**description** : unregister notifications and remove all tags from agent
--]]
function Agent:reset()
	C.agent_reset(self._object)
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

--[[###Agent.on : method
**description** : assign an event handler for a particular event  
**param** *eventName*: String. The name of the event to handle  
**param** *handler*: Function. The function to call when the event occurs
--]]
function Agent:on(event, handler)
	-- 1. store the handler for this event
	self._handlers[event] = handler
	-- 2. register for notification of this event
	notify_register(event, self)
end

setmetatable(Agent, {
	__tostring = function(self)
		return format("Agent(%d)", self.id)
	end,
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
		end
		-- reset this agent:
		self.agents[id]:reset()
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
		_object = app.shared.agents[i],
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
	-- this is where all the per-agent processes would be simulated
	
end

go(function()
	while true do
		local dt = wait("update")
		for i = 0, av.MAX_AGENTS-1 do
			local a = Agent.agents[i]
			if a and a._object.enable ~= 0 then
				-- run the per-agent update:
				a:update(dt)
				
				-- check for collisions:
				local obj = a._object
				local n = obj.nearest
				local d = obj.nearest_distance
				if i ~= n and d < 1 then
					local with = Agent.agents[n]
					a:notify("collide", with, d)
				end
			end
		end
	end
end)

return {
	Agent = Agent,
	Tag = Tag,
}