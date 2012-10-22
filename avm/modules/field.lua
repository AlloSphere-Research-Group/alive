local ffi = require "ffi"
local C = ffi.C

local floor = math.floor

local vec = require "vec"
local vec3, quat = vec.vec3, vec.quat

local Field = {}
Field.__index = Field

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
	local paaa = self:index(a.x, a.y, a.z);
	local paab = self:index(a.x, a.y, b.z);
	local paba = self:index(a.x, b.y, a.z);
	local pabb = self:index(a.x, b.y, b.z);
	local pbaa = self:index(b.x, a.y, a.z);
	local pbab = self:index(b.x, a.y, b.z);
	local pbba = self:index(b.x, b.y, a.z);
	local pbbb = self:index(b.x, b.y, b.z);
	self.data[paaa] = self.data[paaa] + value * faaa;
	self.data[pbaa] = self.data[pbaa] + value * fbaa;
	self.data[paba] = self.data[paba] + value * faba;
	self.data[paab] = self.data[paab] + value * faab;
	self.data[pbab] = self.data[pbab] + value * fbab;
	self.data[pabb] = self.data[pabb] + value * fabb;
	self.data[pbba] = self.data[pbba] + value * fbba;
	self.data[pbbb] = self.data[pbbb] + value * fbbb;
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

Field.noise = Field.map_rec(function(current, x, y, z, factor)
	return current + srandom()*factor
end)

Field.decay = Field.map_rec(function(current, x, y, z, factor)
	return current * factor
end)

Field.min = Field.map_rec(function(current, x, y, z, factor)
	return min(current, factor)
end)

setmetatable(Field, {
	__call = function(_, dim)
		local size = dim.x * dim.y * dim.z
		local stridey = dim.x
		local stridez = stridey * dim.y
		return setmetatable({
			dim = dim,
			size = size,
			stride = vec3(1, stridey, stridez),
			data = ffi.new("float[?]", size),
			back = ffi.new("float[?]", size),
		}, Field)
	end
})

return Field