-- tags stores table of all tag names
local tags = {}
-- map of agents to tag names:
local agenttags = {}

-- each tag contains a list (array or hash?) of the nodes (agents) it refers to
-- probably also want a map of agents to tag names

function tag(agent, name)
	local ats = agenttags[agent]
	if not ats then
		ats = {}
		agenttags[agent] = ats
	end
	-- tags stored as both list (for order) and hash (for existence tests)
	-- check to avoid duplicate entries
	if not ats[name] then
		-- add tag to agent:
		ats[name] = true
		ats[#ats+1] = name
		-- also add agent to tag:
		local as = tags[name]
		-- lazy create:
		if not as then
			as = {}
			tags[name] = as
		end
		as[#as+1] = agent
		-- should the tag behaviors be applied here?
	end
	return agent
end

-- really this should return a 'collection' object
-- upon which operations can be delivered (messages)
function pick(name)
	local as = tags[name]
	if as then
		local count = #as
		if count > 0 then
			-- pick a random one:
			return as[math.random(count)]
		end
		-- else tag is empty
	end
	-- else tag does not exist
end

-----------------------------

local av = require "av"
local vec = require "vec"
local ev = require "ev"
local app = av.app

local sin, cos = math.sin,math.cos
local abs, floor = math.abs, math.floor
local random = math.random
local srandom = function() return random() * 2 - 1 end

-- initialize agents in some particular way:
for i = 0, av.MAX_AGENTS-1 do
	local a = app.agents[i]
	a.position.x = 10. * sin(i * 0.1) + 5.
	a.position.y = sin(i) + i * 0.01
	a.position.z = 10. * cos(i * 0.1) - 5.
	a.rotate:fromAxisY(cos(i))
	a.scale:set(0.5, 0.2, 1)
	
	a.phase = 0
	a.freq = 55 * floor(abs(12 * cos(i))) + 5*srandom()
	
	-- add to default tag:
	tag(a, "default")
end

function app:update(dt)
	av:events()
	
	-- pick a random agent:
	local a = pick("default")
	if a then
		a.turn.x = 0
		a.turn.y = 10 * srandom()
		a.turn.z = 0
		a.color.g = 0
		a.freq = 55 * (4+random(10)) + 5*srandom()
	end
	
	local a = pick("default")
	if a then
		local i = random(150)
		a.move:set(0, 0, 30. * random())
		a.turn.x = 2.*cos(i)
		a.turn.y = 0
		a.turn.z = 0
		a.color.r = random()
		a.color.g = 0.5
		a.freq = 55 * (11+random(10)) + 5*srandom()
	end
	
	local a = pick("default")
	if a then
		local i = random(150)
		a.move:set(0, 0, 0)
		a.position.x = 10. * sin(i * 0.1) + 5.
		a.position.y = sin(i) + i * 0.01
		a.position.z = 10. * cos(i * 0.1) - 5.
		a.rotate:fromAxisY(cos(i))
		a.color.r = 0.5
		a.color.g = 0.5
		a.freq = 55 * random(5) + 5*srandom()
	end
end

print("ok")