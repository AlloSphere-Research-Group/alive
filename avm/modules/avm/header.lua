local header = [[
// generated from avm.h on Fri Oct 12 19:45:02 2012
typedef struct Window {
 int id;
 int width, height;
 int fullscreen;
 void (*onframe)(struct Window * self);
} Window;
Window * window_get();
]]
local ffi = require 'ffi'
ffi.cdef(header)
return header