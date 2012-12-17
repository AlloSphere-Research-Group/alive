local gl = require "ffi.gl"

local ffi = require "ffi"
local lib = ffi.C

-- the most likely use is to load an image into a texture.
-- gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, w, h, 0, gl.RGBA, gl.UNSIGNED_BYTE, 0)

local header = [[
	typedef struct al_HashSpace al_HashSpace;
	
	al_HashSpace * al_hashspace_new(int resolution, int objects);
	void al_hashspace_free(al_HashSpace * self);
	
	void al_hashspace_move(al_HashSpace * self, int id, double x, double y, double z);
	void al_hashspace_remove(al_HashSpace * self, int id);
	
	int al_hashspace_nearest(al_HashSpace * self, int id, double maxradius);
]]

local cppheader = [[
extern "C" {
]] .. header .. [[
}
]]



ffi.cdef(header)

-- the module:
local HashSpace = {
	move = lib.al_hashspace_move,
	remove = lib.al_hashspace_remove,
	nearest = lib.al_hashspace_nearest,
	cppheader = cppheader,
}
HashSpace.__index = HashSpace

setmetatable(HashSpace, {
	__call = function(class, resolution, objects)
		local x = lib.al_hashspace_new(resolution or 5, objects or 0)
		--ffi.gc(x, lib.al_hashspace_free)
		return x
	end,
})

ffi.metatype("al_HashSpace", HashSpace)

return HashSpace