local min, max = math.min, math.max
local sqrt = math.sqrt
local sin, cos = math.sin, math.cos
local pi = math.pi
local random = math.random
local srandom = function() return random()*2-1 end

local ffi = require "ffi"
local C = ffi.C
require "ffi.aliveheader"
local al = require "ffi.al"
local Vec3f, Quatf = al.Vec3f, al.Quatf

print("sizeof audiomsg_packet", ffi.sizeof("audiomsg_packet"))


--	q must be a normalized quaternion
function quat_rotate(q, v)
	-- qv = vec4(v, 0) // 'pure quaternion' derived from vector
	-- return ((q * qv) * q^-1).xyz
	-- reduced to 24 multiplies and 17 additions:
	px =  q.w*v.x + q.y*v.z - q.z*v.y
	py =  q.w*v.y + q.z*v.x - q.x*v.z
	pz =  q.w*v.z + q.x*v.y - q.y*v.x
	pw = -q.x*v.x - q.y*v.y - q.z*v.z
	return Vec3f(
		px*q.w - pw*q.x + pz*q.y - py*q.z,	-- x
		py*q.w - pw*q.y + px*q.z - pz*q.x,	-- y
		pz*q.w - pw*q.z + py*q.x - px*q.y	-- z
	)
end

-- equiv. quat_rotate(quat_conj(q), v):
-- q must be a normalized quaternion
function quat_unrotate(q, v)
    -- reduced:
	px = q.w*v.x - q.y*v.z + q.z*v.y
    py = q.w*v.y - q.z*v.x + q.x*v.z
    pz = q.w*v.z - q.x*v.y + q.y*v.x
	pw = q.x*v.x + q.y*v.y + q.z*v.z
    return Vec3f(
        pw*q.x + px*q.w + py*q.z - pz*q.y,  -- x
        pw*q.y + py*q.w + pz*q.x - px*q.z,  -- y
        pw*q.z + pz*q.w + px*q.y - py*q.x   -- z
    )
end

local function mix(x, y, a) return x + a*(y-x) end

function attenuate(d, near, scale)
	local c = 2
	local x = max(0, d - near) * scale
	local xc = x + c
	local x1 = xc / (x*x + x + xc)
	return x1 * x1
end

local SQRT2 = 1.414213562373095
local c1_sqrt2	= 0.707106781186548

function encodeWeightsFuMa16(ws, x, y, z)
	local c1_sqrt2	= 0.707106781186548
	local c8_11		= 8./11.
	local c40_11	= 40./11.
	local x2 = x * x
	local y2 = y * y
	local z2 = z * z
	local pre = c40_11 * z2 - c8_11

	ws[ 1] = x						-- X = cos(A)cos(E)	
	ws[ 2] = y						-- Y = sin(A)cos(E)
	ws[ 3] = z						-- Z = sin(E)
	ws[ 4] = x2 - y2				-- U = cos(2A)cos2(E) = xx-yy
	ws[ 5] = 2. * x * y				-- V = sin(2A)cos2(E) = 2xy
	ws[ 6] = 2. * z * x				-- S = cos(A)sin(2E) = 2zx
	ws[ 7] = 2. * z * y				-- T = sin(A)sin(2E) = 2yz
	ws[ 8] = 1.5 * z2 - 0.5			-- R = 1.5sin2(E)-0.5 = 1.5zz-0.5
	ws[ 9] = x * (x2 - 3. * y2)		-- P = cos(3A)cos3(E) = X(X2-3Y2)
	ws[10] = y * (y2 - 3. * x2)		-- Q = sin(3A)cos3(E) = Y(3X2-Y2)
	ws[11] = z * (x2 - y2) * 0.5	-- N = cos(2A)sin(E)cos2(E) = Z(X2-Y2)/2
	ws[12] = x * y * z				-- O = sin(2A)sin(E)cos2(E) = XYZ
	ws[13] = pre * x				-- L = 8cos(A)cos(E)(5sin2(E) - 1)/11 = 8X(5Z2-1)/11
	ws[14] = pre * y				-- M = 8sin(A)cos(E)(5sin2(E) - 1)/11 = 8Y(5Z2-1)/11
	ws[15] = z * (2.5 * z2 - 1.5)	-- K = sin(E)(5sin2(E) - 3)/2 = Z(5Z2-3)/2
end

local speakers = {}
local s = {
	direction = Vec3f(-1, 0, -1):normalize(),
	weights = { [0]=c1_sqrt2 },
}
encodeWeightsFuMa16(s.weights, s.direction.x, s.direction.y, s.direction.z)
speakers[0] = s

