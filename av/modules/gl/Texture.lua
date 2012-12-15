local gl = require "gl"
local ffi = require "ffi"
local lib = ffi.C

local m = {}
m.__index = m

local 
function texture(w, h)
	local format = gl.RGBA
	local level = 0
	local data = nil
	local ty = gl.UNSIGNED_BYTE
	
	if type(w) == "number" then
		-- assume 2D for now:
		h = h or w
		
	elseif type(w) == "string" then
		-- try to load from file:
		local src = w
		
		-- load this file:
		local image = require "av.image"
		local img = image.load(src)
		print(img)
		w = img.width
		h = img.height
		data = img.data
		if img.planes == 4 then
			ty = gl.UNSIGNED_BYTE
			format = gl.RGBA
		else
			print("unexpected format")
		end
	end
	
	return setmetatable({
		w = w, 
		h = h,
		target = gl.TEXTURE_2D,
		format = format,
		type = ty,
		level = level,
		data = data,
		
		wrap_s = gl.CLAMP_TO_EDGE,
		wrap_t = gl.CLAMP_TO_EDGE,
		min_filter = gl.LINEAR,
		mag_filter = gl.LINEAR,
		border = 0,
		tex = 0,
	}, m)
end

function m:wrap(s, t)
	self.wrap_s = s or gl.CLAMP_TO_EDGE
	self.wrap_t = t or self.wrap_s
end	

function m:destroy()
	if self.tex ~= 0 then 
		gl.DeleteTextures(self.tex)
	end
	self.tex = 0
end

function m:create()
	self:destroy()
	
	self.tex = gl.GenTextures()
	
	gl.Enable(self.target)
	gl.BindTexture(self.target, self.tex)
	gl.TexParameteri(self.target, gl.TEXTURE_WRAP_S, self.wrap_s)
	gl.TexParameteri(self.target, gl.TEXTURE_WRAP_T, self.wrap_t)
	gl.TexParameteri(self.target, gl.TEXTURE_MIN_FILTER, self.min_filter)
	gl.TexParameteri(self.target, gl.TEXTURE_MAG_FILTER, self.mag_filter)
	gl.TexImage2D(
		self.target, 
		self.level,
		self.format, 
		self.w, 
		self.h, 
		self.border, 
		self.format,
		self.type,
		self.data
	)	
	gl.BindTexture(self.target, 0)
end

function m:bind(unit)
	if self.tex == 0 then self:create() end
	unit = unit or 0
	gl.Enable(self.target)
	gl.ActiveTexture(gl.TEXTURE0 + unit)
	gl.BindTexture(self.target, self.tex)
end

function m:unbind(unit)
	unit = unit or 0
	gl.ActiveTexture(gl.TEXTURE0 + unit)
	gl.BindTexture(self.target, 0)
end

return setmetatable(m, {
	__call = function(_, ...) 
		return texture(...)
	end,
})