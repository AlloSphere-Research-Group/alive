local ffi = require "ffi"
local C = ffi.C
local avm = require "av"
local gl = require "gl"
local glutils = require "gl.utils"
local Shader = require "gl.Shader"
local Texture = require "gl.Texture"
local cubefbo = require "gl.cubefbo"

local vec = require "vec"
local vec3, quat = vec.vec3, vec.quat
local nav = require "nav"
local field = require "field"
local isosurface = require "av.isosurface"
local image = require "av.image"

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

phong = phong or dofile("phong.lua")
pointsprite = pointsprite or dofile("pointsprite.lua")
sprite = Texture("tex01.png")

numstalks = numstalks or 0

local activestalks = {}
local stalk_length = 1
local stalk_spring = 1
local stalk_friction = .15 --.1
local stalk_flow = 5
local stalk_fluid_push = 5
local stalk_move_xfade = 0.02
local stalk_damping = 0.09

local
function initStalk(s, len)
	s.dpos:set(0, 0, 0)
	s.force:set(0, 0, 0)
	s.diff:set(0, 0, 0)
	activestalks[#activestalks+1] = s
	for i = 1, len/2 do
	--if len > 0 then
		local b = ffi.new("Stalk")
		numstalks = numstalks + 1
		b.pos = s.pos:clone():add(
			srandom() * stalk_length,
			srandom() * stalk_length,
			srandom() * stalk_length
		)
		b.quat = s.quat:clone()
		-- attach to s:
		b.nextsibling = s.firstchild
		s.firstchild = b
		
		initStalk(b, random(len-1) )
	end
	return s
end

if not shared then
	header = [[
	
	static const int NUM_PARTICLES = 2000;
	static const int NUM_STALK_ROOTS = 15;
	
	enum {
		THING_CELL = 0,
		THING_STALK
	};
	
	typedef struct Particle {
		vec3f pos;
		vec3f color;
	} Particle; 
	
	typedef struct Stalk {
		int isroot;
		quat quat;
		vec3 pos;
		float len;
		vec3 dpos;
		vec3 force;
		vec3 diff;	// vector relative to parent
		vec3 color;
		
//		bool hasDust, isDead, isRoot;
//		int growth;
//		vec gene;

		// tree structure:
		struct Stalk * firstchild;
		struct Stalk * nextsibling;
	} Stalk;
	
	typedef struct Shared {
		Particle particles[NUM_PARTICLES];
		Stalk stalkroots[NUM_STALK_ROOTS];
	} Shared; 
	]]
	
	ffi.cdef(header)
	
	shared = ffi.new("Shared")
	
	for i = 0, C.NUM_PARTICLES-1 do
		local p = shared.particles[i]
		p.pos.x = random() * 32 
		p.pos.y = random() * 32
		p.pos.z = random() * 32
		
		p.color:set(
			random() * 2,
			random() * 1,
			random() * 0.5
		)	
	end
	
	for i = 0, C.NUM_STALK_ROOTS-1 do
		local s = shared.stalkroots[i]
		s.nextsibling = nil
		s.firstchild = nil
		s.isroot = 1
		
		s.len = stalk_length
		
		s.pos:set(
			random() * world.dim.x,
			random() * world.dim.y,
			random() * world.dim.z
		)
		s.quat:fromEuler(
			random() * pi,
			random() * pi,
			random() * pi
		)
		-- create branches:
		initStalk(s, 6)
	end
	print(#activestalks, "stalks")
end
local particles_stride = ffi.sizeof("Particle")
local particles_ptr = ffi.cast("char *", shared.particles)
local particles_pos = ffi.cast("GLvoid *", particles_ptr + ffi.offsetof("Particle", "pos"))
local particles_color = ffi.cast("GLvoid *", particles_ptr + ffi.offsetof("Particle", "color"))

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



function win:create()
	-- create shaders, buffers, textures etc. here
	
	-- create shader:
	phong:create()
	
	-- create tube displaylist:
	if tubelist then gl.DeleteLists(tubelist) end
	tubelist = gl.GenLists()
	gl.NewList(tubelist, gl.COMPILE)
		-- draw tube here
		local radius = 1
		local columns = 6
		gl.Begin(gl.QUAD_STRIP)
		for i = 0, columns do
			local angle = pi * 2 * i/columns
			local x = radius * cos(angle)
			local y = radius * sin(angle)
			gl.Normal3d(-sin(angle), -cos(angle), 0)
			gl.Vertex3d(x, y, 0)
			gl.Vertex3d(x, y, 1)
		end
		gl.End()
	gl.EndList()
end

function win:visible(state)
	print("visible", state)
end

function update()

	-- update stalks:
	for i = 1, #activestalks do
		local s = activestalks[i]
		--s.hasDust = 0;
		
		-- for a smoother movement, so similar to dust:
		-- dpos is only gradually affected by the forces
		-- in this case, the forces are the local flow plus the branch tensions

		-- assume force was calculated on previous frame
		-- add field flow to force
		---[[
		local flow = vec3(
			srandom(),
			srandom(),
			srandom()
		)
		--fluid->getFlow(a->pos, flow);
		flow:mul(stalk_flow * 0.1)
		s.force:add(flow)
		--]]
		
		-- gradually apply to object
		s.dpos = vec3.lerp(s.dpos, s.force, stalk_move_xfade);
		
		s.pos:add(s.dpos)
		s.dpos:mul(stalk_damping)
		s.force:set(0, 0, 0)
		
		-- stay within the region:
		s.pos:sub(world.active_origin)
			 :mod(world.dim)
			 :add(world.active_origin)

		
		local b = s.firstchild
		while b ~= nil do
			-- cache relative position from parent:
			b.diff = (b.pos - s.pos)
			b.len = b.diff:mag()
			
			local change = b.diff:normalized()
			
			--[[
				maybe this whole idea was wrong from the start.
			
				maybe each branch should have a 'desired' orientation relative to the parent?
				the tricky part is deriving an orientation from two points;
				it is ambiguous
				
				but the force simulation only gives us positions... 
			
			--]]
			
			-- somehow derive a quaternion that orients the z axis along -b.diff
			-- the axis to rotate around is orthogonal to b.diff and b.quat:uz()
			-- the amount to rotate is...
			--local rotate = quat():fromRotor(b.quat:uz(), -change)
			-- apply:
			--b.quat:mul(rotate):normalize()
			--b->q.toward_point(b->glvec.x, b->glvec.y, b->glvec.z, b->q, 0, 0, 0);
			--b.quat = (b.quat:towardPoint(change, vec3(0, 0, 0), 1))
			
			local rot = vec3(0, 0, -1):getRotationTo(change)
			b.quat = b.quat * rot
			
			
			
			local intensity = stalk_spring * (b.len - stalk_length)
			
			-- stretch affects color:
			b.color.x = b.color.x + 0.1 * (0.1 - b.color.x)
			b.color.y = b.color.x
			b.color.z = 1 - b.color.x*0.7
			
			-- spring forces
			local vel = s.dpos - b.dpos
			change:mul(intensity)  -- - (vel * stalk_friction);
			
			s.force:add(change)
			b.force:sub(change)
			
			-- straigtening factor:
			--local twist = b.diff:normalized():mul(0.1)
			--b.force:sub(twist)
	
			-- next branch:
			b = b.nextsibling
		end
	end

	-- update particles:
	for i = 0, C.NUM_PARTICLES-1 do
		local p = shared.particles[i]
		
		-- Brownian:
		p.pos:add{
			x = srandom() * 0.01,
			y = srandom() * 0.01,
			z = srandom() * 0.01,
		}
		
		-- wrap in active space:
		p.pos:sub(world.active_origin)
			 :mod(world.dim)
			 :add(world.active_origin)
		
	end
	
	
	-- update all agents:
	for i, agent in ipairs(agents) do
		local nav = agent.nav
		
		
		
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

function draw()
	
	-- OpenGL state:
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE)
	gl.Enable(gl.DEPTH_TEST)
	gl.DepthMask(false)
	gl.PointSize(20)
	gl.LineWidth(2)
	gl.Color(1, 1, 1)
	
	-- world.draw(w, h)
	
	phong:bind()
	phong:uniform("far", 64)
	
	-- draw phongs
	phong:attribute("scale", 1, 1, 1)
	phong:attribute("rotate", 0, 0, 0, 1)
	
	
	for i = 1, #activestalks do
		
		local s = activestalks[i]
		
		phong:attribute("translate", s.pos.x, s.pos.y, s.pos.z)
		phong:attribute("rotate", s.quat.x, s.quat.y, s.quat.z, s.quat.w)
		local branches_size = 2 -- should be #s.branches or something
		local w = stalk_length * 0.03 -- * (s.color.x)
		phong:attribute("scale", w, w, s.len) -- vec::mag(a->glvec) ??
		gl.Color(1, 1, 1, 1)
		gl.CallList(tubelist)
	end
	
	
	phong:unbind()
	
	--[[
	stalk_material:bind()
		W.drawstalks()
		gl.CallList(tubelist)
	stalk_material:unbind()
	
	--gl.LineWidth(1)
	cell_material:bind()
		W.drawcells()
	cell_material:unbind()
	--]]
	
	
	-- draw all the active dusts:
	-- TODO: fog effect
	pointsprite:bind()
	pointsprite:uniform("tex0", 0)
	pointsprite:uniform("pointSize", 0.1)
	pointsprite:uniform("viewportWidth", win.width)
	sprite:bind()
	
	gl.Enable(gl.POINT_SPRITE)
    gl.TexEnvi(gl.POINT_SPRITE, gl.COORD_REPLACE, gl.TRUE)
	
	gl.EnableClientState(gl.VERTEX_ARRAY)
	gl.EnableClientState(gl.COLOR_ARRAY) 
	
	gl.VertexPointer(3, gl.FLOAT, particles_stride, particles_pos)
	gl.ColorPointer(3, gl.FLOAT, particles_stride, particles_color)
	
	gl.Enable(gl.VERTEX_PROGRAM_POINT_SIZE)
	gl.DrawArrays(gl.POINTS, 0, C.NUM_PARTICLES)
	
	gl.DisableClientState(gl.VERTEX_ARRAY)
	gl.DisableClientState(gl.COLOR_ARRAY)
	
    gl.Disable(gl.VERTEX_PROGRAM_POINT_SIZE)
	gl.Disable(gl.POINT_SPRITE)
	sprite:unbind()
	pointsprite:unbind()
	
	gl.DepthMask(true)
end

-- TODO: stereographics
function win:draw()
	
	-- update navigation:
	world.nav:step()
	world.active_origin = world.nav.pos:clone():sub(world.dimhalf):map(floor)
				
	audio.pos(world.nav.pos)
	audio.quat(world.nav.quat)
	
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
	
	
	-- normal render style:
	gl.Enable(gl.SCISSOR_TEST)
	gl.Scissor(0, 0, self.width, self.height)
	gl.Viewport(0, 0, self.width, self.height)
	gl.ClearColor(0, 0, 0)
	gl.Clear(gl.COLOR_BUFFER_BIT, gl.DEPTH_BUFFER_BIT)
	
	gl.Enable(gl.DEPTH_TEST)
	gl.DepthMask(false)
	
	-- ordinary setup:
	gl.MatrixMode(gl.PROJECTION)
	gl.LoadMatrix(glutils.perspective(80, self.width/self.height, 1, 100))
	
	local q = world.nav.quat
	gl.MatrixMode(gl.MODELVIEW)
	gl.LoadMatrix(glutils.lookat(
		world.nav.pos,
		world.nav.pos - q:uz(),
		q:uy()
	))
	
	draw()
	
	gl.Disable(gl.SCISSOR_TEST)
end
