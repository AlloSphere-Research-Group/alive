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
A = Agent
Q = require "query"

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
	go(function()
		while true do
			Q("red", "green"):move(Random()*5*Random())
		
			Q("red"):pick(0.2):turn(srandom()*3, srandom()*3, srandom()*3)
							:freq(Random() + 55 * Random(10))
			wait("beat")
		end
	end)

	go(function()
		while true do
			local a = Agent("green")
			local c = random() * 0.8
			a:color(c, 1, c)
			a:freq(random() + 55 * random(5))
			a:on("beat", function(self, event)
				self:move(random(10))
			end)
			wait(1)
			
			for i = 1, 4 do
				local a = Agent("red")
				local c = random() * 0.8
				a:color(1, c, c)
				a:freq(random() + 55 * random(4 + 8))
				wait(1)
			end
		end
	end)
end