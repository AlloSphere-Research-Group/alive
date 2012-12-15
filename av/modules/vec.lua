local sin, cos, tan = math.sin, math.cos, math.tan
local asin, acos, atan, atan2 = math.asin, math.acos, math.atan, math.atan2
local sqrt, pow, abs = math.sqrt, math.pow, math.abs
local min, max = math.min, math.max
local floor = math.floor
local pi = math.pi
local format = string.format

local ffi = require "ffi"

ffi.cdef [[
	typedef struct vec3 { double x, y, z; } vec3;
	typedef struct quat { double x, y, z, w; } quat;
	
	typedef struct vec3f { float x, y, z; } vec3f;
	typedef struct quatf { float x, y, z, w; } quatf;
]]

local EPSILON = 0.0000001

function define_vec(T, element_type, quat_type)

	local vec = {}
	vec.__index = vec

	local fmt = T .. "(%f, %f, %f)"
	function vec:__tostring()
		return format(fmt, self.x, self.y, self.z)
	end

	-- construct or in-place:
	function vec:identity()
		if self then
			self.x = 0
			self.y = 0
			self.z = 1
		else
			return ffi.new(T, 0, 0, 1)
		end
	end

	-- constructors:
	function vec:__unm()
		return ffi.new(T, -self.x, -self.y, -self.z) 
	end

	function vec.__add(a, b)
		if type(b) == "number" then a, b = b, a end
		if type(a) == "number" then
			return ffi.new(T, a+b.x, a+b.y, a+b.z) 
		else
			return ffi.new(T, a.x+b.x, a.y+b.y, a.z+b.z) 
		end
	end

	function vec.__sub(a, b)
		if type(b) == "number" then a, b = -b, -a end
		if type(a) == "number" then
			return ffi.new(T, a-b.x, a-b.y, a-b.z) 
		else
			return ffi.new(T, a.x-b.x, a.y-b.y, a.z-b.z) 
		end
	end

	function vec.__mul(a, b) 
		if type(b) == "number" then a, b = b, a end
		if type(a) == "number" then
			return ffi.new(T, a*b.x, a*b.y, a*b.z) 
		else
			return ffi.new(T, a.x*b.x, a.y*b.y, a.z*b.z) 
		end
	end

	function vec.__div(a, b) 
		if type(b) == "number" then 
			return ffi.new(T, a.x/b, a.y/b, a.z/b) 
		elseif type(a) == "number" then
			return ffi.new(T, a/b.x, a/b.y, a/b.z) 
		else
			return ffi.new(T, a.x/b.x, a.y/b.y, a.z/b.z) 
		end
	end

	function vec.__mod(a, b)
		if type(b) == "number" then
			return ffi.new(T, 
				a.x % b,
				a.y % b,
				a.z % b
			)
		else
			return ffi.new(T, 
				a.x % b.x,
				a.y % b.y,
				a.z % b.z
			)
		end
	end
		
	function vec.__pow(a, b) 
		if type(b) == "number" then 
			return ffi.new(T, a.x^b, a.y^b, a.z^b) 
		elseif type(a) == "number" then
			return ffi.new(T, a^b.x, a^b.y, a^b.z) 
		else
			return ffi.new(T, a.x^b.x, a.y^b.y, a.z^b.z) 
		end
	end	
		
	function vec:clone()
		return ffi.new(T, self.x, self.y, self.z)
	end

	function vec:normalized()
		local unit = self:dot(self)	-- magSqr
		if unit < EPSILON then 
			return ffi.new(T, 0, 0, 1)
		end
		local scale = 1./sqrt(unit)
		return ffi.new(T, self.x*scale, self.y*scale, self.z*scale)
	end

	function vec:cross(b)
		return ffi.new(T, 
			self.y*b.z - self.z*b.y, 
			self.z*b.x - self.x*b.z, 
			self.x*b.y - self.y*b.x 
		)
	end

	-- Reflect vector around line
	function vec:reflect(normal)
		--return self - (2 * self:dot(normal) * normal)
		-- use in-place ops where possible:
		return (normal * (-2 * self:dot(normal))):add(self)
	end

	function vec:lerp(b, t)
		return (b-self):mul(t):add(self)
	end
	vec.mix = vec.lerp

	-- in-place operations:
	function vec:set(x, y, z)
		if type(x) == "table" and #x >= 3 then
			-- a table array
			x, y, z = unpack(x)
		end
		if type(x) == "number" then
			-- three numbers
			-- one number
			self.x = x
			self.y = y or x
			self.z = z or x
		else
			self.x = x.x
			self.y = x.y or 0
			self.z = x.z or 0
		end
		return self
	end

	function vec:zero()
		self.x = 0
		self.y = 0
		self.z = 0
		return self
	end

	function vec:map(f)
		self.x = f(self.x)
		self.y = f(self.y)
		self.z = f(self.z)
		return self
	end

	function vec:add(b)
		if type(b) == "number" then
			self.x = self.x + b
			self.y = self.y + b
			self.z = self.z + b
		else
			self.x = self.x + b.x
			self.y = self.y + b.y
			self.z = self.z + b.z
		end
		return self
	end

	function vec:sub(b)
		if type(b) == "number" then
			self.x = self.x - b
			self.y = self.y - b
			self.z = self.z - b
		else
			self.x = self.x - b.x
			self.y = self.y - b.y
			self.z = self.z - b.z
		end
		return self
	end

	function vec:mul(b)
		if type(b) == "number" then
			self.x = self.x * b
			self.y = self.y * b
			self.z = self.z * b
		else
			self.x = self.x * b.x
			self.y = self.y * b.y
			self.z = self.z * b.z
		end
		return self
	end

	function vec:div(b)
		if type(b) == "number" then
			self.x = self.x / b
			self.y = self.y / b
			self.z = self.z / b
		else
			self.x = self.x / b.x
			self.y = self.y / b.y
			self.z = self.z / b.z
		end
		return self
	end

	function vec:mod(b)
		if type(b) == "number" then
			self.x = self.x % b
			self.y = self.y % b
			self.z = self.z % b
		else
			self.x = self.x % b.x
			self.y = self.y % b.y
			self.z = self.z % b.z
		end
		return self
	end

	function vec:normalize()
		local unit = self:dot(self)	-- magSqr
		if unit < EPSILON then 
			self:set(0, 0, 1)
		else
			local scale = 1./sqrt(unit)
			self.x = self.x * scale
			self.y = self.y * scale
			self.z = self.z * scale
		end
		return self
	end

	function vec:min(v)
		if type(v) == "number" then
			self.x = min(self.x, v)
			self.y = min(self.y, v)
			self.z = min(self.z, v)
		else
			self.x = min(self.x, v.x)
			self.y = min(self.y, v.y)
			self.z = min(self.z, v.z)
		end
		return self
	end

	function vec:max(v)
		if type(v) == "number" then
			self.x = max(self.x, v)
			self.y = max(self.y, v)
			self.z = max(self.z, v)
		else
			self.x = max(self.x, v.x)
			self.y = max(self.y, v.y)
			self.z = max(self.z, v.z)
		end
		return self
	end

	function vec:clip(a, b)
		return self:max(a):min(b)
	end

	function vec:wrap(a, b)
		return self:mod(b - a):add(a)
	end

	-- accessors:
	function vec.__eq(a, b) 
		return a.x==b.x and a.y==b.y and a.z==b.z
	end
	function vec.__lt(a, b) 
		return a.x<b.x and a.y<b.y and a.z<b.z
	end
	function vec.__le(a, b) 
		return a.x<=b.x and a.y<=b.y and a.z<=b.z
	end

	function vec:unpack()
		return self.x, self.y, self.z
	end

	function vec:dot(v)
		return self.x*v.x + self.y*v.y + self.z*v.z
	end

	-- generate a normal from three vertices:
	function vec.normal(p1, p2, p3)
		--[[
		local u = p2 - p1
		local v = p3 - p1
		return vec(
			u.y*v.z - u.z*v.y,
			u.z*v.x - u.x*v.z,
			u.x*v.y - u.y*v.x
		)
		--]]
		local u = p1 - p2
		local v = p3 - p2
		return v:cross(u):normalize()
	end

	function vec:magSqr()
		return self:dot(self)
	end
	vec.area = vec.magSqr

	function vec:mag()
		return sqrt(self:dot(self)) 
	end
	vec.__len = vec.mag

	function vec:distance2(v)
		-- (-self):dot(v)
		local x1 = t.x-self.x
		local y1 = t.y-self.y
		local z1 = t.z-self.z
		return x1*x1 + y1*y1 + z1*z1
	end

	function vec:distance(v)
		sqrt(self:distance2(v))
	end

	-- Returns product of elements
	function vec:product() 
		return self.x * self.y * self.z 
	end	

	-- Returns sum of elements
	function vec:sum() 
		return self.x + self.y + self.z 
	end

	-- The p-norm is pth root of the sum of the absolute value of the elements 
	-- raised to the pth, (sum |x_n|^p) ^ (1/p).
	function vec:pnorm(p) 
		local r = abs(self.x)^p
				+ abs(self.y)^p
				+ abs(self.z)^p
		return r^(1/p)		
	end

	-- returns a quat:
	function vec.getRotationTo(src, dst)
		local q = ffi.new(quat_type, 0, 0, 0, 1)
		local d = src:dot(dst)
		if (d >= 1) then
			--// vectors are the same, return identity:
			return q
		end
		if (d < -0.999999999) then
			--// vectors are nearly opposing
			--// pick an axis to rotate around
			local axis = ffi.new(T, 0, 1, 0):cross(src)
			-- if colinear, pick another:
			if (axis:magSqr() < 0.00000000001) then
				axis = ffi.new(T, 0, 0, 1):cross(src)
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
	end

	function vec:ptr()
		return ffi.cast(element_type .." *", self)
	end

	setmetatable(vec, {
		__call = function(_, x, y, z)
			-- possible arguments to cast from:
			if not x then
				return ffi.new(T, 0, 0, 0)
			elseif type(x) == "table" and #x >= 3 then
				-- a table array
				x, y, z = unpack(x)
			end
			if type(x) == "number" then
				-- three numbers
				-- one number
				return ffi.new(T, x, y or x, z or x)
			else
				-- another vec (clone it)
				-- a table with .x, .y, .z fields
				return ffi.new(T, x.x or 0, x.y or 0, x.z or 0)
			end
		end,
	})
	
	return vec
