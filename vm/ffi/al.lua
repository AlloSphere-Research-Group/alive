
local sin, cos, tan = math.sin, math.cos, math.tan
local asin, acos, atan, atan2 = math.asin, math.acos, math.atan, math.atan2
local sqrt, pow, abs = math.sqrt, math.pow, math.abs
local min, max = math.min, math.max
local floor = math.floor
local pi = math.pi
local format = string.format

local wrap = function(v, lo, hi)
	if lo == hi then return lo end
	if lo > hi then lo, hi = hi, lo end
	if v >= lo and v < hi then return v end
	local range = hi-lo
	if range <= 0.0000001 then return lo end
	local wraps = floor((v-lo)/range) 
	return v - range * wraps
end

local fold = function(v, lo, hi)
	if lo == hi then return lo end
	if lo > hi then lo, hi = hi, lo end
	local range = hi-lo
	local wraps = 0
	if v >= hi then
		v = v - range
		if v > hi then
			wraps = floor((v-lo)/range)
			v = v - range * wraps
		end
		wraps = wraps + 1
	elseif v < lo then
		v = v + range
		if v < lo then
			wraps = floor((v-lo)/range) - 1
			v = v - range * wraps
		end
		wraps = wraps - 1
	end
	if wraps % 2 == 1 then v = hi + lo - v end
	return v, wraps
end


local enums = [[
typedef enum {	
	AlloVoidTy			= 0x0000,
	AlloFloat32Ty		= 0x0004,
	AlloFloat64Ty		= 0x0008,
	AlloSInt8Ty			= 0x0101, 
	AlloSInt16Ty		= 0x0102,
	AlloSInt32Ty		= 0x0104,
	AlloSInt64Ty		= 0x0108,
	AlloUInt8Ty			= 0x0201,
	AlloUInt16Ty		= 0x0202,
	AlloUInt32Ty		= 0x0204,
	AlloUInt64Ty		= 0x0208,
	AlloArrayTy			= 0x1A2C,	
	AlloPointer32Ty		= 0x2F04,
	AlloPointer64Ty		= 0x2F08
} AlloTy;

]]

local header = [[
typedef struct { float x, y, z; } Vec3f;
typedef struct { double x, y, z; } Vec3d;
typedef struct { float w, x, y, z; } Quatf;
typedef struct { double w, x, y, z; } Quatd;

typedef struct { Vec3d vec; Quatd quat; } Pose;

typedef struct { float r, g, b, a; } Color;
typedef struct { float h, s, v; } HSV;

typedef struct {
	AlloTy type;
	uint8_t components, dimcount;	
	uint32_t dim[4], stride[4];
} ArrayHeader;

typedef struct {
	union { char * ptr; uint64_t pad; } data;
	ArrayHeader header;
} Array;
]]

local ffi = require "ffi"
ffi.cdef(enums .. header)

local QUAT_EPSILON = 0.0000001
local QUAT_ACCURACY_MAX = 1.000001
local QUAT_ACCURACY_MIN = 0.999999

local Array
local Vec3d
local Quatd
local Color

Array = ffi.metatype("Array", {
	__tostring = function(s)
		return format("Array{ptr='%s', type=%s, components=%d, dimcount=%d, dim={%d, %d, %d, %d}, stride={%d, %d, %d, %d} }", tostring(s.data.ptr), tostring(s.header.type), s.header.components, s.header.dimcount, s.header.dim[0], s.header.dim[1], s.header.dim[2], s.header.dim[3], s.header.stride[0], s.header.stride[1], s.header.stride[2], s.header.stride[3])
	end,
	--[=[
	__add = function(a, b) 
		if type(b) == "number" then a, b = b, a end
		if type(a) == "number" then
			return Vec3d(a+b.x, a+b.y, a+b.z) 
		else
			return Vec3d(a.x+b.x, a.y+b.y, a.z+b.z) 
		end
	end,
	__sub = function(a, b) 
		if type(b) == "number" then a, b = -b, -a end
		if type(a) == "number" then
			return Vec3d(a-b.x, a-b.y, a-b.z) 
		else
			return Vec3d(a.x-b.x, a.y-b.y, a.z-b.z) 
		end
	end,
	__unm = function(s) 
		return Vec3d(-s.x, -s.y, -s.z) 
	end,
	__mul = function(a, b) 
		if type(b) == "number" then a, b = b, a end
		if type(a) == "number" then
			return Vec3d(a*b.x, a*b.y, a*b.z) 
		else
			return Vec3d(a.x*b.x, a.y*b.y, a.z*b.z) 
		end
	end,
	__len = function(a) return math.sqrt(a.x*a.x + a.y*a.y + a.z*a.z) end,
	--]=]
	__index = {
		
	},
})

