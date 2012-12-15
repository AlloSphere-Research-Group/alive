local av = require "av"
local vec = require "vec"
local ev = require "ev"

local app = av.app

local sin, cos = math.sin,math.cos
local abs, floor = math.abs, math.floor
local random = math.random
local srandom = function() return random() * 2 - 1 end

print(app.agents, av.MAX_AGENTS)



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
end

function app:update(dt)
	av:events()
	
	-- pick a random agent:
	local i = random(av.MAX_AGENTS)-1
	local a = app.agents[i]
	a.turn.x = 0
	a.turn.y = 10 * srandom()
	a.turn.z = 0
	a.color.g = 0
	
	-- pick a random agent:
	local i = random(av.MAX_AGENTS)-1
	local a = app.agents[i]
	a.move:set(0, 0, 30. * abs(sin(i)))
	a.turn.x = 2.*cos(i)
	a.turn.y = 0
	a.turn.z = 0
	a.color.r = random()
	a.color.g = 0.5
	
	-- pick a random agent:
	local i = random(av.MAX_AGENTS)-1
	local a = app.agents[i]
	a.move:set(0, 0, 0)
	a.position.x = 10. * sin(i * 0.1) + 5.
	a.position.y = sin(i) + i * 0.01
	a.position.z = 10. * cos(i * 0.1) - 5.
	a.rotate:fromAxisY(cos(i))
	a.color.r = 0.5
	a.color.g = 0.5
end

print("ok")