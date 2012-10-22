local ffi = require "ffi"
local gl = require "gl"
local Shader = require "gl.Shader"

local vec = require "vec"
local vec3, quat = vec.vec3, vec.quat

local vs = [[
	#version 110
	varying vec2 T;
	void main(void) {
		// pass through the texture coordinate (normalized pixel):
		T = vec2(gl_MultiTexCoord0);
		gl_Position = vec4(T*2.-1., 0, 1);
	}
]]

local fs = [[
	#version 110
	uniform samplerCube cubeMap;
	
	varying vec2 T;
	
	float M_PI = 3.1415926536;
	
	void main (void){
		// x runs 0..1, convert to angle -PI..PI:
		float az = M_PI * (T.x*2.-1.);
		// y runs 0..1, convert to angle -PI_2..PI_2:
		float el = M_PI * 0.5 * (T.y*2.-1.);
		// convert polar to normal:
		float x1 = sin(az);
		float y1 = sin(el);
		float z1 = cos(az);
		vec3 v = vec3(x1, y1, z1);
		
		// index into cubemap:
		vec3 rgb = textureCube(cubeMap, v).rgb;
		
		gl_FragColor = vec4(rgb, 1.);
	}
]]

local cylinder_shader = Shader(vs, fs)

local m = {}
m.__index = m

local Faces = { 
	POSITIVE_X, NEGATIVE_X, 
	POSITIVE_Y, NEGATIVE_Y, 
	POSITIVE_Z, NEGATIVE_Z 
}

function m:create()
	-- create cubemap texture
	self.tex = gl.GenTextures(1)
	gl.BindTexture(gl.TEXTURE_CUBE_MAP, self.tex)
	-- each cube face should clamp at texture edges:
	gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
	gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
	gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_R, gl.CLAMP_TO_EDGE)
	-- normal filtering
	gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	-- no mipmapping:
	--glTexParameteri(mTarget, gl.GENERATE_MIPMAP, gl.TRUE); -- automatic mipmap
	--glTexParameterf(mTarget, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
	---[[
	gl.TexGeni( gl.S, gl.TEXTURE_GEN_MODE, gl.OBJECT_LINEAR )
	gl.TexGeni( gl.T, gl.TEXTURE_GEN_MODE, gl.OBJECT_LINEAR )
	gl.TexGeni( gl.R, gl.TEXTURE_GEN_MODE, gl.OBJECT_LINEAR )
	local X = ffi.new("float[4]", { 1,0,0,0 })
	local Y = ffi.new("float[4]", { 0,1,0,0 })
	local Z = ffi.new("float[4]", { 0,0,1,0 })
	gl.TexGenfv( gl.S, gl.OBJECT_PLANE, X )
	gl.TexGenfv( gl.T, gl.OBJECT_PLANE, Y )
	gl.TexGenfv( gl.R, gl.OBJECT_PLANE, Z )
	--]]
	-- RGBA8 Cubemap texture, mResolution x mResolution
	for face = 0, 5 do
		gl.TexImage2D(
			gl.TEXTURE_CUBE_MAP_POSITIVE_X+face, 
			0, 
			gl.RGBA8, 
			self.dim, self.dim, 0, 
			gl.BGRA, gl.UNSIGNED_BYTE, nil
		)
	end
	gl.BindTexture(gl.TEXTURE_CUBE_MAP, 0)
	
	-- one FBO to rule them all...
	self.fbo = gl.GenFramebuffers(1)
	gl.BindFramebuffer(gl.FRAMEBUFFER, self.fbo)
	-- Attach one of the faces of the Cubemap texture to this FBO
	gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_CUBE_MAP_POSITIVE_X, self.tex, 0)
	
	self.rbo = gl.GenRenderbuffers()
	gl.BindRenderbuffer(gl.RENDERBUFFER, self.rbo)
	gl.RenderbufferStorage(gl.RENDERBUFFER, gl.DEPTH_COMPONENT24, self.dim, self.dim)
	-- Attach depth buffer to FBO
	gl.FramebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.RENDERBUFFER, self.rbo)

	-- ...and in the darkness bind them:
	for face = 0, 5 do
		gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0+face, gl.TEXTURE_CUBE_MAP_POSITIVE_X+face, self.tex, 0)
	end
	
	-- Does the GPU support current FBO configuration?
	local status = gl.CheckFramebufferStatus(gl.FRAMEBUFFER)
	if status ~= gl.FRAMEBUFFER_COMPLETE then
		error("GPU does not support required FBO configuration\n")
	end
	
	-- cleanup:
	gl.BindRenderbuffer(gl.RENDERBUFFER, 0)
	gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
end

function m:destroy()
	gl.DeleteTextures(1, self.tex)
end

function m:bind(unit)
	unit = unit or 0
	
	if self.tex == 0 then
		self:create()
	end

	gl.ActiveTexture(gl.TEXTURE0+unit)
	gl.Enable(gl.TEXTURE_CUBE_MAP)
	gl.BindTexture(gl.TEXTURE_CUBE_MAP, self.tex)
end

function m:unbind(unit)
	unit = unit or 0
	
	gl.ActiveTexture(gl.TEXTURE0+unit)
	gl.BindTexture(gl.TEXTURE_CUBE_MAP, 0)
	--gl.Disable(gl.TEXTURE_CUBE_MAP)
end


local
function lookat(ux, uy, uz, pos)
	local m = {	
		ux.x,			up.x,			uz.x,			0,
		ux.y,			up.y,			uz.y,			0,
		ux.z,			up.z,			uz.z,			0,
		-ux:dot(eye),	-up:dot(eye),	-uz:dot(eye),	1,	
	}
	return m
