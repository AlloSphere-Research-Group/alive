local ffi = require "ffi"
local avm = require "avm"
local gl = require "gl"
local glutils = require "gl.utils"
local Shader = require "gl.Shader"

local vec = require "vec"
local vec3, quat = vec.vec3, vec.quat
local nav = require "nav"
local field = require "field"
local isosurface = require "isosurface"

local random = math.random
local srandom = function() return random()*2-1 end
local rad, deg = math.rad, math.deg
local min, max = math.min, math.max
local sin, cos = math.sin, math.cos
local ceil, floor = math.ceil, math.floor
local pi = math.pi

-- currently just one window:
local win = avm.window
local audio = avm.audio
audio.clear()

if updating == nil then
	updating = true
end

world = world or {
	dim = vec3(32, 32, 32),
	nav = nav(),
	active_origin = vec3(0, 0, 0),	
	infinite = true,
	ambient_color = vec3(
		0.3 + 0.1*srandom(), 
		0.3 + 0.1*srandom(), 
		0.3 + 0.1*srandom()
	),
}
world.dimhalf = world.dim/2
world.nav.pos = world.dimhalf:clone()

sugar = sugar or field(world.dim)

sugariso = sugariso or isosurface(world.dim.x)
sugariso.level = 0.1

local agents = {}
for i = 1, 50 do
	local agent = {
		id = i,
		sugar = 0,
	}
	agent.nav = nav()
	agent.nav.color:set( 
		max(0, sin(pi * 1/3 + i/10 * pi * 2)), 
		max(0, sin(pi * 2/3 + i/10 * pi * 2)), 
		max(0, sin(           i/10 * pi * 2))
	)
	agent.nav.pos:set( srandom(), srandom(), srandom() )
	agent.nav.pos:mul(world.dim / 2)
	agent.nav.pos:add(world.nav.pos)

	local s = 0.1
	agent.nav.scale:set( 2*s, 2*s, s * 3 )
	agent.nav.quat:fromEuler(srandom(), srandom(), srandom())
	
	-- attach a sound:
	agent.sound = {
		id = i
	}
	
	-- tell audio:
	audio.voice(agent.id)
	audio.pos(agent.nav.pos, agent.id)
	
	-- TODO: install gc hander to send C.AUDIO_VOICE_FREE
	
	agents[i] = agent
end

audio.start()

local t = 0.1
local nav_move = vec3(t, t, -t)
local t = math.pi * 0.01
local nav_turn = vec3(t, t, t)
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
		world.nav.pos = world.dimhalf:clone()
		world.nav.quat:identity()
	end,
	
	[32] = function()
		updating = not updating
	end,
	
	[string.byte("n")] = function() 
		sugar:noise(0.000001)
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

function win:key(e, k)	
	if e == "down" then
		if keydown[k] then
			keydown[k]()
		elseif k == 27 then
			win.fullscreen = not win.fullscreen
		else
			print("unhandled key down", e, k)
		end
	else
		if keyup[k] then
			keyup[k]()
		else
			print("unhandled key up", e, k)
		end
	end
end

function win:mouse(e, b, x, y)
	--print(e, b, x, y)
end

function win:resize(w, h)
	print("resize", w, h)
end

local vs = [[
#version 110

//attribute vec3 position;
//attribute vec3 normal;
//attribute vec4 color;
attribute vec4 rotate;
attribute vec3 translate;
attribute vec3 scale;

uniform float far;

varying vec4 C;
varying vec3 N;
varying float F;

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
	vec3 position = gl_Vertex.xyz;
	vec3 P = translate + quat_rotate(rotate, position * scale);

	gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * vec4(P, 1.);
	
	// fog effect
	float dist = gl_Position.z / far;
	F = 1.-pow(dist, 4.);
	
	N = quat_rotate(rotate, gl_NormalMatrix * gl_Normal);	// normal
	C = gl_Color;	// color
}
]]

local fs = [[
#version 110

uniform vec3 ambient;

varying vec4 C;
varying vec3 N;
varying float F;

void main() {
	
	vec3 L = vec3(1, 1, -1);
	float l = max(0., dot(N, L));
	
	vec3 color = ambient + C.rgb*l;
	
	gl_FragColor = vec4(color, C.a*F) + vec4(0.5);
}
]]

local phong = Shader(vs, fs)

local vertices = ffi.new("vec3f[?]", 12, { 
	-- under:
	{ 0, 0, -1 },
	{ -0.5, 0, 0.5 },
	{ 0.5, 0, 0.5 },
	
	-- back:
	{ 0, 0.5, 0.5 },
	{ 0.5, 0, 0.5 },
	{ -0.5, 0, 0.5 },
		
	-- right:
	{ 0, 0.5, 0.5 },
	{ 0, 0, -1 },
	{ 0.5, 0, 0.5 },
		
	-- left:
	{ -0.5, 0, 0.5 },
	{ 0, 0, -1 },
	{ 0, 0.5, 0.5 },
})

local normals = ffi.new("vec3f[?]", 12)
-- auto face normals:
for i = 0, 11, 3 do
	local n = vertices[i]:normal(
		vertices[i+1],
		vertices[i+2]
	)
	for v = 0, 2 do
		normals[i+v] = n
	end
end

