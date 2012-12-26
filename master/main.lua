print("starting main2.lua")

local av = require "av"
local app = av.app
local vec = require "vec"
local E = require "expr"
E:globalize()
local agent = require "agent"
local Agent = agent.Agent
Q = require "query"

local sin, cos = math.sin,math.cos
local abs, floor = math.abs, math.floor
local table_remove = table.remove
local random = math.random
local srandom = function() return random() * 2 - 1 end

math.randomseed(os.time())

--------------------------------------------------------------------------------
-- DEMO
--------------------------------------------------------------------------------

--[[

stateful exprs

p = SinOsc(10) + 1
	=> { op="+", { op="sinosc", 10 }, { op="number", 1 } }

=>

loadstring this:

local phase = 0
return function(env, dt)
	phase = phase + 10 / dt
	local v1 = sin(phase * pi * 2)
	local v2 = v1 + 1
	return v2
end

--]]

--[[go(function()
	while true do
		Q("red", "green"):move(Random()*5*Random()*5)
	
		Q("red"):pick(0.2):turn(srandom()*3, srandom()*3, srandom()*3)
						:freq(Random() + 55 * Random(10))
		wait("beat")
	end
end)

go(function()
	while true do
		local a = Agent("green")
		a:color(0.5, 1, 0.5)
		a:freq(random() + 55 * random(5))
		a:on("beat", function(self, event)
			self:move(random(10))
		end)
		wait(1)
		
		for i = 1, 4 do
			local a = Agent("red")
			a:color(1, 0.5, 0.5)
			a:freq(random() + 55 * random(4 + 8))
			wait(1)
		end
	end
end)

print("ok")--]]