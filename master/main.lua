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

