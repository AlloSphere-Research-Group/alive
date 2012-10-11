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


local uniformsetters = {
	[gl.FLOAT] = gl.Uniform1f,
	[gl.FLOAT_VEC2] = gl.Uniform2f,
	[gl.FLOAT_VEC3] = gl.Uniform3f,
	[gl.FLOAT_VEC4] = gl.Uniform4f,
	[gl.INT] = gl.Uniform1i,
	[gl.INT_VEC2] = gl.Uniform2i,
	[gl.INT_VEC3] = gl.Uniform3i,
	[gl.INT_VEC4] = gl.Uniform4i,
	-- gl.BOOL, gl.BOOL_VEC2, gl.BOOL_VEC3, gl.BOOL_VEC4, 
	[gl.FLOAT_MAT2] = function(index, v)
		gl.UniformMatrix2f(index, 1, 0, v)
	end,	
	[gl.FLOAT_MAT3] = function(index, v)
		gl.UniformMatrix3f(index, 1, 0, v)
	end, 
	[gl.FLOAT_MAT4] = function(index, v)
		gl.UniformMatrix4f(index, 1, 0, v)
	end, 
	[gl.SAMPLER_2D] = gl.Uniform1i,
	[gl.SAMPLER_3D] = gl.Uniform1i,
	[gl.SAMPLER_CUBE] = gl.Uniform1i,
}
local attributesetters = {
	[gl.FLOAT] = gl.VertexAttrib1f,
	[gl.FLOAT_VEC2] = gl.VertexAttrib2f,
	[gl.FLOAT_VEC3] = gl.VertexAttrib3f,
	[gl.FLOAT_VEC4] = gl.VertexAttrib4f,
}

local 
function checkStatus(program)	
	local status = ffi.new("GLint[1]")
    gl.GetProgramiv(program, gl.LINK_STATUS, status)
	if status[0] == gl.FALSE then
		local infoLogLength = ffi.new("GLint[1]")
		gl.GetProgramiv(program, gl.INFO_LOG_LENGTH, infoLogLength)
		local strInfoLog = ffi.new("GLchar[?]", infoLogLength[0] + 1)
        gl.GetProgramInfoLog(program, infoLogLength[0], nil, strInfoLog)
        gl.DeleteProgram(self.id)
        self.id = 0
		error("gl.LinkProgram " .. ffi.string(strInfoLog))
	end
	return program
end

local Shader = class(function(vertex, fragment)
	t = {
		id = 0,
		uniforms = {},
		attributes = {},
		vertex = vertex,
		fragment = fragment,
	}
	--watcher.run_and_watch(vert, watcher.read_and_set, t, "vertex")
	--watcher.run_and_watch(frag, watcher.read_and_set, t, "fragment")
	return t
end)

function Shader:destroy()
	if self.id ~= 0 then
		gl.DeleteProgram(self.id)
	end
	self.id = 0
end

function Shader:create()
	--print("------")
	
	-- create shaders:
	local vs = gl.CreateShader(gl.VERTEX_SHADER, self.vertex)
	local fs = gl.CreateShader(gl.FRAGMENT_SHADER, self.fragment)
	-- clear uniforms:
	self.uniforms = {}
	self.attributes = {}
	
	self.id = gl.CreateProgram()
	gl.AttachShader(self.id, vs)
	gl.AttachShader(self.id, fs)
	
	-- link:
	gl.LinkProgram(self.id)
	gl.DetachShader(self.id, vs)
	gl.DetachShader(self.id, fs)
	
	-- query attrs:
	local params = ffi.new("GLint[1]")
	
	gl.GetProgramiv(self.id, gl.ACTIVE_UNIFORMS, params)
	--print("uniforms:", params[0])
	for i = 0, params[0]-1 do
		self:addUniform(i)
	end
	
	gl.GetProgramiv(self.id, gl.ACTIVE_ATTRIBUTES, params)
	--print("attributes:", params[0])
	for i = 0, params[0]-1 do
		self:addAttribute(i)
	end
	
	self.id = checkStatus(self.id)
	
	-- cleanup:
	gl.DeleteShader(vs)
	gl.DeleteShader(fs)
	
	return self
end

function Shader:addUniform(index)
	local length = ffi.new("GLsizei[1]")
	local size = ffi.new("GLint[1]")
	local type = ffi.new("GLenum[1]")
	local buf = ffi.new("GLchar[128]")
	-- get uniform properties:
	gl.GetActiveUniform(self.id, index, 128, length, size, type, buf)
	local k = ffi.string(buf)
	local loc = gl.GetUniformLocation(self.id, k)
	u = {
		index = index,
		loc = loc,
		type = type[0],
		size = size[0],
		length = length[0],
		setter = assert(uniformsetters[type[0] ]),
	}
	--print(string.format("adding uniform setter for %s: index %d (%d), type %d, size %d length %d", k, u.index, u.loc, u.type, u.size, u.length))
	self.uniforms[k] = u
end

function Shader:addAttribute(index)
	local length = ffi.new("GLsizei[1]")
	local size = ffi.new("GLint[1]")
	local ty = ffi.new("GLenum[1]")
	local buf = ffi.new("GLchar[128]")
	
	-- get uniform properties:
	gl.GetActiveAttrib(self.id, index, 128, length, size, ty, buf)
	local k = ffi.string(buf)
	local loc = gl.GetAttribLocation(self.id, k)
	u = {
		index = index,
		loc = loc,
		type = ty[0],
		size = size[0],
		length = length[0],
		setter = assert(attributesetters[ ty[0] ]),
	}
	--print(string.format("adding attribute setter for %s: index %d (%d), type %d, size %d length %d", k, u.index, loc, u.type, u.size, u.length))
	self.attributes[k] = u
end

function Shader:bind()
	if self.id == 0 then
		self:create()
	end
	gl.UseProgram(self.id)
end

function Shader:unbind()
	gl.UseProgram(0)
end

function Shader:GetAttribLocation(k)
	return gl.GetAttribLocation(self.id, k)
end


function Shader:uniform(k, ...)
	local u = self.uniforms[k]
	if not u then
		error("Shader uniform not found: "..k)
	end
	u.setter(u.loc, ...)
end

function Shader:attribute(k, ...)
	local u = self.attributes[k]
	if not u then
		error("Shader attribute not found: "..k)
	end
	u.setter(u.loc, ...)
end

return Shader
