local ffi = require "ffi"
local lib = ffi.C

local header = [[
	typedef struct al_Fluid al_Fluid;
	typedef struct al_Field al_Field;
	typedef struct Vec3f { float x, y, z; } Vec3f;

	al_Fluid * al_fluid_new(int dimx, int dimy, int dimz);
	void al_fluid_free(al_Fluid * self);
	void al_fluid_update(al_Fluid * self);
	float * al_fluid_ptr(al_Fluid * self);
	void al_fluid_add_gradient(al_Fluid * self, double x, double y, double z, float g);
	void al_fluid_add_velocity(al_Fluid * self, double x, double y, double z, double vx, double vy, double vz);
	Vec3f al_fluid_velocity(al_Fluid * self, double x, double y, double z);
		
	al_Field * al_field_new(int components, int dimx, int dimy, int dimz);
	void al_field_free(al_Field * self);
	void al_field_add(al_Field * self, double x, double y, double z, float * data);
	void al_field_diffuse(al_Field * self, double diffusion);
	void al_field_advect(al_Field * self, al_Fluid * fluid, double amt);
	void al_field_scale(al_Field * self, double amt);
	float * al_field_ptr(al_Field * self);
]]
ffi.cdef(header)

local cppheader = [[
extern "C" {
]] .. header .. [[
}
]]

-- the module:
local Fluid = {
	update = lib.al_fluid_update,
	ptr = lib.al_fluid_ptr,
	add_gradient = lib.al_fluid_add_gradient,
	add_velocity = lib.al_fluid_add_velocity,
	velocity = lib.al_fluid_velocity,
}
Fluid.__index = Fluid

setmetatable(Fluid, {
	__call = function(class, dim)
		local s = lib.al_fluid_new(dim or 32)
		--ffi.gc(s, lib.al_fluid_free)
		return s
	end,
})

ffi.metatype("al_Fluid", Fluid)

-- the module:
local Field = {
	add = lib.al_field_add,
	diffuse = lib.al_field_diffuse,
	advect = lib.al_field_advect,
	scale = lib.al_field_scale,
	ptr = lib.al_field_ptr,
}
Field.__index = Field

setmetatable(Field, {
	__call = function(class, components, dim)
		local s = lib.al_field_new(components or 3, dim or 32)
		--ffi.gc(s, lib.al_field_free)
		return s
	end,
})

ffi.metatype("al_Field", Field)

Fluid.Field = Field
Fluid.cppheader = cppheader

return Fluid