
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

av.timer = ev.Timer(function(loop, handler, event)
	assert(event == ev.TIMER)
	--print('one second (ish) timer' .. loop:now())
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