local 
function vec(name, quatname)	
	return ffi.metatype(name, {
		__tostring = function(s)
			return format("%s(%f, %f, %f)", name, s.x, s.y, s.z)
		end,
		--__concat = function(a, b) end
		__len = function(s) return sqrt(s:dot(s)) end,
		__unm = function(s) 
			return ffi.new(name, -s.x, -s.y, -s.z) 
		end,
		__add = function(a, b) 
			if type(b) == "number" then a, b = b, a end
			if type(a) == "number" then
				return ffi.new(name, a+b.x, a+b.y, a+b.z) 
			else
				return ffi.new(name, a.x+b.x, a.y+b.y, a.z+b.z) 
			end
		end,
		__sub = function(a, b) 
			if type(b) == "number" then a, b = -b, -a end
			if type(a) == "number" then
				return ffi.new(name, a-b.x, a-b.y, a-b.z) 
			else
				return ffi.new(name, a.x-b.x, a.y-b.y, a.z-b.z) 
			end
		end,
		__mul = function(a, b) 
			if type(b) == "number" then a, b = b, a end
			if type(a) == "number" then
				return ffi.new(name, a*b.x, a*b.y, a*b.z) 
			else
				return ffi.new(name, a.x*b.x, a.y*b.y, a.z*b.z) 
			end
		end,
		__div = function(a, b) 
			if type(b) == "number" then 
				return ffi.new(name, a.x/b, a.y/b, a.z/b) 
			elseif type(a) == "number" then
				return ffi.new(name, a/b.x, a/b.y, a/b.z) 
			else
				return ffi.new(name, a.x/b.x, a.y/b.y, a.z/b.z) 
			end
		end,
		__pow = function(a, b) 
			if type(b) == "number" then 
				return ffi.new(name, a.x^b, a.y^b, a.z^b) 
			elseif type(a) == "number" then
				return ffi.new(name, a^b.x, a^b.y, a^b.z) 
			else
				return ffi.new(name, a.x^b.x, a.y^b.y, a.z^b.z) 
			end
		end,
		__lt = function(a, b) 
			return a.x<b.x and a.y<b.y and a.z<b.z
		end,
		__le = function(a, b) 
			return a.x<=b.x and a.y<=b.y and a.z<=b.z
		end,
		__eq = function(a, b) 
			return a.x==b.x and a.y==b.y and a.z==b.z
		end,
		__index = {
			set = function(s, x, y, z) s.x = x; s.y = y; s.z = z end,
			copy = function(s, q) s.x = q.x; s.y = q.y; s.z = q.z end,
			zero = function(s) s.x = 0; s.y = 0; s.z = 0 end,
			unpack = function(s) return s.x, s.y, s.z end,
			
			add = function(s, v) 
				s.x = s.x + v.x 
				s.y = s.y + v.y 
				s.z = s.z + v.z
			end,
			mul = function(s, v) 
				s.x = s.x * v.x 
				s.y = s.y * v.y 
				s.z = s.z * v.z
			end,
			shift = function(s, v) 
				s.x = s.x + v 
				s.y = s.y + v 
				s.z = s.z + v
			end,
			scale = function(s, v) 
				s.x = s.x * v
				s.y = s.y * v 
				s.z = s.z * v
			end,
			
			magSqr = function(s) return s:dot(s) end,
			area = function(s) return s:dot(s) end,
			mag = function(s) return sqrt(s:dot(s)) end,
			
			distanceSquaredTo = function(s, t)
				local x1 = t.x-s.x
				local y1 = t.y-s.y
				local z1 = t.z-s.z
				return x1*x1 + y1*y1 + z1*z1
			end,
			distanceTo = function(s, t)
				return sqrt(distanceSquaredTo(s, t))
			end,
			
			dot = function(s, v)
				return s.x*v.x + s.y*v.y + s.z*v.z
			end,
			cross = function(s, b)
				return ffi.new(name,  
					s.y*b.z - s.z*b.y, 
					s.z*b.x - s.x*b.z, 
					s.x*b.y - s.y*b.x )
			end,
			normalize = function(s)
				local unit = s:dot(s)	-- magSqr
				if (unit*unit < QUAT_EPSILON) then return ffi.new(name, 0, 0, 1) end
				local scale = 1./sqrt(unit)
				return ffi.new(name, s.x*scale, s.y*scale, s.z*scale)
			end,
			
			-- returns a quat:
			getRotationTo = function(src, dst)
				local q = ffi.new(quatname, 1, 0, 0, 0)
				local d = src:dot(dst)
				if (d >= 1) then
					--// vectors are the same, return identity:
					return q
				end
				if (d < -0.999999999) then
					--// vectors are nearly opposing
					--// pick an axis to rotate around
					local axis = ffi.new(name, 0, 1, 0):cross(src)
					-- if colinear, pick another:
					if (axis:magSqr() < 0.00000000001) then
						axis = ffi.new(name, 0, 0, 1):cross(src)
					end
					return q:fromAxisAngle(pi, axis)
				else
					local s = sqrt((d+1)*2)
					local invs = 1./s
					local c = src:cross(dst)
					q.w = s * 0.5
					q.x = c.x * invs
					q.y = c.y * invs
					q.z = c.z * invs
				end
				return q:normalize()
			end,
			
			-- Reflect vector around line
			reflect = function(s, normal)
				assert(normal and ffi.istype(normal, ctype))
				return s - (2 * s:dot(normal) * normal)
			end,
			
			-- The p-norm is pth root of the sum of the absolute value of the elements 
			-- raised to the pth, (sum |x_n|^p) ^ (1/p).
			pnorm = function(s, p) 
				local r = abs(s.x)^p
						+ abs(s.y)^p
						+ abs(s.z)^p
				return r^(1/p)		
			end,
			
			-- Returns product of elements
			product = function() return s.x * s.y * s.z end,	
			-- Returns sum of elements
			sum = function() return s.x + s.y + s.z end,

			-- linear interpolation
			lerp = function(s, b, t)
				assert(b and ffi.istype(b, ctype))
				return s + t * (b-s)
			end,
			
			-- linear interpolation
			mix = function(s, v, t)
				return s + t*(v-s)
			end,
			
			min = function(s, v)
				return ffi.new(name, 
					min(s.x, v),
					min(s.y, v),
					min(s.z, v)
				)
			end,
			max = function(s, v)
				return ffi.new(name, 
					max(s.x, v),
					max(s.y, v),
					max(s.z, v)
				)
			end,
			clip = function(s, mn, mx)
				return ffi.new(name, 
					min(max(s.x, mn), mx),
					min(max(s.y, mn), mx),
					min(max(s.z, mn), mx)
				)
			end,
			wrap = function(s, mn, mx)
				return ffi.new(name, 
					wrap(s.x, mn, mx),
					wrap(s.y, mn, mx),
					wrap(s.z, mn, mx)
				)
			end,
			
			-- clip, wrap, fold?
			-- T * elems(){ return &x; } -- return cast to double *
			-- xy, xz, yz methods?
		},
	})
