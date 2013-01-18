-- STARTUP INITIALIZATION
-- not using locals here
-- so that the environment is already primed for live coding without verbiosity

-- math extensions:
function math.srandom() return random() * 2 - 1 end
-- copy all math lib into global scope:
for k, v in pairs(math) do _G[k] = v end

-- pull in modules:
av = require "av"
app = av.app
vec = require "vec"
E = require "expr"
E:globalize()
local agent = require "agent"
Agent = agent.Agent
local query = require "query"
Tag = query.Tag

A = Agent
T = Tag
Q = query

-- random means random
math.randomseed(os.time())

-- panic handler:
function panic()
	-- kill all coroutines:
	av.panic()
	
	-- kill all agents:
	Q("*"):die()
end

function demo()
	-- create some agents
	for i = 1, 25 do
		local a = Agent("green")
		local c = random() * 0.8
		a:color(c, 1, c)
		a:freq(random() + 55 * random(5))
		a:on("beat", function(self, event)
			self:move(srandom(10))
		end)
		
		for i = 1, 4 do
			local a = Agent("red")
			local c = random() * 0.8
			a:color(1, c, c)
			a:freq(random() + 55 * random(4 + 8))
			a:move(random(10))
		end
	end
	
	-- make them change:
	go(function()
		while true do
			Q("*"):pick(0.2)
				:turn(srandom()*3, srandom()*3, srandom()*3)
				:freq(Random() + 55 * Random(10))
			wait("beat")
		end
	end)
end