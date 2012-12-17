local gl = require "ffi.gl"

local ffi = require "ffi"
local lib = ffi.C

ffi.cdef [[
	typedef struct al_Font al_Font;
	typedef struct al_Mesh al_Mesh;

	al_Font * al_font_new(const char * path, int size, int anti_aliased);
	void al_font_free(al_Font * self);
	
	// returns the width of a text string in pixels
	float al_font_width(al_Font * self, const char * text);
	
	// returns the "above-line" and "below-line" height of the font in pixels
	float al_font_ascender(al_Font * self);
	float al_font_descender(al_Font * self);
	
	// returns the total height of the font in pixels
	float al_font_size(al_Font * self);
	
	void al_font_render(al_Font * self, const char * text);
	
	// al_font_write(font, mesh, "text");
	// al_font_texture_bind(font);
	// al_mesh_draw(mesh);
	// al_font_texture_unbind(font);
	void al_font_write(al_Font * self, al_Mesh * mesh, const char * text);
	void al_font_texture_bind(al_Font * self);	
	void al_font_texture_unbind(al_Font * self);
]]

-- the module:
local Font = {
	width = lib.al_font_width,
	ascender = lib.al_font_ascender,
	descender = lib.al_font_descender,
	size = lib.al_font_size,
	render = lib.al_font_render,
	write = lib.al_font_write,
	texture_bind = lib.al_font_texture_bind,
	texture_unbind = lib.al_font_texture_unbind,
}
Font.__index = Font

setmetatable(Font, {
	__call = function(class, path, size, anti_aliased)
		local s = lib.al_font_new(assert(path, "missing font path"), size or 10, anti_aliased or 1)
		ffi.gc(s, lib.al_font_free)
		return s
	end,
})

ffi.metatype("al_Font", Font)

return Font