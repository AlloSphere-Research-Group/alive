local ffi = require 'ffi'
local lib = ffi.C
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
			local ok, err = pcall(v, self, key_events[e], k)
			if not ok then print(debug.traceback(err)) end
		end
		
	elseif k == "draw" then
		self.ondraw = function(self)
			local ok, err = pcall(v, self)
			if not ok then print(debug.traceback(err)) end
		end
		
	elseif k == "create" then
		self.oncreate = function(self)
			local ok, err = pcall(v, self)
			if not ok then print(debug.traceback(err)) end
		end
		
	elseif k == "resize" then
		self.onresize = function(self, w, h)
			local ok, err = pcall(v, self, w, h)
			if not ok then print(debug.traceback(err)) end
		end
		
	elseif k == "visible" then
		self.ondraw = function(self, s)
			local ok, err = pcall(v, self, s)
			if not ok then print(debug.traceback(err)) end
		end
		
	elseif k == "mouse" then
		self.onmouse = function(self, e, b, x, y)
			local ok, err = pcall(v, self, mouse_events[e], b, x, y)
			if not ok then print(debug.traceback(err)) end
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
		Window[k] = lib["av_window_" .. k]
		return Window[k]
	end,
})

ffi.metatype("av_Window", Window)

local w = lib.av_window_create()

return w