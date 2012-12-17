
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

local function modified(filename)
	if ffi.os == "OSX" then
		return tonumber(io.popen('stat -f "%m" ' .. filename):read("*l"))
	else
		return tonumber(io.popen('stat -c %Y ' .. filename):read("*l"))
	end
end

local mainmod = 1 + modified("main.lua")

av.timer = ev.Timer(function(loop, handler, event)
	assert(event == ev.TIMER)
	--print('one second (ish) timer', loop:now())
	local mod = modified("main.lua")
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
	str = str:gsub("\\n", "\n")
	print('io', str)
	local ok, f = pcall(loadstring, str)
	if ok then
		local ok, err = pcall(f)
		if not ok then print(err) end
	else
		print(err)
	end
		
	
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