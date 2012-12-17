
local header = require "header"
local ffi = require "ffi"
local C = ffi.C
local vec = require "vec"
local ev = require "ev"

local loop = ev.default_loop()
local app = C.app_get()


local av = {
	app = app,
}

local mainmod = 1 + tonumber(io.popen('stat -f "%m" main.lua'):read("*l"))

av.timer = ev.Timer(function(loop, handler, event)
	assert(event == ev.TIMER)
	--print('one second (ish) timer', loop:now())
	local mod = tonumber(io.popen('stat -f "%m" main.lua'):read("*l"))
	if mod > mainmod then
		print(string.rep("-", 80))
		dofile("main.lua")
		mainmod = mod
	end
end, 1, 1)
av.timer:start(loop)

av.stdin = ev.IO(function(loop, handler, event)
	local fd = handler.fd	-- 0
	local str = io.read("*l") --io.read(1)
	print('io', str)
	
	if str == "q" then os.exit() end	
end, 0, ev.READ)
av.stdin:start(loop)

function av:events()
	loop:run(ev.RUN_NOWAIT) 
end

setmetatable(av, {
	__index = function(_, k)
		return C[k]
	end,
})

return av