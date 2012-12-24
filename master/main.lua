print("starting main2.lua")

local av = require "av"
local app = av.app
local vec = require "vec"
local E = require "expr"
E:globalize()
local agent = require "agent"
local Tag = agent.Tag
local Agent = agent.Agent

local sin, cos = math.sin,math.cos
local abs, floor = math.abs, math.floor
local table_remove = table.remove
local random = math.random
local srandom = function() return random() * 2 - 1 end

math.randomseed(os.time())

--------------------------------------------------------------------------------
-- DEMO
--------------------------------------------------------------------------------

a = 10
A = Random(2) ^ (Sin(1)):abs() - E"a"

print(A)
print(A())

local all = Tag("*")
local reds = Tag("red")
local greens = Tag("green")

go(function()
	while true do
		all:pick(0.1):move(random()*10*random()*10)
		reds:pick(0.1):turn(srandom()*3, srandom()*3, srandom()*3)
		reds:pick(0.1):freq(random() + 55 * random(10))
		wait("beat")
	end
end)

go(function()
	while true do
		
		local a = Agent("green")
		a:color(0.5, 1, 0.5)
		a:freq(random() + 55 * random(10))
		wait(1)
		
		for i = 1, 4 do
			local a = Agent("red")
			a:color(1, 0.5, 0.5)
			a:freq(random() + 55 * random(10))
			wait(1)
		end
	end
end)

print("ok")