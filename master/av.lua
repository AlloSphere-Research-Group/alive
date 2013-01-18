
local ffi = require "ffi"
local header = require "header"
local C = ffi.C
local app = C.global_get()

local ev = require "ev"
local loop = ev.default_loop()

local vec = require "vec"
local scheduler = require "scheduler"
local notify = require "notify"
local notify_trigger = notify.trigger


local main = scheduler.create()
-- these are global:
go, now, wait, event, sequence, cancel = main.go, main.now, main.wait, main.event, main.sequence, main.cancel




-- bpm is also global, so it can be easily modified:
bpm = 120
-- start a tempo routine:
go(function()
	while true do
		-- TODO: merge these two event systems:
		event("beat")
		notify_trigger("beat")
		wait(60/bpm)
	end
end)

local av = {
	app = app,
	panic = scheduler.panic,
}

av.timer = ev.Timer(function(loop, handler, event)
	--assert(event == ev.TIMER)
	--print('one second (ish) timer', loop:now())
	
end, 1, 1)
av.timer:start(loop)

av.stdin = ev.IO(function(loop, handler, event)
	local fd = handler.fd
	local str = io.read("*l")
	str = str:gsub("<n>", "\n")
	print('io', os.time(), str)
	local ok, f = pcall(loadstring, str)
	if ok then
		local ok, err = pcall(f)
		if not ok then print(err) end
	else
		print(f)
	end
	if str == "q" then os.exit() end	
end, 0, ev.READ)
av.stdin:start(loop)

function av:events()
	loop:run(ev.RUN_NOWAIT) 
end

-- entry point from application:
function av.app:update(dt)
	loop:run(ev.RUN_NOWAIT)
	-- trigger scheduler: 
	-- or main.update(now)?
	main.advance(dt)
	
	print("update", dt)
	
	event("update", dt)
	-- make sure prints print
	io.flush()
end

setmetatable(av, {
	__index = function(_, k)
		return C[k]
	end,
})

return av