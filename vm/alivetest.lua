-- force reload:
--for k, v in pairs(package.loaded) do package.loaded[k] = nil end

local ffi = require "ffi"
local alive = require "ffi.alive"
local gl = require "ffi.gl"
local Shader = require "ffi.gl.Shader"
local al = require "ffi.al"
local Vec3f, Quatf = al.Vec3f, al.Quatf

local random = math.random
local srandom = function() return random()*2-1 end
local rad, deg = math.rad, math.deg

local start = os.time()

local updating = true

local function Nav()
	local self = {
		pos = Vec3f(),
		scale = Vec3f(),
		quat = Quatf(),
		color = Vec3f(),
	}
	
	return self
end

local agents = {}
for i = 1, 100 do
	local agent = {}
	agent.nav = Nav()
	agent.nav.color:set( random(), random(), random() )
	agent.nav.pos:set( srandom(), srandom(), srandom() )
	agent.nav.scale:set( 0.05 )
	agent.nav.quat:fromEuler(srandom(), srandom(), srandom())
	agents[i] = agent
end

function alive:onKey(e, k)
	if e == "down" then
		if k == 27 then
			self:fullscreen(not self:fullscreen())
		elseif k == 32 then
			updating = not updating
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
	gl_Position = gl_ModelViewProjectionMatrix * vec4(P, 1.);
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
	
	vec3 color = 0.2 + C * l * 0.8;

    gl_FragColor = vec4(color, 1);
}
]]


local program = Shader(vs, fs)

local vertices = ffi.new("Vec3f[?]", 12, { 
	{ 0, 0, -1 },
	{ 1, 0, 1 },
	{ -1, 0, 1 },
	
	{ 0, 1, 1 },
	{ 1, 0, 1 },
	{ -1, 0, 1 },
		
	{ 0, 1, 1 },
	{ 0, 0, -1 },
	{ 1, 0, 1 },
		
	{ -1, 0, 1 },
	{ 0, 1, 1 },
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
	-- update all agents:
	for i, agent in ipairs(agents) do
		agent.nav.pos:add(agent.nav.quat:uf() * agent.nav.scale.z * 0.5)
		agent.nav.quat:mul(Quatf():fromEuler(0.1, 0, 0))
	end
end

function draw()
	gl.ClearColor(0.5, 0.3, 0, 1)
	gl.Clear()
	--gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)
	gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)
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
	
	--gl.UseProgram(0)
	program:unbind()
end


local created = false
function alive:onFrame(w, h)
	if not created then
	
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
		
		-- read uniforms/attrs here
		
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

	if updating then
		updateWorld()
	end	

	local h2 = h/2
	gl.Enable(gl.SCISSOR_TEST)
	
	gl.Viewport(0, 0, w, h2)
	gl.Scissor(0, 0, w, h2)
	draw()
	
	gl.Viewport(0, h2, w, h2)
	gl.Scissor(0, h2, w, h2)
	draw()
end

print("ok")