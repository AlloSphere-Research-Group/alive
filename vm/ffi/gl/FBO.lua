local gl = require "ffi.gl"
local ffi = require "ffi"

local 
function class(ctor)
	local c = {}
	c.__index = c
	setmetatable(c, {
		__call = function(c, ...) return setmetatable(ctor(...) or {}, c) end,
	})
	return c
end

local FBO = class(function(w, h) 
	return { 
		fbo = 0,
		color = 0,
		depth = 0,
		w = w or 512, 
		h = h or w or 512,
		clearcolor = { 0, 0, 0, 1. },
	}
end)

function FBO:destroy()
	if self.fbo ~= 0 then gl.DeleteFramebuffers(self.fbo) end
	if self.color ~= 0 then gl.DeleteTextures(self.color) end
	if self.depth ~= 0 then gl.DeleteTextures(self.depth) end
	self.fbo = 0
	self.color = 0
	self.depth = 0
end

function FBO:create()
	self:destroy()
	
	gl.Enable(gl.TEXTURE_2D)
	self.color = gl.GenTextures(1)
	gl.BindTexture(gl.TEXTURE_2D, self.color)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, self.w, self.h, 0, gl.RGBA, gl.UNSIGNED_BYTE, nil)	
	--gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, fbow, fboh, 0, gl.RGBA, gl.FLOAT, 0)	
	gl.BindTexture(gl.TEXTURE_2D, 0)
	--print("colortex", self.color)
	
	gl.Enable(gl.TEXTURE_2D)
	self.depth = gl.GenTextures(1)
	gl.BindTexture(gl.TEXTURE_2D, self.depth)
	--gl.TexParameter(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
    --gl.TexParameter(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
    --gl.TexParameter(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP)
    --gl.TexParameter(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_BORDER)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_BORDER)
	--gl.TexParameter(gl.TEXTURE_2D, gl.TEXTURE_BORDER_COLOR, 1, 1, 1, 1)	
    --gl.TexParameter(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    --gl.TexParameter(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	--gl.TexParameter(gl.TEXTURE_2D, gl.TEXTURE_COMPARE_FUNC, gl.LEQUAL)
	--gl.TexParameter(gl.TEXTURE_2D, gl.TEXTURE_COMPARE_MODE, gl.COMPARE_R_TO_TEXTURE)
	--gl.TexImage2D(gl.TEXTURE_2D, 0, gl.DEPTH_COMPONENT24, fbow, fboh, 0, gl.DEPTH_COMPONENT, gl.UNSIGNED_INT, 0)	
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.DEPTH_COMPONENT24, self.w, self.h, 0, gl.DEPTH_COMPONENT, gl.FLOAT, nil)	
	gl.BindTexture(gl.TEXTURE_2D, 0)
	--print("depthtex", self.depth)

	--[[
	rbo = gl.GenRenderbuffers()
	gl.BindRenderbuffer(rbo)
	gl.RenderbufferStorage(gl.DEPTH_COMPONENT24, fbow, fboh)
	gl.UnBindRenderbuffer(rbo)	
	print("rbo", rbo)
	--]]
	
	self.fbo = gl.GenFramebuffers(1)
	gl.BindFramebuffer(gl.FRAMEBUFFER, self.fbo)
	--gl.FramebufferRenderbuffer(gl.DEPTH_ATTACHMENT, rbo)
	gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.TEXTURE_2D, self.depth, 0)
	gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, self.color, 0)
	local status = gl.CheckFramebufferStatus(gl.FRAMEBUFFER)
	
	print(status, gl.FRAMEBUFFER_COMPLETE)
	if status ~= gl.FRAMEBUFFER_COMPLETE and status ~= 0 then
		if status == gl.FRAMEBUFFER_INCOMPLETE_ATTACHMENT then
			error("GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT")
		elseif status == gl.FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT then
			error("GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT")
		--elseif status == gl.FRAMEBUFFER_INCOMPLETE_FORMATS then
		--	error("GL_FRAMEBUFFER_INCOMPLETE_FORMATS")
		elseif status == gl.FRAMEBUFFER_INCOMPLETE_DRAW_BUFFER then
			error("GL_FRAMEBUFFER_INCOMPLETE_DRAW_BUFFER")
		elseif status == gl.FRAMEBUFFER_INCOMPLETE_READ_BUFFER then
			error("GL_FRAMEBUFFER_INCOMPLETE_READ_BUFFER")
		elseif status == gl.FRAMEBUFFER_UNSUPPORTED then
			error("GL_FRAMEBUFFER_UNSUPPORTED")
		--elseif status == gl.FRAMEBUFFER_INCOMPLETE_DIMENSIONS then
		--	error("GL_FRAMEBUFFER_INCOMPLETE_DIMENSIONS")
		else
			error("unexpected gl.CheckFramebufferStatus status: " .. tostring(status))
		end	
	end
	
	gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
	--print("fbo", self.fbo)
end

function FBO:enter()
	if self.fbo == 0 then self:create() end
	
	gl.Enable(gl.TEXTURE_2D)
	gl.BindFramebuffer(gl.FRAMEBUFFER, self.fbo)
	
	gl.Viewport(0, 0, self.w, self.h)
	gl.ClearColor(clearcolor)
	gl.ClearDepth(1.0)
	gl.Clear(bit.bor(gl.COLOR_BUFFER_BIT, gl.DEPTH_BUFFER_BIT))
end

function FBO:leave()
	gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
end

function FBO:depthmipmap()	
	self:binddepth2D()
	gl.GenerateMipmap(gl.TEXTURE_2D)
	self:unbind()
end

function FBO:colormipmap()	
	self:binddepth2D()
	gl.GenerateMipmap(gl.TEXTURE_2D)
	self:unbind()
end

function FBO:bindcolor(unit)
	if self.fbo == 0 then self:create() end
	unit = unit or 0
	gl.Enable(gl.TEXTURE_2D)
	gl.ActiveTexture(gl.TEXTURE0 + unit)
	gl.BindTexture(gl.TEXTURE_2D, self.color)
end

function FBO:binddepth(unit)
	if self.fbo == 0 then self:create() end
	unit = unit or 0
	gl.Enable(gl.TEXTURE_2D)
	gl.ActiveTexture(gl.TEXTURE0 + unit)
	gl.BindTexture(gl.TEXTURE_2D, self.depth)
end

function FBO:unbind(unit)
	unit = unit or 0
	gl.ActiveTexture(gl.TEXTURE0 + unit)
	gl.BindTexture(gl.TEXTURE_2D, 0)
end

-- bind first.
function FBO:readcolor()
	if not self.colordata then
		local size = self.w * self.h * 3
		self.colordata = ffi.new("uint8_t[?]", self.w * self.h * 4)
	end
	gl.BindFramebuffer(gl.FRAMEBUFFER, self.fbo)
	gl.ReadPixels(0, 0, self.w, self.h, gl.RGB, gl.UNSIGNED_BYTE, ffi.cast("GLvoid *", self.colordata))
	gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
	return self.colordata
end

return FBO