end

function define_quat(T, element_type, vec_type)

	local quat = {}
	quat.__index = quat

	local fmt = T .. "(%f, %f, %f, %f)"
	function quat:__tostring()
		return format(fmt, self.x, self.y, self.z, self.w)
	end

	-- construct or in-place:
	function quat:identity()
		if self then
			self.x = 0
			self.y = 0
			self.z = 0
			self.w = 1
		else
			return ffi.new(T, 0, 0, 0, 1)
		end
	end

	-- constructors:
	function quat.__mul(a, b)
		if type(a) == "number" then a, b = b, a end
		local res = ffi.new(T, 0, 0, 0, 1)
		return res:mul(b)
	end

	function quat.__div(a, b)
		if type(b) == "number" then
			-- scalar division
			return ffi.new(T, a.x / b, a.y / b, a.z / b, a.w / b)
		elseif type(s) == "number" then
			-- scalar division
			return ffi.new(T, a / b.x, a / b.y, a / b.z, a / b.w)
		else
			-- TODO: inline this
			return q:conjugate() * (s/q:magSqr())
		end
	end

	function quat:clone()
		return ffi.new(T, self:unpack())
	end

	function quat:normalized()
		local unit = s:dot(s)	-- magSqr
		if unit < EPSILON then 
			return ffi.new(T, 0, 0, 0, 1)
		end
		local scale = 1./sqrt(unit)
		return ffi.new(T, 
			self.x*scale, 
			self.y*scale, 
			self.z*scale, 
			self.w*scale
		)
	end

	-- Returns signum, q/|q|, the closest point on unit 3-sphere
	quat.sgn = quat.normalized

	function quat:conjugated()
		return ffi.new(T,
			-self.x,
			-self.y,
			-self.z,
			self.w
		)
	end
	quat.conj = quat.conjugated

	function quat:inversed()
		return self:normalized():conjugate()
	end

	-- Returns multiplicative inverse
	function quat:reciprocal() 
		return self:conjugated() * 1/self:magSqr() 
	end

	function quat:lerped(b, t)
		return (b-self):mul(t):add(self)
	end
	quat.mix = quat.lerped

	-- in-place:
	function quat:set(x, y, z, w)
		self.x = x
		self.y = y
		self.z = z
		self.w = w
		return self
	end

	function quat:add(q)
		if type(q) == "number" then
			self.x = self.x + q
			self.y = self.y + q
			self.z = self.z + q
			self.w = self.w + q
		else
			self.x = self.x + q.x
			self.y = self.y + q.y
			self.z = self.z + q.z
			self.w = self.w + q.w
		end
		return self
	end

	function quat:sub(q)
		if type(q) == "number" then
			self.x = self.x - q
			self.y = self.y - q
			self.z = self.z - q
			self.w = self.w - q
		else
			self.x = self.x - q.x
			self.y = self.y - q.y
			self.z = self.z - q.z
			self.w = self.w - q.w
		end
		return self
	end

	function quat:mul(q)
		if type(q) == "number" then
			self.x = self.x * q
			self.y = self.y * q
			self.z = self.z * q
			self.w = self.w * q
		else
			local x = self.w*q.x + self.x*q.w + self.y*q.z - self.z*q.y
			local y = self.w*q.y + self.y*q.w + self.z*q.x - self.x*q.z
			local z = self.w*q.z + self.z*q.w + self.x*q.y - self.y*q.x
			local w = self.w*q.w - self.x*q.x - self.y*q.y - self.z*q.z
			self.x = x
			self.y = y
			self.z = z
			self.w = w
		end
		return self
	end

	function quat:normalize()
		local unit = self:dot(self)	-- magSqr
		if unit < EPSILON then 
			self:set(0, 0, 0, 1)
		else
			local scale = 1./sqrt(unit)
			self.x = self.x * scale
			self.y = self.y * scale
			self.z = self.z * scale
			self.w = self.w * scale
		end
		return self
	end

	function quat:conjugate()
		self.x = -self.x
		self.y = -self.y
		self.z = -self.z
		return self
	end

	function quat:inverse()
		return self:normalize():conjugate()
	end

	function quat:fromAxisAngle(angle, axis)
		local t2 = angle * 0.5
		local sinft2 = sin(t2)
		self.w = cos(t2)
		self.x = axis.x * sinft2
		self.y = axis.y * sinft2
		self.z = axis.z * sinft2
		return self
	end

	function quat:fromAxisX(angle)
		local t2 = angle * 0.5
		self.w = cos(t2)
		self.x = sin(t2)
		self.y = 0
		self.z = 0
		return self
	end

	function quat:fromAxisY(angle)
		local t2 = angle * 0.5
		self.w = cos(t2)
		self.x = 0
		self.y = sin(t2)
		self.z = 0
		return self
	end

	function quat:fromAxisZ(angle)
		local t2 = angle * 0.5
		self.w = cos(t2)
		self.x = 0
		self.y = 0
		self.z = sin(t2)
		return self
	end

	-- derive quaternion as absolute difference between two unit vectors
	-- v1 and v2 must be normalized. the order of v1,v2 is not important;
	-- v1 and v2 define a plane orthogonal to a rotational axis
	-- the rotation around this axis increases as v1 and v2 diverge
	-- alternatively expressed as Q = (1+gp(v1, v2))/sqrt(2*(1+dot(b, a)))
	function quat:fromRotor(v1, v2) 
		--  get the normal to the plane (i.e. the unit bivector containing the v1 and v2)
		-- normalize because the cross product can get slightly denormalized
		local axis = v1:cross(v2)
		axis:normalize()
		
		-- the angle between v1 and v2:
		local dotmag = v1:dot(v2)
		-- theta is 0 when colinear, pi/2 when orthogonal, pi when opposing
		local theta = acos(dotmag)
		
		-- now generate as normal from angle-axis representation
		self:fromAxisAngle(theta, axis)
		return self
	end

	function quat:fromEuler(az, el, ba) 
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
		self.w = tw*c3 - tz*s3
		self.x = tx*c3 + ty*s3
		self.y = ty*c3 - tx*s3
		self.z = tw*s3 + tz*c3
		return self
	end



	-- should it normalize internally? 
	function quat:lerp(target, amt)
		local a = 1-amt
		return self:sub(target):mul(a):add(target):normalize()
	end

	function quat:slerp(target, amt)
		if amt == 0 then
			return s
		elseif amt == 1 then
			return target
		end
		
		local sign = 1
		local dot_prod = self:dot(target)
		-- clamp:
		local dot_prod = min(max(dot_prod, -1), 1)
		-- if B is on opposite hemisphere from A, use -B instead
		if dot_prod < 0.0 then
			dot_prod = -dot_prod
			sign = -1
		end
		
		local a, b
		local cos_angle = acos(dot_prod)
		if abs(cos_angle) > EPSILON then
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
		
		return self:lerp(target, b)
	end

	-- accessors:
	function quat.__eq(a, b) 
		return a.w==b.w and a.x==b.x and a.y==b.y and a.z==b.z
	end

	function quat:unpack()
		return self.x, self.y, self.z, self.w
	end

	function quat:dot(v)
		return self.w*v.w + self.x*v.x + self.y*v.y + self.z*v.z
	end

	function quat:magSqr()
		return self:dot(self)
	end

	function quat:mag()
		return sqrt(self:dot(self))
	end

	function quat:axisAngle()
		local unit = self.w*self.w
		if unit < EPSILON then
			-- |cos x| must always be less than or equal to 1!
			local invsin = 1/sqrt(1 - unit) --approx = 1/sqrt(1 - cos^2(theta/2))
			return 2*acos(self.w), ffi.new(vec_type, self.x*invsin, self.y*invsin, self.z*invsin)
		else
			if self.x == 0 and self.y == 0 and self.z == 0 then
				-- change to some default axis:
				return 0, vec3.identity()
			else
				-- for small angles, axis is roughly equal to i,j,k components
				-- axes are close to zero, should be normalized:
				return 0, ffi.new(vec_type, self.x, self.y, self.z):normalized()
			end
		end
	end

	function quat:euler()
		-- http://www.mathworks.com/access/helpdesk/help/toolbox/aeroblks/quaternionstoeulerangles.html
		local sqw = self.w*self.w
		local sqx = self.x*self.x
		local sqy = self.y*self.y
		local sqz = self.z*self.z
		az = asin (-2.0 * (self.x*self.z - self.w*self.y))
		el = atan2( 2.0 * (self.y*self.z + self.w*self.x), (sqw - sqx - sqy + sqz))
		ba = atan2( 2.0 * (self.x*self.y + self.w*self.z), (sqw + sqx - sqy - sqz))
		return az, el, ba
	end

	function quat.ux(s) 
		return ffi.new(vec_type, 
			1.0 - 2.0*s.y*s.y - 2.0*s.z*s.z,
			2.0*s.x*s.y + 2.0*s.z*s.w,
			2.0*s.x*s.z - 2.0*s.y*s.w)
	end

	function quat.uy(s) 
		return ffi.new(vec_type, 
			2.0*s.x*s.y - 2.0*s.z*s.w,
			1.0 - 2.0*s.x*s.x - 2.0*s.z*s.z,
			2.0*s.y*s.z + 2.0*s.x*s.w)
	end

	function quat.uz(s) 
		return ffi.new(vec_type, 
			2.0*s.x*s.z + 2.0*s.y*s.w,
			2.0*s.y*s.z - 2.0*s.x*s.w,
			1.0 - 2.0*s.x*s.x - 2.0*s.y*s.y)
	end

	-- 'forward' vector is negative z for OpenGL coordinate system
	function quat.uf(s) 
		return ffi.new(vec_type, 
			-( 2.0*s.x*s.z + 2.0*s.y*s.w ),
			-( 2.0*s.y*s.z - 2.0*s.x*s.w ),
			-( 1.0 - 2.0*s.x*s.x - 2.0*s.y*s.y) )
	end

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


	function quat.matrix(s, m)
		Vec<3,T> ux,uy,uz;
		toCoordinateFrame(ux,uy,uz);
		
		local ux, uy, uz = s:ux(), s:uy(), s:uz()
		

		m[ 0] = ux[0];	m[ 4] = uy[0];	m[ 8] = uz[0];	m[12] = 0;
		m[ 1] = ux[1];	m[ 5] = uy[1];	m[ 9] = uz[1];	m[13] = 0;
		m[ 2] = ux[2];	m[ 6] = uy[2];	m[10] = uz[2];	m[14] = 0;
		m[ 3] = 0;		m[ 7] = 0;		m[11] = 0;		m[15] = 1;
	end
	--]]

	--	q must be a normalized quaternion
	function quat.rotate(q, v)
		-- qv = vec4(v, 0) // 'pure quaternion' derived from vector
		-- return ((q * qv) * q^-1).xyz
		-- reduced to 24 multiplies and 17 additions:
		local px =  q.w*v.x + q.y*v.z - q.z*v.y
		local py =  q.w*v.y + q.z*v.x - q.x*v.z
		local pz =  q.w*v.z + q.x*v.y - q.y*v.x
		local pw = -q.x*v.x - q.y*v.y - q.z*v.z
		return ffi.new(vec_type,
			px*q.w - pw*q.x + pz*q.y - py*q.z,	-- x
			py*q.w - pw*q.y + px*q.z - pz*q.x,	-- y
			pz*q.w - pw*q.z + py*q.x - px*q.y	-- z
		)
	end

	-- equiv. quat_rotate(quat_conj(q), v):
	-- q must be a normalized quaternion
	function quat.unrotate(q, v)
		-- reduced:
		local px = q.w*v.x - q.y*v.z + q.z*v.y
		local py = q.w*v.y - q.z*v.x + q.x*v.z
		local pz = q.w*v.z - q.x*v.y + q.y*v.x
		local pw = q.x*v.x + q.y*v.y + q.z*v.z
		return ffi.new(vec_type,
			pw*q.x + px*q.w + py*q.z - pz*q.y,  -- x
			pw*q.y + py*q.w + pz*q.x - px*q.z,  -- y
			pw*q.z + pz*q.w + px*q.y - py*q.x   -- z
		)
	end

	-- get the quaternion from a given point and quaterion toward another point
	-- TODO: this is a Pose method!
	function quat:towardPoint(pos, v, amt)
		local diff = (v-pos):normalize()
		if amt < 0 then diff = -diff end
		
		local zaxis = self:uz()
		local along = zaxis:dot(diff)
		
		local axis = zaxis:cross(diff):normalize()
		local axis_mag_sqr = axis:magSqr()
		if axis_mag_sqr < 0.001 and along < 0 then
			axis = zaxis:cross(ffi.new(vec_type, 0, 0, 1)):normalize()
			axis_mag_sqr = axis:magSqr()
			if axis_mag_sqr < 0.001 then
				axis = zaxis:cross(ffi.new(vec_type, 0, 1, 0)):normalize()
				axis_mag_sqr = axis:magSqr()
			end
		end
		if along < 0.9995 and axis_mag_sqr > 0.001 then
			local theta = abs(amt)*acos(along)
			return self:clone():fromAxisAngle(theta, axis)
		else
			return quat.identity()
		end
	end

	function quat:ptr()
		return ffi.cast(element_type .. " *", self)
	end

	setmetatable(quat, {
		__call = function(_, x, y, z, w)
			if not x then
				return ffi.new(T, 0, 0, 0, 1)
			elseif type(x) == "table" and #x >= 3 then
				-- a table array
				x, y, z, w = unpack(x)
			end
			if type(x) == "number" then
				-- three numbers
				-- one number
				return ffi.new(T, x, y or 0, z or 0, w or 1)
			else
				-- another vec3 (clone it)
				-- a table with .x, .y, .z fields
				return ffi.new(T, x.x or 0, x.y or 0, x.z or 0, x.w or 1)
			end
		end,
	})
	
	return quat
end

local vec3 = ffi.metatype("vec3", define_vec("vec3", "double", "quat"))
local vec3f = ffi.metatype("vec3f", define_vec("vec3f", "float", "quatf"))

local quat = ffi.metatype("quat", define_quat("quat", "double", "vec3"))
local quatf = ffi.metatype("quatf", define_quat("quatf", "float", "vec3f"))

return {
	vec3 = vec3,
	vec3f = vec3f,
	quat = quat,
	quatf = quatf,
}