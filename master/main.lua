local av = require "av"
local app = av.app
local vec = require "vec"
local E = require "expr"
E:globalize()
local agent = require "agent"
local Agent = agent.Agent
Q = require "query"

local sin, cos = math.sin,math.cos
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

--[[

--]]
