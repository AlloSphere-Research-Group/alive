local gl = require "ffi.gl"

local ffi = require "ffi"
local lib = ffi.C

-- the most likely use is to load an image into a texture.
-- gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, w, h, 0, gl.RGBA, gl.UNSIGNED_BYTE, 0)

ffi.cdef[[
	typedef struct al_Image al_Image;
	
	al_Image * al_image_new();
	void al_image_free(al_Image * im);
	int al_image_load(al_Image * im, const char * filepath);
	void * al_image_pixels(al_Image * im);
	int al_image_width(al_Image * im);
	int al_image_height(al_Image * im);
	int al_image_format(al_Image * im);
	
	int al_image_write(const char * path, uint8_t * pixels, int w, int h, int channels);
]]

-- the module:
local Image = {
	["load"] = lib.al_image_load,
	pixels = lib.al_image_pixels,
	width = lib.al_image_width,
	height = lib.al_image_height,
	format = lib.al_image_format,
	
	write = lib.al_image_write,
}
Image.__index = Image

setmetatable(Image, {
	__call = function(class, path)
		local im = lib.al_image_new()
		ffi.gc(im, lib.al_image_free)
		if path then
			im:load(path)
		end
		return im
	end,
})

ffi.metatype("al_Image", Image)

return Image