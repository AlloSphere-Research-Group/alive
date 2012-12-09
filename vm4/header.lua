local header = [[
// generated from main.h on Sun Dec  9 11:41:31 2012
typedef struct vec3 { double x, y, z; } vec3;
typedef struct quat { double x, y, z, w; } quat;
typedef struct vec3f { float x, y, z; } vec3f;
typedef struct quatf { float x, y, z, w; } quatf;
static const int MAX_AGENTS = 256;
typedef struct Agent {
 quat rotate;
 vec3 translate, scale;
} Agent;
typedef struct Shared {
 Agent agents[MAX_AGENTS];
} Shared;
Shared * app_get();
]]
local ffi = require 'ffi'
ffi.cdef(header)
return header