end

local
function quat(name, vecname)
	return ffi.metatype(name, {
		__tostring = function(s)
			return format("%s(%f, %f, %f, %f)", name, s.w, s.x, s.y, s.z)
		end,
		--__concat = function(a, b) end
		__len = function(s) return sqrt(s:dot(s)) end,
		--__unm = function(s) return Vec3d(-s.x, -s.y, -s.z) end,
		--[[
		-- what do these operations mean for quaternions?
		__add = function(a, b) 
		__sub = function(a, b) 
		__mul = function(a, b) 
			if type(b) == "number" then a, b = b, a end
			if type(a) == "number" then
				return Vec3d(a*b.x, a*b.y, a*b.z) 
			else
				return Vec3d(a.x*b.x, a.y*b.y, a.z*b.z) 
			end
		end,
		--]]
		__mul = function(s, q)
			if type(q) == "number" then
				return ffi.new(name, s.w * q, s.x * q, s.y * q, s.z * q)
			elseif type(s) == "number" then
				return ffi.new(name, q.w * s, q.x * s, q.y * s, q.z * s)
			else
				return ffi.new(name,
					s.w*q.w - s.x*q.x - s.y*q.y - s.z*q.z,
					s.w*q.x + s.x*q.w + s.y*q.z - s.z*q.y,
					s.w*q.y + s.y*q.w + s.z*q.x - s.x*q.z,
					s.w*q.z + s.z*q.w + s.x*q.y - s.y*q.x
				)
			end
		end,
		__div = function(s, q)
			if type(q) == "number" then
				-- scalar division
				return ffi.new(name, s.w / q, s.x / q, s.y / q, s.z / q)
			elseif type(s) == "number" then
				-- scalar division
				return ffi.new(name, s / q.w, s / q.x, s / q.y, s / q.z)
			else
				return q:conjugate() * (s/q:magSqr())
			end
		end,
		
		--[[
		
		__pow = function(a, b) 
			if type(b) == "number" then 
				return Vec3d(a.x^b, a.y^b, a.z^b) 
			elseif type(a) == "number" then
				return Vec3d(a^b.x, a^b.y, a^b.z) 
			else
				return Vec3d(a.x^b.x, a.y^b.y, a.z^b.z) 
			end
		end,
		__lt = function(a, b) 
			return a.x<b.x and a.y<b.y and a.z<b.z
		end,
		__le = function(a, b) 
			return a.x<=b.x and a.y<=b.y and a.z<=b.z
		end,
		--]]
		__eq = function(a, b) 
			return a.w==b.w and a.x==b.x and a.y==b.y and a.z==b.z
		end,

		__index = {	
			identity = function() return ffi.new(name, 1, 0, 0, 0) end,
			set = function(s, w, x, y, z) s.w = w; s.x = x; s.y = y; s.z = z end,
			copy = function(s, q) s.w = q.w; s.x = q.x; s.y = q.y; s.z = q.z end,
			unpack = function(s) return s.w, s.x, s.y, s.z end,
			
			normalize = function(s)
				local unit = s:dot(s)	-- magSqr
				if (unit*unit < QUAT_EPSILON) then return ffi.new(name, 1, 0, 0, 0) end
				local scale = 1./sqrt(unit)
				s.w = s.w * scale
				s.x = s.x * scale
				s.y = s.y * scale
				s.z = s.z * scale
				return s
			end,
			
			mul = function(s, q)
				local x, y, z, w = s.x, s.y, s.z, s.w
				s.w = w*q.w - x*q.x - y*q.y - z*q.z
				s.x = w*q.x + x*q.w + y*q.z - z*q.y
				s.y = w*q.y + y*q.w + z*q.x - x*q.z
				s.z = w*q.z + z*q.w + x*q.y - y*q.x
			end,
			
			-- Returns the conjugate
			conj = function(s) return Quat(w, -s.x, -s.y, -s.z) end,
			conjugate = function(s) return Quat(w, -s.x, -s.y, -s.z) end,
			
			-- Returns inverse (same as conjugate if normalized as q^-1 = q_conj/q_mag^2)
			inverse = function(s) return s:normalize():conj() end,
			
			magSqr = function(s) return s:dot(s) end,
			mag = function(s) return sqrt(s:dot(s)) end,

			-- Returns multiplicative inverse
			recip = function(s) return s:conj() * 1/s:magSqr() end,

			-- Returns signum, q/|q|, the closest point on unit 3-sphere
			sgn = function(s) return s:normalize() end,
			
			-- linear interpolation
			mix = function(s, v, t)
				return s + t*(v-s)
			end,
			
			-- dot product
			dot = function(s, v)
				return s.w*v.w + s.x*v.x + s.y*v.y + s.z*v.z
			end,
			
			-- Set as versor rotated by angle, in radians, around axis
			fromAxisAngle = function(s, angle, axis)
				local t2 = angle * 0.5
				local sinft2 = sin(t2)
				s.w = cos(t2)
				s.x = axis.x * sinft2
				s.y = axis.y * sinft2
				s.z = axis.z * sinft2
				return s
			end,
			fromAxisX = function(s, angle) 
				local t2 = angle * 0.5
				s.w = cos(t2)
				s.x = sin(t2)
				s.y = 0
				s.z = 0
				return s
			end,
			fromAxisY = function(s, angle) 
				local t2 = angle * 0.5
				s.w = cos(t2)
				s.x = 0
				s.y = sin(t2)
				s.z = 0
				return s
			end,
			fromAxisZ = function(s, angle) 
				local t2 = angle * 0.5
				s.w = cos(t2)
				s.x = 0
				s.y = 0
				s.z = sin(t2)
				return s
			end,
			
			fromEuler = function(s, az, el, ba) 
				--[[
				//http://vered.rose.utoronto.ca/people/david_dir/GEMS/GEMS.html
				//Converting from Euler angles to a quaternion is slightly more tricky, as the order of operations
				//must be correct. Since you can convert the Euler angles to three independent quaternions by
				//setting the arbitrary axis to the coordinate axes, you can then multiply the three quaternions
				//together to obtain the final quaternion.

				//So if you have three Euler angles (a, b, c), then you can form three independent quaternions
				//Qx = [ cos(a/2), (sin(a/2), 0, 0)]
				//Qy = [ cos(b/2), (0, sin(b/2), 0)]
				//Qz = [ cos(c/2), (0, 0, sin(c/2))]
				//And the final quaternion is obtained by Qx * Qy * Qz.
				--]]
				local c1 = cos(az * 0.5)
				local c2 = cos(el * 0.5)
				local c3 = cos(ba * 0.5)
				local s1 = sin(az * 0.5)
				local s2 = sin(el * 0.5)
				local s3 = sin(ba * 0.5)
				-- equiv Q1 = Qy * Qx; // since many terms are zero
				local tw = c1*c2
				local tx = c1*s2
				local ty = s1*c2
				local tz =-s1*s2
				-- equiv Q2 = Q1 * Qz; // since many terms are zero
				s.w = tw*c3 - tz*s3
				s.x = tx*c3 + ty*s3
				s.y = ty*c3 - tx*s3
				s.z = tw*s3 + tz*c3
				return s
			end,
			
			-- v1 and v2 must be normalized
			-- alternatively expressed as Q = (1+gp(v1, v2))/sqrt(2*(1+dot(b, a)))
			fromRotor = function(v1, v2) 
				--  get the normal to the plane (i.e. the unit bivector containing the v1 and v2)
				local n = v1:cross(v2)
				n = n:normalize() -- normalize because the cross product can get slightly denormalized
			
				-- calculate half the angle between v1 and v2
				local dotmag = v1:dot(v2)
				local theta = acos(dotmag)*0.5
			
				-- calculate the scaled actual bivector generaed by v1 and v2
				local bivec = n*sin(theta)
				s.w = cos(theta)
				s.x = bivec.x
				s.y = bivec.y
				s.z = bivec.z
				return s
			end,
			
			--[[
			function fromMatrix4(s, m)
				T trace = m[0]+m[5]+m[10];
				w = sqrt(1. + trace)*0.5;
			
				if(trace > 0.) {
					x = (m[9] - m[6])/(4.*w);
					y = (m[2] - m[8])/(4.*w);
					z = (m[4] - m[1])/(4.*w);
				}
				else {
					if(m[0] > m[5] && m[0] > m[10]) {
						// m[0] is greatest
						x = sqrt(1. + m[0]-m[5]-m[10])*0.5;
						w = (m[9] - m[6])/(4.*x);
						y = (m[4] + m[1])/(4.*x);
						z = (m[8] + m[2])/(4.*x);
					}
					else if(m[5] > m[0] && m[5] > m[10]) {
						// m[1] is greatest
						y = sqrt(1. + m[5]-m[0]-m[10])*0.5;
						w = (m[2] - m[8])/(4.*y);
						x = (m[4] + m[1])/(4.*y);
						z = (m[9] + m[6])/(4.*y);
					}
					else { //if(m[10] > m[0] && m[10] > m[5]) {
						// m[2] is greatest
						z = sqrt(1. + m[10]-m[0]-m[5])*0.5;
						w = (m[4] - m[1])/(4.*z);
						x = (m[8] + m[2])/(4.*z);
						y = (m[9] + m[6])/(4.*z);
					}
				}
				return s;
			end
			--]]
			
			toAxisAngle = function (s)
				local unit = w*w
				if unit < QUAT_ACCURACY_MIN then
					-- |cos x| must always be less than or equal to 1!
					local invsin = 1/sqrt(1 - unit) --approx = 1/sqrt(1 - cos^2(theta/2))
					
					return 2*acos(s.w), ffi.new(vecname, s.x*invsin, s.y*invsin, s.z*invsin)
				else
					if s.x == 0 and s.y == 0 and s.z == 0 then
						-- change to some default axis:
						return 0, ffi.new(vecname, 0, 0, 1)
					else
						-- for small angles, axis is roughly equal to i,j,k components
						-- axes are close to zero, should be normalized:
						return 0, ffi.new(vecname, s.x, s.y, s.z):normalize()
					end
				end
			end,
			
			-- toEuler
			toEuler = function(s)
				-- http://www.mathworks.com/access/helpdesk/help/toolbox/aeroblks/quaternionstoeulerangles.html
				local sqw = s.w*s.w
				local sqx = s.x*s.x
				local sqy = s.y*s.y
				local sqz = s.z*s.z
				az = asin (-2.0 * (s.x*s.z - s.w*s.y))
				el = atan2( 2.0 * (s.y*s.z + s.w*s.x), (sqw - sqx - sqy + sqz))
				ba = atan2( 2.0 * (s.x*s.y + s.w*s.z), (sqw + sqx - sqy - sqz))
				return az, el, ba
			end,
			
			ux = function(s) 
				return ffi.new(vecname, 
					1.0 - 2.0*s.y*s.y - 2.0*s.z*s.z,
					2.0*s.x*s.y + 2.0*s.z*s.w,
					2.0*s.x*s.z - 2.0*s.y*s.w)
			end,
			uy = function(s) 
				return ffi.new(vecname, 
					2.0*s.x*s.y - 2.0*s.z*s.w,
					1.0 - 2.0*s.x*s.x - 2.0*s.z*s.z,
					2.0*s.y*s.z + 2.0*s.x*s.w)
			end,
			uz = function(s) 
				return ffi.new(vecname, 
					2.0*s.x*s.z + 2.0*s.y*s.w,
					2.0*s.y*s.z - 2.0*s.x*s.w,
					1.0 - 2.0*s.x*s.x - 2.0*s.y*s.y)
			end,
			-- 'forward' vector is negative z for OpenGL coordinate system
			uf = function(s) return -s:uz() end,
			
			--[[
			Quat to matrix:
			RHCS
				[ 1 - 2y - 2z    2xy + 2wz      2xz - 2wy	] 
				[											] 
				[ 2xy - 2wz      1 - 2x - 2z    2yz + 2wx	] 
				[											] 
				[ 2xz + 2wy      2yz - 2wx      1 - 2x - 2y	]
			
			LHCS              
				[ 1 - 2y - 2z    2xy - 2wz      2xz + 2wy	] 
				[											] 
				[ 2xy + 2wz      1 - 2x - 2z    2yz - 2wx	] 
				[											] 
				[ 2xz - 2wy      2yz + 2wx      1 - 2x - 2y	]
			
			
			toMatrix = function(s)
				Vec<3,T> ux,uy,uz;
				toCoordinateFrame(ux,uy,uz);
				
				local ux, uy, uz = s:ux(), s:uy(), s:uz()
				
			
				m[ 0] = ux[0];	m[ 4] = uy[0];	m[ 8] = uz[0];	m[12] = 0;
				m[ 1] = ux[1];	m[ 5] = uy[1];	m[ 9] = uz[1];	m[13] = 0;
				m[ 2] = ux[2];	m[ 6] = uy[2];	m[10] = uz[2];	m[14] = 0;
				m[ 3] = 0;		m[ 7] = 0;		m[11] = 0;		m[15] = 1;
			end
			--]]
			
			--[[
				Rotating a vector is simple:
				v1 = q * qv * q^-1
				Where v is a 'pure quaternion' derived from the vector, i.e. w = 0. 	
			--]]
			rotate = function(v)
				-- v1 = (q * v * q^-1)
				-- simplified: v1 = (q * v):
				local v1 = ffi.new(name, 
					-x*v.x - y*v.y - z*v.z,
					 w*v.x + y*v.z - z*v.y,
					 w*v.y - x*v.z + z*v.x,
					 w*v.z + x*v.y - y*v.x
				)
				v1 = v1 * s:conj();	-- p * q^-1
				return ffi.new(vecname, v1.x, v1.y, v1.z)
			end,
			
			rotateTransposed = function(v)
				return s:conj():rotate(v)
			end,
			
			slerp = function(s, target, amt)
				if amt == 0 then
					return s
				elseif amt == 1 then
					return target
				end
				
				local sign = 1
				local dot_prod = s:dot(target)
				-- clamp:
				local dot_prod = min(max(dot_prod, -1), 1)
				-- if B is on opposite hemisphere from A, use -B instead
				if dot_prod < 0.0 then
					dot_prod = -dot_prod
					sign = -1
				end
				
				local a, b
				local cos_angle = acos(dot_prod)
				if abs(cos_angle) > QUAT_EPSILON then
					local sine = sin(cos_angle)
					local inv_sine = 1/sine
					a = sin(cos_angle*(1-amt)) * inv_sine
					b = sign * sin(cos_angle*amt) * inv_sine
				else
					-- nearly the same;
					-- approximate without trigonometry
					a = amt
					b = 1-amt
				end
				
				local w = a*s.w + b*target.w
				local x = a*s.x + b*target.x
				local y = a*s.y + b*target.y
				local z = a*s.z + b*target.z
				
				s.w = w
				s.x = x
				s.y = y
				s.z = z
				s:normalize()
			end,
					
			-- get the quaternion from a given point and quaterion toward another point
			-- TODO: this is a Pose method!
			towardPoint = function(q, pos, v, amt)
				local diff = (v-pos):normalize()
				if amt < 0 then diff = -diff end
				
				local zaxis = q:uz()
				local along = zaxis:dot(diff)
				
				local axis = zaxis:cross(diff):normalize()
				local axis_mag_sqr = axis:magSqr()
				if axis_mag_sqr < 0.001 and along < 0 then
					axis = zaxis:cross(ffi.new(vecname, 0, 0, 1)):normalize()
					axis_mag_sqr = axis:magSqr()
					if axis_mag_sqr < 0.001 then
						axis = zaxis:cross(ffi.new(vecname, 0, 1, 0)):normalize()
						axis_mag_sqr = axis:magSqr()
					end
				end
				if along < 0.9995 and axis_mag_sqr > 0.001 then
					local theta = abs(amt)*acos(along)
					q:fromAxisAngle(theta, axis)
				else
					q:set(1, 0, 0, 0)
				end
				return q
			end,
		}
	})
