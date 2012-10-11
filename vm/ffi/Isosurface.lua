local gl = require "ffi.gl"

local ffi = require "ffi"
local lib = ffi.C

ffi.cdef [[
	typedef struct al_Isosurface al_Isosurface;
	al_Isosurface * al_isosurface_new(int dim);
	void al_isosurface_free(al_Isosurface * self);
	void al_isosurface_level(al_Isosurface * self, double s);
	void al_isosurface_generate(al_Isosurface * self, float * data);
	void al_isosurface_generate_shifted(al_Isosurface * self, float * data, const int sx, const int sy, const int sz);
	void al_isosurface_generate_normals(al_Isosurface * self);
	void al_isosurface_draw(al_Isosurface * self);
	
	Vec3f * al_isosurface_vertices(al_Isosurface * self);
	Vec3f * al_isosurface_normals(al_Isosurface * self);
	unsigned int * al_isosurface_indices(al_Isosurface * self);
	unsigned int al_isosurface_num_indices(al_Isosurface * self);
]]

-- the module:
local Isosurface = {
	generate = lib.al_isosurface_generate,
	level = lib.al_isosurface_level,
	draw = lib.al_isosurface_draw,
}
Isosurface.__index = Isosurface

setmetatable(Isosurface, {
	__call = function(class, dim)
		local s = lib.al_isosurface_new(dim)
		ffi.gc(s, lib.al_isosurface_free)
		return s
	end,
	__index = function(s, k)
		Isosurface[k] = lib["al_isosurface_" .. k]
		return Isosurface[k]
	end,
})

ffi.metatype("al_Isosurface", Isosurface)

return Isosurface