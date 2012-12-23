print("starting main2.lua")

local av = require "av"
local vec = require "vec"
local ev = require "ev"
local app = av.app

math.randomseed(os.time())

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
	self._object.velocity = z
	return self
end

function Agent:turn(a, e, b)
	self._object.turn:set(e, a, b)
	return self
end

-- audio properties:
function Agent:freq(f)
	self._voice.freq = f
	return self
end


local events = {}
local
function register(k, v)
	-- get or create map:
	local e = events[k]
	if not e then 
		e = {} 
		events[k] = e
	end
	-- add to map:
	e[v] = true
end

local 
function unregister(k, v)
	local e = events[k]
	e[v] = nil
end

local 
function trigger(k, ...)
	local e = events[k]
	if e then
		for o in pairs(e) do
			o:notify(k, ...)
		end
	end
end

function Agent:notify(k, ...)
	local handler = self._handlers[k]
	if handler then
		handler(self, k, ...)
	else
		-- if this happens, probably shoudl unregister it:
		unregister(k, self)
	end
end

function Agent:die()
	self.enable = 0
	-- unregister notifications:
	for k in pairs(self._handlers) do
		unregister(k, self)
		self._handlers[k] = nil
	end
	Agent.pool[#Agent.pool+1] = self.id
end


function Agent:on(event, handler)
	-- 1. store the handler for this event
	self._handlers[event] = handler
	-- 2. register for notification of this event
	register(event, self)
end

setmetatable(Agent, {
	__call = function(self)
		-- grab an agent (stealing if necessary)
		local id = table_remove(self.pool)
		-- steal active agent if necessary:
		if not id then id = random(av.MAX_AGENTS-1) end
		-- return agent:
		return self.agents[id]
	end,
})

-- initialize:
for i = 0, av.MAX_AGENTS-1 do
	local o = {
		id = i,
		_object = app.agents[i],
		_voice = app.voices[i],
		
		_handlers = {},
	}
	-- store in all-agent list:
	Agent.agents[i] = setmetatable(o, Agent)
	-- add ID to pool:
	Agent.pool[i] = i
end

--------------------------------------------------------------------------------
-- DEMO
--------------------------------------------------------------------------------


go(function()
	while true do
		trigger("beat")
		wait(0.5)
	end
end)


go(function()
	while true do
		local b = Agent()
		b:enable()
		b:freq(random() + 55 * random(10))
		
		-- insert a beat-based handler:
		b:on("beat", function()
			b:turn(srandom()*3, srandom()*3, srandom()*3)
			b:move(random()*10*random()*10)
		end)
		
		wait(1)
	end
end)



print("ok")