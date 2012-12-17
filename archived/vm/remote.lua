local luv = require "luv"

local toluajit = luv.pipe.create()
toluajit:open(10)

local fromluajit = luv.pipe.create()
fromluajit:open(11)

local f = luv.fiber.create(function()
	local p = luv.process.spawn("./alive", { "", stdout = luv.stdout, stdin = toluajit })
	print("SPAWNED:", p)

	--toluajit:write("print(1234)")
	
	while true do
		local l, m = luv.stdin:read()
		print(l, m)
		
		--toluajit:write(m)
	end
end)
f:ready()
f:join()
