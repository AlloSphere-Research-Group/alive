local ffi = require 'ffi'
local C = ffi.C
local header = require 'avm.header'

local Window = {}

function Window:__tostring()
	return string.format("Window(%d)", self.id)
end

local key_events = {
	"down",
	"up"
}

local mouse_events = {
	[0] = "down",
	"up",
	"drag",
	"move",
}

function Window:__newindex(k, v)
	if k == "key" then
		self.onkey = function(self, e, k)
			v(self, key_events[e], k)
		end
		
	elseif k == "mouse" then
		self.onmouse = function(self, e, b, x, y)
			v(self, mouse_events[e], b, x, y)
		end
		
	elseif k == "fullscreen" then
		self:setfullscreen(v)
		
	elseif k == "title" then
		self:settitle(v)
		
	elseif k == "dim" then
		self:setdim(unpack(v))
		
	else
		error("cannot assign to Window: "..k)
	end
end

function Window:__index(k)
	if k == "fullscreen" then
		return self.is_fullscreen ~= 0
	elseif k == "dim" then
		return { self.width, self.height }
	else
		return Window[k]
	end
end

setmetatable(Window, {
	__index = function(self, k)
		Window[k] = C["av_window_" .. k]
		return Window[k]
	end,
})

ffi.metatype("av_Window", Window)



