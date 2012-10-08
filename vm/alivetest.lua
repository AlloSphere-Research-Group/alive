-- force reload:
--for k, v in pairs(package.loaded) do package.loaded[k] = nil end

local ffi = require "ffi"
local C = ffi.C
local alive = require "ffi.alive"
local gl = require "ffi.gl"
local glutils = require "ffi.gl.utils"
local Shader = require "ffi.gl.Shader"
local Isosurface = require "ffi.Isosurface"
local al = require "ffi.al"
local Vec3f, Quatf = al.Vec3f, al.Quatf

local random = math.random
local srandom = function() return random()*2-1 end
local rad, deg = math.rad, math.deg
local min, max = math.min, math.max
local sin, cos = math.sin, math.cos
local ceil, floor = math.ceil, math.floor
local pi = math.pi

local start = os.time()
local updating = true

local Field = {}
Field.__index = Field
setmetatable(Field, {
	__call = function(_, dim)
		local size = dim.x * dim.y * dim.z
		local stridey = dim.x
		local stridez = stridey * dim.y
		return setmetatable({
			dim = dim,
			size = size,
			stride = Vec3f(1, stridey, stridez),
			data = ffi.new("float[?]", size),
			back = ffi.new("float[?]", size),
		}, Field)
	end
})

function Field:index(x, y, z)
	return (x % self.dim.x)*self.stride.x 
		 + (y % self.dim.y)*self.stride.y 
		 + (z % self.dim.z)*self.stride.z
end

function Field:index_nocheck(x, y, z)
	return x*self.stride.x 
		 + y*self.stride.y 
		 + z*self.stride.z
end

function Field:sample(vec)
	local v = vec % self.dim
	local a = v:clone():map(floor)
	local b = (a + 1) % self.dim
	local bf = v - a
	local af = 1 - bf
	-- get the interpolation corner weights:
	local faaa = af.x * af.y * af.z
	local faab = af.x * af.y * bf.z
	local faba = af.x * bf.y * af.z
	local fabb = af.x * bf.y * bf.z
	local fbaa = bf.x * af.y * af.z
	local fbab = bf.x * af.y * bf.z
	local fbba = bf.x * bf.y * af.z
	local fbbb = bf.x * bf.y * bf.z
	-- get the cell for each neighbor:
	local paaa = self:index_nocheck(a.x, a.y, a.z);
	local paab = self:index_nocheck(a.x, a.y, b.z);
	local paba = self:index_nocheck(a.x, b.y, a.z);
	local pabb = self:index_nocheck(a.x, b.y, b.z);
	local pbaa = self:index_nocheck(b.x, a.y, a.z);
	local pbab = self:index_nocheck(b.x, a.y, b.z);
	local pbba = self:index_nocheck(b.x, b.y, a.z);
	local pbbb = self:index_nocheck(b.x, b.y, b.z);
	-- for each plane of the field, do the 3D interp:
	--for (size_t p=0; p<header.components; p++) {
		return		self.data[paaa] * faaa +
					self.data[pbaa] * fbaa +
					self.data[paba] * faba +
					self.data[paab] * faab +
					self.data[pbab] * fbab +
					self.data[pabb] * fabb +
					self.data[pbba] * fbba +
					self.data[pbbb] * fbbb;
	--}
end

