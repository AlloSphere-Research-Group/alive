local ffi = require "ffi"
local C = ffi.C

-- allow loading modules from within av
-- (use package.preload instead?)
package.path = "./world/?.lua;./world/?/init.lua;" .. package.path

local av = {}

local window = require "window"

function av.run()
	--[[
	while window.running do
		window.swap()
		-- in order to get maximum possible frame rate?
		run_once(0.01)
	end
	--]]
	window:startloop()
end

return av