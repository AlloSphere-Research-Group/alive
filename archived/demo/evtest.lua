local avm = require "avm"
local gl = require "gl"

-- currently just one window:
local win = avm.window

local ev = require "libev"

local loop = ev.default_loop()

function test_basic()
	local tfun = function(loop, timer, revents)
         print(true, 'one second timer')
         print(revents)
	end

	local timer1 = ev.Timer(tfun, 1, 1)
	timer1:start(loop)
end

test_basic()

function win:draw()
	gl.ClearColor(math.random(), math.random(), math.random(), 1)
	gl.Clear()

	loop:loop(ev.RUN_NOWAIT)
end

--[[

while true do
	print("once", loop:loop(ev.RUN_ONCE))
	print("nowait", loop:loop(ev.RUN_NOWAIT))
	print("repeat")
end
--]]