function Field:overdub(vec, value)
	local v = vec % self.dim
	local a = v:clone():map(floor)
	local b = (a + 1) % self.dim
	local bf = v - a
	local af = 1 - bf
	-- get the interpolation corner weights:
	local faaa = af.x * af.y * af.z
	local faab = af.x * af.y * bf.z
	local faba = af.x * bf.y * af.z
	local fabb = af.x * bf.y * bf.z
	local fbaa = bf.x * af.y * af.z
	local fbab = bf.x * af.y * bf.z
	local fbba = bf.x * bf.y * af.z
	local fbbb = bf.x * bf.y * bf.z
	-- get the cell for each neighbor:
	local paaa = self:index_nocheck(a.x, a.y, a.z);
	local paab = self:index_nocheck(a.x, a.y, b.z);
	local paba = self:index_nocheck(a.x, b.y, a.z);
	local pabb = self:index_nocheck(a.x, b.y, b.z);
	local pbaa = self:index_nocheck(b.x, a.y, a.z);
	local pbab = self:index_nocheck(b.x, a.y, b.z);
	local pbba = self:index_nocheck(b.x, b.y, a.z);
	local pbbb = self:index_nocheck(b.x, b.y, b.z);
	-- for each plane of the field, do the 3D interp:
	--for (size_t p=0; p<header.components; p++) {
		self.data[paaa] = self.data[paaa] + value * faaa;
		self.data[pbaa] = self.data[pbaa] + value * fbaa;
		self.data[paba] = self.data[paba] + value * faba;
		self.data[paab] = self.data[paab] + value * faab;
		self.data[pbab] = self.data[pbab] + value * fbab;
		self.data[pabb] = self.data[pabb] + value * fabb;
		self.data[pbba] = self.data[pbba] + value * fbba;
		self.data[pbbb] = self.data[pbbb] + value * fbbb;
	--}
end

function Field:diffuse(diffusion, passes)
	passes = passes or 14
	
	-- swap buffers:
	self.data, self.back = self.back, self.data
	
	local optr = self.data
	local iptr = self.back
	local div = 1.0/((1.+6.*diffusion))
	
	-- Gauss-Seidel relaxation scheme:
	for n = 1, passes do
		for z = 0, self.dim.z-1 do
			for y = 0, self.dim.y-1 do
				for x = 0, self.dim.x-1 do
					local pre  =	iptr[self:index(x,	y,	z  )]
					local va00 =	optr[self:index(x-1,y,	z  )]
					local vb00 =	optr[self:index(x+1,y,	z  )]
					local v0a0 =	optr[self:index(x,	y-1,z  )]
					local v0b0 =	optr[self:index(x,	y+1,z  )]
					local v00a =	optr[self:index(x,	y,	z-1)]
					local v00b =	optr[self:index(x,	y,	z+1)]
					
					optr[self:index(x,y,z)] = div*(
						pre +
						diffusion * (
							va00 + vb00 +
							v0a0 + v0b0 +
							v00a + v00b
						)
					)
				end
			end
		end
	end
end

function Field.map(f)
	return function(self, ...)
		for z = 0, self.dim.z-1 do
			for y = 0, self.dim.y-1 do
				for x = 0, self.dim.x-1 do
					self.data[self:index(x, y, z)] = f(x, y, z, ...)
				end
			end
		end
	end
end

function Field.map_rec(f)
	return function(self, ...)
		for z = 0, self.dim.z-1 do
			for y = 0, self.dim.y-1 do
				for x = 0, self.dim.x-1 do
					local index = self:index(x, y, z)
					self.data[index] = f(self.data[index], x, y, z, ...)
				end
			end
		end
	end
end

Field.noise = Field.map(function(x, y, z)
	return random()
end)

Field.decay = Field.map_rec(function(current, x, y, z, factor)
	return current * factor
end)

Field.min = Field.map_rec(function(current, x, y, z, factor)
	return min(current, factor)
end)


local Nav = {}
Nav.__index = Nav
setmetatable(Nav, {
	__call = function(_)
		return setmetatable({
			move = Vec3f(),
			turn = Vec3f(),
			pos = Vec3f(),
			scale = Vec3f(),
			quat = Quatf():identity(),
			color = Vec3f(),
			
		}, Nav)
	end
})

world = {
	dim = Vec3f(32, 32, 32),
	nav = Nav(),
}
world.nav.pos = world.dim/2

sugar = sugar or Field(world.dim)
--sugar:noise()

sugariso = sugariso or Isosurface()
sugariso:level(0.1)

