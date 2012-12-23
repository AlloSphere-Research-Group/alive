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

function Agent:die()
	self.enable = 0
	Agent.pool[#Agent.pool+1] = self.id
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
	}
	-- store in all-agent list:
	Agent.agents[i] = setmetatable(o, Agent)
	-- add ID to pool:
	Agent.pool[i] = i
end

--------------------------------------------------------------------------------
-- DEMO
--------------------------------------------------------------------------------


local a = Agent()
print(a)
a:enable()
a:halt()
a:home()
a:move(0.5)
a:turn(0.5, 0, 0)
a:freq(110)

for i = 1, 150 do
	local b = Agent()
	b:home()
	b:enable()
	b:move(random()*4)
	b:turn(srandom(), 0, 0)
	b:freq(random() + 55 * random(10))
end
print("ok")