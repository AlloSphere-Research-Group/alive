print("running on", hostname)

local ffi = require "ffi"
local clang = require "clang"
local osc = require "osc"

ffi.cdef [[
void al_sleep(double t);
]]
local C = ffi.C

local function exec(cmd) print(os.execute(cmd)) end	

local r = osc.Recv(8019)
local s = osc.Send("localhost", 8010)
--s:send("/print", "hello")

while true do
	for m in r:recv() do
		if m.addr == "/handshake" then
			print("got handshake", unpack(m))
		elseif m.addr == "/git" then
			print("got git cmd", unpack(m))
			exec("git " .. table.concat(m, " "))
			print("done")
		else
			print("unrecognized command", m.addr, unpack(m))
		end
	end
	
	C.al_sleep(0.1)
end