function Nav:step()
	-- standard pipeline:
	self.pos:add(			
		self.quat:ux() * self.move.x
		+ self.quat:uy() * self.move.y
		+ self.quat:uz() * -self.move.z
	)
	self.quat = self.quat * Quatf():fromEuler(self.turn.y, self.turn.x, self.turn.z)
	self.quat:normalize()
	
	-- wrap:
	self.pos = self.pos % world.dim
end


local msg = C.audioq_head()
if msg ~= nil then
	msg.cmd = C.AUDIO_CLEAR
	C.audioq_send()
end

local agents = {}
for i = 1, 50 do
	local agent = {
		id = i,
		sugar = 0,
	}
	agent.nav = Nav()
	agent.nav.color:set( 
		max(0, sin(pi * 1/3 + i/10 * pi * 2)), 
		max(0, sin(pi * 2/3 + i/10 * pi * 2)), 
		max(0, sin(           i/10 * pi * 2))
	)
	if i > 1 then
		agent.nav.pos:set( srandom(), srandom(), srandom() )
		agent.nav.pos:mul(world.dim / 2)
		agent.nav.pos:add(world.nav.pos)
	
	else
		agent.nav.pos = world.nav.pos + Vec3f(0, 0, -2)
	end
	agent.nav.scale:set( 0.2, 0.2, 0.1 * random(4) )
	agent.nav.quat:fromEuler(srandom(), srandom(), srandom())
	
	-- attach a sound:
	agent.sound = {
		id = i
	}
	local msg = C.audioq_head()
	if msg ~= nil  then
		msg.cmd = C.AUDIO_VOICE_NEW
		msg.id = i
		C.audioq_send()
	end
	local msg = C.audioq_head()
	if msg ~= nil then
		msg.cmd = C.AUDIO_VOICE_POS
		msg.id = i
		msg.x = agent.nav.pos.x
		msg.y = agent.nav.pos.y
		msg.z = agent.nav.pos.z
		C.audioq_send()
	end
	-- TODO: install gc hander to send C.AUDIO_VOICE_FREE
	
	agents[i] = agent
end

local t = 0.1
local nav_move = Vec3f(t, t, -t)
local t = math.pi * 0.01
local nav_turn = Vec3f(t, t, t)
local keydown = {
	[44]  = function() world.nav.move.x =  nav_move.x end,
	[46]  = function() world.nav.move.x = -nav_move.x end,
	[39]  = function() world.nav.move.y =  nav_move.y end,
	[47]  = function() world.nav.move.y = -nav_move.y end,
	[270] = function() world.nav.move.z = -nav_move.z end,
	[272] = function() world.nav.move.z =  nav_move.z end,
	
	[120] = function() world.nav.turn.x = -nav_turn.x end,
	[119] = function() world.nav.turn.x =  nav_turn.x end,
	[271] = function() world.nav.turn.y =  nav_turn.y end,
	[269] = function() world.nav.turn.y = -nav_turn.y end,
	[97]  = function() world.nav.turn.z = -nav_turn.z end,
	[100] = function() world.nav.turn.z =  nav_turn.z end,
	
	[96] = function()
		world.nav.pos = world.dim / 2
		world.nav.quat = Quatf:identity()
	end,
}

local keyup = {
	[44]  = function() world.nav.move.x = 0 end,
	[46]  = function() world.nav.move.x = 0 end,
	[39]  = function() world.nav.move.y = 0 end,
	[47]  = function() world.nav.move.y = 0 end,
	[270] = function() world.nav.move.z = 0 end,
	[272] = function() world.nav.move.z = 0 end,
	
	[119] = function() world.nav.turn.x = 0 end,
	[120] = function() world.nav.turn.x = 0 end,
	[271] = function() world.nav.turn.y = 0 end,
	[269] = function() world.nav.turn.y = 0 end,
	[97]  = function() world.nav.turn.z = 0 end,
	[100] = function() world.nav.turn.z = 0 end,
}