local s = {
	direction = Vec3f(1, 0, -1):normalize(),
	weights = { [0]=c1_sqrt2 },
}
encodeWeightsFuMa16(s.weights, s.direction.x, s.direction.y, s.direction.z)
speakers[1] = s

function phasor(freq)
	local pincr = freq/C.audio_samplerate()
	local phase = 0
	return function()
		phase = (phase + pincr) % 1
		return phase - 0.5
	end
end

function cycle(freq)
	local pincr = freq/C.audio_samplerate()
	local phase = 0
	return function()
		phase = (phase + pincr) % 1
		return sin(phase * pi * 2)
	end
end

function fly(freq)
	local p = phasor(freq)
	local c = cycle(freq * 0.5)
	return function()
		return (c() + 0.5*p())
	end
end

function lag(amt)
	local y = 0
	return function(x)
		y = y + amt * (x-y)
		return y
	end
end

view = view or {
	pos = Vec3f(),
	quat = Quatf():identity(),
}

voices = voices or {}

local min_distance_squared = 0.00001
local cpu = 0.05
local flag = 0
local flaglag = lag(0.01)

C.audio_set_callback(function(sampletime)
	local frames = C.audio_buffersize()
	local outs = C.audio_channelsout()
	local outputs = {}
	for c = 0, outs-1 do
		outputs[c] = C.audio_outbuffer(c)
	end
	
	local nexttime = sampletime + frames
	local m = C.audioq_peek(nexttime)
	while m ~= nil do
		-- TODO: use message...
		flag = 1
		local cmd = m.cmd
		if cmd == C.AUDIO_VOICE_NEW then
			voices[m.id] = {
				ugen = fly(((m.id % 10) + srandom() * 0.2) * 110),
				pos = Vec3f(),
			}
			
		elseif cmd == C.AUDIO_VOICE_FREE then
			voices[m.id] = nil
			
		elseif cmd == C.AUDIO_VOICE_POS then
			voices[m.id].pos.x = m.x
			voices[m.id].pos.y = m.y
			voices[m.id].pos.z = m.z
			
		elseif cmd == C.AUDIO_POS then
			view.pos.x = m.x
			view.pos.y = m.y
			view.pos.z = m.z
			
		elseif cmd == C.AUDIO_QUAT then
			view.quat.x = m.x
			view.quat.y = m.y
			view.quat.z = m.z
			view.quat.w = m.w
		elseif cmd == C.AUDIO_CLEAR then
			for k, v in pairs(voices) do
				voices[k] = nil
			end
		end
		
		-- get next message:
		m = C.audioq_next(nexttime)
	end
	
	local out0 = C.audio_outbuffer(0)
	local out1 = C.audio_outbuffer(1)
	local w0 = speakers[0].weights
	local w1 = speakers[1].weights
	
	-- play all voices:
	for id, v in pairs(voices) do
		local ugen = v.ugen
		local amp = 0.05
		local pan = 0.5
		local omni = 0
		
		-- get position in 'view space':
		local rel = quat_unrotate(view.quat, v.pos - view.pos)
		
		-- distance squared:
		local d2 = rel:dot(rel)
		-- distance
		local d = sqrt(d2)
		-- unit rel:
		local direction = rel / d
		
		-- amplitude scale by distance:
		local atten = attenuate(d2, 0.2, 1/32)
		
		
		-- omni mix is also distance-dependent. 
		-- at near distances, the signal should be omnidirectional
		-- the minimum really depends on the radii of the listener/emitter
		local spatial = 1 - attenuate(d2, 0.2, 1/4)
		
		
		-- encode:
		local w = SQRT2
		-- first 3 harmonics are the same as the unit direction:
		local x = spatial * direction.x
		local y = spatial * direction.y
		local z = spatial * direction.z
		
		for i=0, frames-1 do
			local s = ugen() * amp * atten
			
			-- decode:
			out0[i] = out0[i]
				+ w0[0] * w * s
				+ w0[1] * x * s
				+ w0[2] * y * s 
				+ w0[3] * z * s
			
			out1[i] = out1[i]
				+ w1[0] * w * s 
				+ w1[1] * x * s 
				+ w1[2] * y * s 
				+ w1[3] * z * s
		end
	end
	
	
	local cpu1 = C.audio_cpu()
	if cpu1 > cpu then
		cpu = cpu1
		print("audio peak cpu", cpu)
	end
	
	-- TODO: tune this
	collectgarbage()
end)