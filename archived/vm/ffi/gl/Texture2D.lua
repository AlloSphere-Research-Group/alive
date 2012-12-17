local gl = require "ffi.gl"

local 
function class(ctor)
	local c = {}
	c.__index = c
	setmetatable(c, {
		__call = function(c, ...) return setmetatable(ctor(...) or {}, c) end,
	})
	return c
end

local Texture2D = class(function(w, h, format, type, level, data)
	if format == 1 then 
		format = gl.LUMINANCE
	elseif format == 2 then
		format = gl.LUMINANCE_ALPHA
	elseif format == 3 then 
		format = gl.RGB
	else
		format = gl.RGBA
	end

	return {
		w = w or 512, 
		h = h or 512,
		target = gl.TEXTURE_2D,
		format = format,
		type = type or gl.UNSIGNED_BYTE,
		level = level or 0,
		data = data,
		
		wrap_s = gl.CLAMP_TO_EDGE,
		wrap_t = gl.CLAMP_TO_EDGE,
		min_filter = gl.LINEAR,
		mag_filter = gl.LINEAR,
		border = 0,
		tex = 0,
	}
end)

function Texture2D:wrap(s, t)
	self.wrap_s = s or gl.CLAMP_TO_EDGE
	self.wrap_t = t or self.wrap_s
end	

function Texture2D:destroy()
	if self.tex ~= 0 then 
		gl.DeleteTextures(self.tex)
	end
	self.tex = 0
end

function Texture2D:create()
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
		self.format or gl.RGBA, 
		self.w, 
		self.h, 
		self.border, 
		self.format,
		self.type,
		self.data
	)	
	gl.BindTexture(self.target, 0)
end

function Texture2D:bind(unit)
	if self.tex == 0 then self:create() end
	unit = unit or 0
	gl.Enable(self.target)
	gl.ActiveTexture(gl.TEXTURE0 + unit)
	gl.BindTexture(self.target, self.tex)
end

function Texture2D:unbind(unit)
	unit = unit or 0
	gl.ActiveTexture(gl.TEXTURE0 + unit)
	gl.BindTexture(self.target, 0)
end

return Texture2D