function alive:onKey(e, k)
	if e == "down" then
		if keydown[k] then
			keydown[k]()
		elseif k == 27 then
			self:fullscreen(not self:fullscreen())
		elseif k == 32 then
			updating = not updating
		else
			print(e, k)
		end
	elseif e == "up" then
		if keyup[k] then
			keyup[k]()
		else
			print(e, k)
		end
	end
end

function trinormal(a, b, c)
	local v1 = b - a
	local v2 = c - b
	local n = v1:cross(v2)
	return n:normalize()
end

local vertexbuffer = 0 
local normalbuffer = 0 

local shaderprogram = 0
local shaderprogram_position = 0
local shaderprogram_normal = 0
local shaderprogram_translate = 0
local shaderprogram_rotate = 0
local shaderprogram_scale = 0

vs = [[
#version 110

attribute vec3 position;
attribute vec3 normal;

attribute vec4 rotate;
attribute vec3 translate;
attribute vec3 scale;
attribute vec3 color;

varying vec3 C;
varying vec3 N;

//	q must be a normalized quaternion
vec3 quat_rotate(vec4 q, vec3 v) {
	// qv = vec4(v, 0) // 'pure quaternion' derived from vector
	// return ((q * qv) * q^-1).xyz
	// reduced to 24 multiplies and 17 additions:
	vec4 p = vec4(
		q.w*v.x + q.y*v.z - q.z*v.y,	// x
		q.w*v.y + q.z*v.x - q.x*v.z,	// y
		q.w*v.z + q.x*v.y - q.y*v.x,	// z
		-q.x*v.x - q.y*v.y - q.z*v.z	// w
	);
	return vec3(
		p.x*q.w - p.w*q.x + p.z*q.y - p.y*q.z,	// x
		p.y*q.w - p.w*q.y + p.x*q.z - p.z*q.x,	// y
		p.z*q.w - p.w*q.z + p.y*q.x - p.x*q.y	// z
	);
}

void main() {
	vec3 V = position.xyz;
	vec3 P = translate + quat_rotate(rotate, V * scale);
	gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * vec4(P, 1.);
	N = normal;
	C = color;
}
]]

fs = [[
#version 110

varying vec3 C;
varying vec3 N;

void main() {
	
	vec3 L = vec3(1, 1, -1);
	float l = max(0., dot(N, L));
	
	vec3 color = mix(vec3(0.5), C, l+0.2);

    gl_FragColor = vec4(color, 1);
}
]]


local program = Shader(vs, fs)

local vertices = ffi.new("Vec3f[?]", 12, { 
	{ 0, 0, -1 },
	{ 0.5, 0, 0.5 },
	{ -0.5, 0, 0.5 },
	
	{ 0, 0.5, 0.5 },
	{ 0.5, 0, 0.5 },
	{ -0.5, 0, 0.5 },
		
	{ 0, 0.5, 0.5 },
	{ 0, 0, -1 },
	{ 0.5, 0, 0.5 },
		
	{ -0.5, 0, 0.5 },
	{ 0, 0.5, 0.5 },
	{ 0, 0, -1 },
})

local normals = ffi.new("Vec3f[?]", 12)
for i = 0, 3 do
	local n = trinormal(
		vertices[i*3],
		vertices[i*3+1],
		vertices[i*3+2]
	)
	for v = 0, 2 do
		normals[i*3+v] = n
	end
end


function make_array_buffer(ptr, size)
	local id = gl.GenBuffers(1)
	gl.BindBuffer(gl.ARRAY_BUFFER, id)
	-- STATIC, STREAM (regularly replace en-masse), DYNAMIC (regularly modify)
	gl.BufferData(gl.ARRAY_BUFFER, size, ptr, gl.STREAM_DRAW)
	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	return id
end	

