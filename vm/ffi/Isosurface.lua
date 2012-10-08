local gl = require "ffi.gl"

local ffi = require "ffi"
local lib = ffi.C

ffi.cdef [[
	typedef struct al_Isosurface al_Isosurface;
	al_Isosurface * al_isosurface_new();
	void al_isosurface_free(al_Isosurface * self);
	void al_isosurface_level(al_Isosurface * self, double s);
	void al_isosurface_generate(al_Isosurface * self, float * data, int dim);
	void al_isosurface_draw(al_Isosurface * self);
	
]]

-- the module:
local Isosurface = {
	generate = lib.al_isosurface_generate,
	level = lib.al_isosurface_level,
	draw = lib.al_isosurface_draw,
}
Isosurface.__index = Isosurface

setmetatable(Isosurface, {
	__call = function(class, path)
		local s = lib.al_isosurface_new()
		ffi.gc(s, lib.al_isosurface_free)
		return s
	end,
})

ffi.metatype("al_Isosurface", Isosurface)

return Isosurface