end

function m:capture(draw, pos, near, far, clearColor)
	near = near or 0.1
	far = far or 100
	clearColor = clearColor or {0, 0, 0}
	
	if self.tex == 0 then
		self:create()
	end
	
	-- do we really need to do this?
	gl.PushAttrib(gl.ALL_ATTRIB_BITS)
	
		
	-- a 90' fovy, 1/1 aspect perspective matrix:
	local D = far-near	
	local D2 = far+near
	local fn2 = far*near*2
	local projection = {	
		1,	0,	0,		0,
		0,	1,	0,		0,
		0,	0,	-D2/D,	-1,
		0,	0,	-fn2/D,	0
	}
	
	local ux = vec3( 1, 0, 0 )
	local uy = vec3( 0, 1, 0 )
	local uz = vec3( 0, 0, 1 )
	local nx = vec3( -1,0, 0 )
	local ny = vec3( 0, -1,0 )
	local nz = vec3( 0, 0, -1)
	
	gl.BindFramebuffer(gl.FRAMEBUFFER, self.fbo)
	for face = 0, 5 do
		gl.DrawBuffer(gl.COLOR_ATTACHMENT0 + face)
		gl.Viewport(0, 0, self.dim, self.dim)
		gl.ClearColor(clearColor)
		gl.Clear(gl.COLOR_BUFFER_BIT, gl.DEPTH_BUFFER_BIT)
		
		gl.MatrixMode(gl.PROJECTION)
		gl.LoadMatrix(projection)
		gl.MatrixMode(gl.MODELVIEW)
		
		if face == 0 then
			-- gl.TEXTURE_CUBE_MAP_POSITIVE_X   
			--gl.LoadMatrix(lookAt(uz, uy, nx, pos))
			gl.LoadMatrix{	
				0,		0,		-1,		0,
				0,		1,		0,		0,
				1,		0,		0,		0,
				-pos.z,	-pos.y,	pos.x,	1,	
			}			
		elseif face == 1 then
			-- gl.TEXTURE_CUBE_MAP_NEGATIVE_X   
			--gl.LoadMatrix(lookAt(nz, uy, ux, pos))
			gl.LoadMatrix{	
				0,		0,		1,		0,
				0,		1,		0,		0,
				-1,		0,		0,		0,
				pos.z,	-pos.y,	-pos.x,	1,	
			}
		elseif face == 2 then
			-- gl.TEXTURE_CUBE_MAP_POSITIVE_Y   
			--gl.LoadMatrix(lookAt(ux, nz, uy, pos))
			gl.LoadMatrix{	
				1,		0,		0,		0,
				0,		0,		1,		0,
				0,		-1,		0,		0,
				-pos.x,	pos.z,	-pos.y,	1,	
			}
		
		elseif face == 3 then
			-- gl.TEXTURE_CUBE_MAP_NEGATIVE_Y   
			--gl.LoadMatrix(lookAt(ux, uz, ny, pos))
			gl.LoadMatrix{	
				1,		0,		0,		0,
				0,		0,		-1,		0,
				0,		1,		0,		0,
				-pos.x,	-pos.z,	pos.y,	1,	
			}
		elseif face == 4 then
			-- gl.TEXTURE_CUBE_MAP_POSITIVE_Z   
			--gl.LoadMatrix(lookAt(ux, uy, uz, pos))
			gl.LoadMatrix{	
				1,		0,		0,		0,
				0,		1,		0,		0,
				0,		0,		1,		0,
				-pos.x,	-pos.y,	-pos.z,	1,	
			}
		else
			-- gl.TEXTURE_CUBE_MAP_NEGATIVE_Z   
			--gl.LoadMatrix(lookAt(nx, uy, nz, pos))
			gl.LoadMatrix{	
				-1,		0,		0,		0,
				0,		1,		0,		0,
				0,		0,		-1,		0,
				pos.x,	-pos.y,	pos.z,	1,	
			}
		end
		
		draw()
	end
	gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
	
	gl.PopAttrib()
end

function m:draw()
	self:bind()
	cylinder_shader:bind()
	cylinder_shader:uniform("cubeMap", 0)
	gl.Begin(gl.QUADS)
		gl.TexCoord(0, 0)	gl.Vertex(0, 0, 0)
		gl.TexCoord(1, 0)	gl.Vertex(1, 0, 0)
		gl.TexCoord(1, 1)	gl.Vertex(1, 1, 0)
		gl.TexCoord(0, 1)	gl.Vertex(0, 1, 0)
	gl.End()
	cylinder_shader:unbind()
	self:unbind()
end

-- build up a mesh to demo?
--[[
	x and y run 0..1
	inline void drawMapVertex(double x, double y) {
		-- x runs 0..1, convert to angle -PI..PI:
		double az = M_PI * (x*2.-1.);
		-- y runs 0..1, convert to angle -PI_2..PI_2:
		double el = M_PI * 0.5 * (y*2.-1.);
		-- convert polar to normal:
		double x1 = sin(az);
		double y1 = sin(el);
		double z1 = cos(az);
		Vec3d v(x1, y1, z1);
		v.normalize();
		mMapMesh.texCoord	( v );
		mMapMesh.vertex	( x, y, 0);
	}
--]]

setmetatable(m, {
	__call = function(_, resolution) 
		resolution = resolution or 1024
		return setmetatable({
			fbo = 0,
			rbo = 0,
			tex = 0,
			dim = resolution,
		}, m)
	end,
})

return m