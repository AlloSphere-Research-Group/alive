local header = [[
// generated from avm.h on Sat Oct 13 15:07:11 2012
typedef struct av_Window {
 int id;
 int width, height;
 int is_fullscreen;
 int button;
 int shift, alt, ctrl;
 double fps;
 void (*draw)(struct av_Window * self);
 void (*resize)(struct av_Window * self, int w, int h);
 void (*onkey)(struct av_Window * self, int event, int key);
 void (*onmouse)(struct av_Window * self, int event, int button, int x, int y);
} av_Window;
av_Window * av_window_create();
void av_window_setfullscreen(av_Window * self, int b);
void av_window_settitle(av_Window * self, const char * name);
]]
local ffi = require 'ffi'
ffi.cdef(header)
return header