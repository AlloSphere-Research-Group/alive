local ffi = require 'ffi'
local lib = ffi.C

ffi.cdef [[

typedef struct al_Window al_Window;
typedef void (__stdcall *onWindowFunc)(al_Window * win);
typedef void (__stdcall *onWindowResizeFunc)(al_Window * win, int w, int h);
typedef void (__stdcall *onWindowKeyboardFunc)(al_Window * win, const char * event, int key);
typedef void (__stdcall *onWindowMouseFunc)(al_Window * win, const char * event, int b, int x, int y);

enum {
	al_window_SINGLE_BUF	= 1<<0,		
	al_window_DOUBLE_BUF	= 1<<1,		
	al_window_STEREO_BUF	= 1<<2,		
	al_window_ACCUM_BUF		= 1<<3,		
	al_window_ALPHA_BUF		= 1<<4,		
	al_window_DEPTH_BUF		= 1<<5,		
	al_window_STENCIL_BUF	= 1<<6,		
	al_window_MULTISAMPLE	= 1<<7,		
	al_window_DEFAULT_BUF	= al_window_DOUBLE_BUF|al_window_ALPHA_BUF|al_window_DEPTH_BUF 
}; 

al_Window * al_window_new();
void al_window_create(al_Window * win);
void al_window_displaymode(al_Window * win, int mode);
void al_window_startloop(al_Window * win);
void al_window_fullscreen(al_Window * win, int b);
void al_window_cursorhide(al_Window * win, int b);
void al_window_fps(al_Window * win, double v);

int al_window_getfullscreen(al_Window * win);
int al_window_getwidth(al_Window * win);
int al_window_getheight(al_Window * win);
double al_window_getfps(al_Window * win);
double al_window_getfpsactual(al_Window * win);
double al_window_getfpsavg(al_Window * win);

void al_window_oncreate(al_Window * win, onWindowFunc func);
void al_window_onclosing(al_Window * win, onWindowFunc func);
void al_window_onresize(al_Window * win, onWindowResizeFunc func);	
void al_window_ondraw(al_Window * win, onWindowFunc func);
void al_window_onkey(al_Window * win, onWindowKeyboardFunc func);
void al_window_onmouse(al_Window * win, onWindowMouseFunc func);
]]

-- the Window module:
local Window = {
	create = lib.al_window_create,
	startloop = lib.al_window_startloop,
	displaymode = lib.al_window_displaymode,
}
Window.__index = Window

function Window:width()
	return lib.al_window_getwidth(self)
end

function Window:height()
	return lib.al_window_getheight(self)
end

function Window:dim()
	return lib.al_window_getwidth(self), lib.al_window_getheight(self)
end

function Window:fullscreen(b)
	if b ~= nil then
		lib.al_window_fullscreen(self, b ~= false)
		lib.al_window_cursorhide(self, lib.al_window_getfullscreen(self))
	end
	return lib.al_window_getfullscreen(self) ~= 0
end

function Window:fps(v)
	if v then 
		lib.al_window_fps(self, v)
	else
		return lib.al_window_getfps(self)
	end
end

function Window:fpsAvg(v)
	return lib.al_window_getfpsavg(self)
end

function Window:fpsActual(v)
	return lib.al_window_getfpsactual(self)
end

local buttons = {
	[0]="left", "middle", "right", "extra",
}

function Window:__newindex(k, v)
	--print("newindex", self, k, v)
	if k == "create" then
		lib.al_window_oncreate(self, v)
	elseif k == "closing" then
		lib.al_window_onclosing(self, v)
	elseif k == "draw" then
		lib.al_window_ondraw(self, v)
	elseif k == "resize" then
		lib.al_window_onresize(self, v)
	elseif k == "key" then
		lib.al_window_onkey(self, function(self, evt, key)
			return v(self, ffi.string(evt), key)
		end)
	elseif k == "mouse" then
		lib.al_window_onmouse(self, function(self, evt, btn, x, y)
			return v(self, ffi.string(evt), buttons[btn], x, y)
		end)
	else
		error("no window handler: "..k)
	end
end

-- lazy load symbols into Window:
setmetatable(Window, { 
	__call = function(class, ...)
		return lib.al_window_new()
	end,
	
	__index = function(class, k)
		local prefixed = "al_window_"..k
		local v = lib[prefixed]
		class[k] = v
		return v
	end
	
})

ffi.metatype("struct al_Window", Window)

return Window