function win:create()
	-- create shaders, buffers, textures etc. here
	gl.ClearColor(world.ambient_color.x, world.ambient_color.y, world.ambient_color.z)
	
	-- create shader:
	phong:create()

	-- initialize GL settings:
	gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)
	gl.Enable(gl.CULL_FACE)
	gl.CullFace(gl.BACK)
	gl.Enable(gl.DEPTH_TEST)
	gl.Disable(gl.BLEND)

end

function win:visible(state)
	print("visible", state)
end

function update()

	-- update field:
	sugar:decay(0.99)
	-- diffuse:
	sugar:diffuse(0.01)
	-- clip:
	--sugar:min(2)

	-- update all agents:
	for i, agent in ipairs(agents) do
		local nav = agent.nav
		
		-- user-defined:
		if i <= 3 then
			-- write to field:
			sugar:overdub(nav.pos, 1)
			
			nav.color:set(0, 0.3, 1)
			nav.move:set(0, 0, 0.02*i)
			nav.turn:set(0.2*srandom(), 0.2*sin(audio.time * 0.001), 0)
		else
		
			-- read field:
			local f = sugar:sample(nav.pos)
			
			nav.move:set(0, 0, 0.2)
			
			local df = f - agent.sugar
			if df < 0 then
				local ft = 1
				nav.turn = nav.turn:lerp(
					vec3(srandom()*pi*ft, srandom()*pi*ft, srandom()*pi*ft),
					0.1)
				nav.color:set(f, 0.1, 0.1)
			else
				nav.turn = nav.turn:lerp(
					vec3(0, 0, 0),
					0.3)
			end
				nav.color:set(0.1+f*f*100, 0.1, 0.1)
			
			-- remember:
			agent.sugar = f --agent.sugar + 0.1*(f - agent.sugar)
		end
		
		-- standard pipeline:
		nav:step()
		
		-- calculate position in 'active' space:
		nav.apos = world.active_origin + ((nav.pos - world.active_origin) %world.dim)
		-- wrap into active space:
		nav.pos = nav.apos
		-- (else mark as inactive?)
		
		-- update audio:
		audio.pos(nav.pos, agent.id)	
	end
end

function win:draw()
	
	-- update navigation:
	world.nav:step()
	world.active_origin = world.nav.pos:clone():sub(world.dimhalf):map(floor)
				
	audio.pos(world.nav.pos)
	audio.quat(world.nav.quat)
	
	sugariso:generate(sugar.data, world.active_origin.x, world.active_origin.y, world.active_origin.z)
	
	if updating then
		update()
	else
		for i, agent in ipairs(agents) do
			local nav = agent.nav
			-- calculate position in 'active' space:
			nav.apos = world.active_origin + ((nav.pos - world.active_origin) %world.dim)
			-- wrap into active space:
			nav.pos = nav.apos
			-- (else mark as inactive?)
			
			-- update audio:
			audio.pos(nav.pos, agent.id)
		end
	end
	
	-- RENDERING --
	
	gl.Clear(gl.COLOR_BUFFER_BIT, gl.DEPTH_BUFFER_BIT)
	gl.Viewport(0, 0, self.width, self.height)
	
	gl.MatrixMode(gl.PROJECTION)
	gl.LoadMatrix(glutils.perspective(90, self.width/self.height, 0.1, 100))
	
	local q = world.nav.quat
	gl.MatrixMode(gl.MODELVIEW)
	gl.LoadMatrix(glutils.lookat(
		world.nav.pos,
		world.nav.pos - q:uz(),
		q:uy()
	))
	
	gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)
	
	phong:bind()
	phong:uniform("far", 64)
	
	-- draw agents:
	gl.EnableClientState(gl.VERTEX_ARRAY)
	gl.EnableClientState(gl.NORMAL_ARRAY)
	
	gl.VertexPointer(3, gl.FLOAT, 0, vertices)
	gl.NormalPointer(gl.FLOAT, 0, normals)	
	for i, agent in ipairs(agents) do
		local nav = agent.nav
		
		phong:attribute("scale", nav.scale.x, nav.scale.y, nav.scale.z)
		phong:attribute("rotate", nav.quat.x, nav.quat.y, nav.quat.z, nav.quat.w)
		phong:attribute("translate", nav.pos.x, nav.pos.y, nav.pos.z)
		
		gl.Color(nav.color.x, nav.color.y, nav.color.z, 1)
		
		gl.DrawArrays(gl.TRIANGLES, 0, 12)
	end
	
	phong:attribute("scale", world.dim.x, world.dim.y, world.dim.z)
	phong:attribute("rotate", 0, 0, 0, 1)
	phong:attribute("translate", world.active_origin.x, world.active_origin.y, world.active_origin.z)
	gl.Color(1, 1, 1)

	gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)
	gl.VertexPointer(3, gl.FLOAT, 0, sugariso:vertices())
	gl.NormalPointer(gl.FLOAT, 0, sugariso:normals())	
	gl.DrawElements(
		gl.TRIANGLES, 
		sugariso:num_indices(), 
		gl.UNSIGNED_INT, 
		sugariso:indices()
	)
	
	gl.DisableClientState(gl.VERTEX_ARRAY)
	gl.DisableClientState(gl.NORMAL_ARRAY)
	
	phong:unbind()
end