function updateWorld()

	-- update field:
	sugar:decay(0.99)
	-- diffuse:
	sugar:diffuse(0.01)
	-- clip:
	--sugar:min(2)
	-- update iso:
	sugariso:generate(sugar.data, sugar.dim.x)
	
	-- update all agents:
	for i, agent in ipairs(agents) do
		local nav = agent.nav
		
		-- user-defined:
		if i <= 3 then
			
			-- write to field:
			sugar:overdub(nav.pos, 1)
			
			nav.color:set(0, 0.3, 1)
			nav.move:set(0, 0, 0.02*i)
			nav.turn:set(0.2*srandom(), 0.2*sin(C.audio_time() * 0.001), 0)
		else
		
			-- read field:
			local f = sugar:sample(nav.pos)
			
			
			nav.move:set(0, 0, 0.2)
			
			local df = f - agent.sugar
			if df < 0 then
				local ft = 1
				nav.turn = nav.turn:lerp(
					Vec3f(srandom()*pi*ft, srandom()*pi*ft, srandom()*pi*ft),
					0.1)
				nav.color:set(f, 0.1, 0.1)
			else
				nav.turn = nav.turn:lerp(
					Vec3f(0, 0, 0),
					0.3)
			end
				nav.color:set(0.1+f*f*100, 0.1, 0.1)
			
			-- remember:
			agent.sugar = f --agent.sugar + 0.1*(f - agent.sugar)
		end
		
		-- standard pipeline:
		nav:step()
		
		local msg = C.audioq_head()
		if msg ~= nil then
			msg.cmd = C.AUDIO_VOICE_POS
			msg.id = i
			msg.x = agent.nav.pos.x
			msg.y = agent.nav.pos.y
			msg.z = agent.nav.pos .z
			C.audioq_send()
		end
		
	end
end

function draw(w, h, q)
	gl.Clear()
	
	gl.MatrixMode(gl.PROJECTION)
	gl.LoadMatrix(glutils.perspective(90, w/h, 0.1, 100))
	
	q = world.nav.quat * q
	
	gl.MatrixMode(gl.MODELVIEW)
	gl.LoadMatrix(glutils.lookat(
		world.nav.pos,
		world.nav.pos - q:uz(),
		q:uy()
	))
	
	gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)
	gl.CullFace(gl.BACK)
	gl.Enable(gl.DEPTH_TEST)
	
	--print(shaderprogram)
	--gl.UseProgram(shaderprogram)
	program:bind()
	
	-- map buffers:
	gl.BindBuffer(gl.ARRAY_BUFFER, vertexbuffer)
	gl.EnableVertexAttribArray(program.attributes.position.loc)
	gl.VertexAttribPointer(
		program.attributes.position.loc,  -- attribute
		3, -- size
		gl.FLOAT, -- type
		gl.FALSE, -- normalized
		ffi.sizeof("GLfloat")*3, -- stride
		ffi.cast("void *", 0)  -- offset
	)
	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	
	gl.BindBuffer(gl.ARRAY_BUFFER, normalbuffer)
	gl.EnableVertexAttribArray(program.attributes.normal.loc)
	gl.VertexAttribPointer(
		program.attributes.normal.loc,  -- attribute
		3, -- size
		gl.FLOAT, -- type
		gl.FALSE, -- normalized
		ffi.sizeof("GLfloat")*3, -- stride
		ffi.cast("void *", 0)  -- offset
	)
	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	
	-- draw all agents:
	for i, agent in ipairs(agents) do
		local nav = agent.nav
		
		program:attribute("scale", nav.scale.x, nav.scale.y, nav.scale.z)
		program:attribute("rotate", nav.quat.x, nav.quat.y, nav.quat.z, nav.quat.w)
		program:attribute("translate", nav.pos.x, nav.pos.y, nav.pos.z)
		program:attribute("color", nav.color.x, nav.color.y, nav.color.z)
		
		gl.DrawArrays(gl.TRIANGLES, 0, 12)
	end
	
	--gl.DisableVertexAttribArray(shaderprogram_position)
	gl.DisableVertexAttribArray(program.attributes.position.loc)
	gl.DisableVertexAttribArray(program.attributes.normal.loc)
	
	program:attribute("scale", world.dim.x, world.dim.y, world.dim.z)
	program:attribute("rotate", 0, 0, 0, 1)
	program:attribute("translate", 0, 0, 0)
	program:attribute("color", 1, 1, 1)
	
	gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)
	sugariso:draw()
	
	--gl.UseProgram(0)
	program:unbind()