end

Quatd = quat("Quatd", "Vec3d")
Quatf = quat("Quatf", "Vec3f")


Vec3d = vec("Vec3d", "Quatd")
Vec3f = vec("Vec3f", "Quatf")

local Pose
Pose = ffi.metatype("Pose", {
	__tostring = function(s)
		return format("Pose(%f, %f, %f, %f, %f, %f, %f)", s.vec.x, s.vec.y, s.vec.z, s.quat.w, s.quat.x, s.quat.y, s.quat.z)
	end,
	__index = {
		uf = function(s) 
			return -s.quat:uz()
		end
	},
})

Color = ffi.metatype("Color", {
	__tostring = function(s)
		return format("Color(%f, %f, %f, %f)", s.r, s.g, s.b, s.a)
	end,
	__unm = function(s) 
		return Color(-s.r, -s.g, -s.b, -s.a) 
	end,
	__index = {
		set = function(s, r, g, b, a) 
			s.r=r or 1
			s.g=g or s.r
			s.b=b or s.r 
			s.a=a or 1 
		end,
		copy = function(s, q) s.r=q.r s.g=q.g s.b=q.b s.a=q.a end,
		unpack = function(s) return s.r, s.g, s.b, s.a end,
	},
})

return {
	header = header,
	Vec3f = Vec3f,
	Vec3d = Vec3d,
	Quatf = Quatf,
	Quatd = Quatd,
	Pose = Pose,
	Array = Array,
	Color = Color,
}