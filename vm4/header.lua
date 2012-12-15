local header = [[
// generated from main.h on Fri Dec 14 16:31:34 2012
typedef struct vec3 { double x, y, z; } vec3;
typedef struct vec3f { float x, y, z; } vec3f;
typedef struct vec4 { double x, y, z, w; } vec4;
typedef struct vec4f { float x, y, z, w; } vec4f;
typedef struct quat { double x, y, z, w; } quat;
typedef struct quatf { float x, y, z, w; } quatf;
typedef struct Color { float r, g, b, a; } Color;
typedef enum {
 AUDIO_OTHER = 0,
 AUDIO_CLEAR,
 AUDIO_POS,
 AUDIO_QUAT,
 AUDIO_VOICE_NEW,
 AUDIO_VOICE_FREE,
 AUDIO_VOICE_POS,
 AUDIO_VOICE_PARAM,
} audiocmd;
typedef union audiomsg {
 struct {
  uint32_t cmd;
  uint32_t id;
  union {
   struct { float x, y, z, w; };
   char data[16];
  };
 };
 char str[24];
} audiomsg;
typedef struct audiomsg_packet {
 audiomsg body;
 double t;
} audiomsg_packet;
typedef struct SpeakerConfig {
 vec4 weights;
} SpeakerConfig;
static const int MAX_SPEAKERS = 4;
static const int MAX_AGENTS = 150;
typedef struct Agent {
 Color color;
 quat rotate;
 vec3 position;
 vec3 scale;
 vec3 turn, move;
 vec3 ux, uy, uz;
 vec3 direction;
 double distance;
 void (*synthesize)(struct Agent&, int, double, float *);
 vec4 encode;
 double freq, phase;
} Agent;
typedef struct Shared {
 Agent agents[MAX_AGENTS];
 SpeakerConfig speakers[MAX_SPEAKERS];
 int numActiveSpeakers;
 float audiogain;
 void (*update)(struct Shared& app, double dt);
} Shared;
Shared * app_get();
]]
local ffi = require 'ffi'
ffi.cdef(header)
return header