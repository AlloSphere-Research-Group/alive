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

local VertexArray = class(function()
	t = {}
	t.id = 0
	return t
end)

function VertexArray:create(vertexData, size, mode)
	size = size or ffi.sizeof(vertexData)
	mode = mode or gl.STREAM_DRAW	 -- e.g. gl.STATIC_DRAW)
	t.id = gl.GenBuffers()
	gl.BindBuffer(gl.ARRAY_BUFFER, t.id)
	gl.BufferData(gl.ARRAY_BUFFER, size, vertexData, mode)
	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
end

function VertexArray:SubData(vertexData, size)
	gl.BindBuffer(gl.ARRAY_BUFFER, self.id)
	gl.BufferSubData(gl.ARRAY_BUFFER, 0, size or ffi.sizeof(vertexData), vertexData)
	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
end

return VertexArray