local gl = require "ffi.gl"

local ffi = require "ffi"
local lib = ffi.C

-- the most likely use is to load an image into a texture.
-- gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, w, h, 0, gl.RGBA, gl.UNSIGNED_BYTE, 0)

ffi.cdef [[
	typedef struct al_Mesh al_Mesh;
	al_Mesh * al_mesh_new();
	void al_mesh_free(al_Mesh * self);
	void al_mesh_reset(al_Mesh * self);
	void al_mesh_scale(al_Mesh * self, double s);
	void al_mesh_draw(al_Mesh * self);
	void al_mesh_import(al_Mesh * self, const char * obj);
	
	void al_mesh_primitive(al_Mesh * self, int primitive);
	void al_mesh_vertex(al_Mesh * self, double x, double y, double z);
	void al_mesh_texcoord2(al_Mesh * self, double x, double y);
	
]]

-- the module:
local Mesh = {
	reset = lib.al_mesh_reset,
	scale = lib.al_mesh_scale,
	import = lib.al_mesh_import,
	draw = lib.al_mesh_draw,
	
	primitive = lib.al_mesh_primitive,
	vertex = lib.al_mesh_vertex,
	texcoord2 = lib.al_mesh_texcoord2,
}
Mesh.__index = Mesh

setmetatable(Mesh, {
	__call = function(class, path)
		local s = lib.al_mesh_new()
		ffi.gc(s, lib.al_mesh_free)
		return s
	end,
})

ffi.metatype("al_Mesh", Mesh)

return Mesh