end


local created = false
local frame = 0
function alive:onFrame(w, h)
	frame = frame + 1
	
	if not created then
		gl.ClearColor(
			0.3 + 0.1*srandom(), 
			0.3 + 0.1*srandom(), 
			0.3 + 0.1*srandom()
		)
		
		program:create()
	
		local vsid = gl.CreateShader(gl.VERTEX_SHADER, vs)
		local fsid = gl.CreateShader(gl.FRAGMENT_SHADER, fs)
		
		shaderprogram = gl.CreateProgram()
		assert(shaderprogram > 0, "failed to create program")
		gl.AttachShader(shaderprogram, vsid)
		gl.AttachShader(shaderprogram, fsid)
		
		-- link:
		gl.LinkProgram(shaderprogram)
		gl.DetachShader(shaderprogram, vsid)
		gl.DetachShader(shaderprogram, fsid)
		
		-- TODO: read uniforms/attrs here
		
		local status = ffi.new("GLint[1]")
		gl.GetProgramiv(shaderprogram, gl.LINK_STATUS, status)
		if status[0] == gl.FALSE then
			local infoLogLength = ffi.new("GLint[1]")
			gl.GetProgramiv(shaderprogram, gl.INFO_LOG_LENGTH, infoLogLength)
			local strInfoLog = ffi.new("GLchar[?]", infoLogLength[0] + 1)
			gl.GetProgramInfoLog(shaderprogram, infoLogLength[0], nil, strInfoLog)
			gl.DeleteProgram(shaderprogram)
			error("gl.LinkProgram " .. ffi.string(strInfoLog))
		end
		
		-- cleanup:
		gl.DeleteShader(vsid)
		gl.DeleteShader(fsid)
		
		--shaderprogram = gl.CreateProgram(vsid, fsid)
		
		gl.UseProgram(shaderprogram)
		shaderprogram_position = gl.GetAttribLocation(shaderprogram, "position")
		shaderprogram_normal = gl.GetAttribLocation(shaderprogram, "normal")

		shaderprogram_rotate = gl.GetAttribLocation(shaderprogram, "rotate")
		shaderprogram_translate = gl.GetAttribLocation(shaderprogram, "translate")
		shaderprogram_scale = gl.GetAttribLocation(shaderprogram, "scale")
		gl.UseProgram(0)
		print(vsid, fsid, shaderprogram, shaderprogram_position)
		
		
		vertexbuffer = make_array_buffer(vertices, ffi.sizeof("Vec3f") * 12)
		normalbuffer = make_array_buffer(normals, ffi.sizeof("Vec3f") * 12)
		
		created = true
	end
	
	world.nav:step()
	msg = C.audioq_head()
	if msg ~= nil then
		msg.cmd = C.AUDIO_POS
		msg.x = world.nav.pos.x
		msg.y = world.nav.pos.y
		msg.z = world.nav.pos.z
		C.audioq_send()
	end
	msg = C.audioq_head()
	if msg ~= nil then
		msg.cmd = C.AUDIO_QUAT
		msg.x = world.nav.quat.x
		msg.y = world.nav.quat.y
		msg.z = world.nav.quat.z
		msg.w = world.nav.quat.w
		C.audioq_send()
	end
	
	if updating then
		updateWorld()
	end	
	

	local h2 = h/2
	gl.Enable(gl.SCISSOR_TEST)
	
	gl.Viewport(0, 0, w, h2)
	gl.Scissor(0, 0, w, h2)
	draw(w, h2, Quatf():fromAxisY(math.pi))
	
	gl.Viewport(0, h2, w, h2)
	gl.Scissor(0, h2, w, h2)
	draw(w, h2, Quatf():identity())
	
	if frame % 100 == 1 then
		print("fps", self:fpsAvg())
	end
end

print("ok")