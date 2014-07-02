local header = [[
// generated from main.h on Wed Jul  2 17:17:38 2014
typedef struct vec3 { double x, y, z; } vec3;
typedef struct vec3f { float x, y, z; } vec3f;
typedef struct vec4 { double x, y, z, w; } vec4;
typedef struct vec4f { float x, y, z, w; } vec4f;
typedef struct quat { double x, y, z, w; } quat;
typedef struct quatf { float x, y, z, w; } quatf;
typedef struct Color { float r, g, b, a; } Color;
typedef struct Pose { vec3 position; quat rotate; } Pose;
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
static const int WORLD_DIM = 32;
static const int DOPPLER_SAMPLES = 4096;
static const int TRAIL_LENGTH = 8;
typedef struct Trail {
 quat rotate;
 vec3 position;
} Trail;
typedef struct Agent {
 Color color;
 quat rotate;
 vec3 position;
 vec3 scale;
 int32_t enable, visible;
 double velocity, acceleration;
 vec3 turn, twist;
 int32_t id, nearest;
 double nearest_distance;
 vec3 ux, uy, uz;
 Trail trails[TRAIL_LENGTH];
 int32_t trail_start, trail_size;
} Agent;
typedef struct Shared {
 Agent agents[MAX_AGENTS];
 Pose view;
 vec3 active_origin;
 Color bgcolor;
 uint32_t framecount;
 uint32_t mode;
 uint32_t show_collisions;
 float eyesep;
} Shared;
typedef struct Voice {
 float buffer[DOPPLER_SAMPLES];
 vec4 encode;
 vec3 direction;
 double distance;
 uint32_t buffer_index;
 uint32_t iphase;
 double amp, freq, phase;
 int32_t id;
 void (*synthesize)(struct Voice&, int frames, float * out);
} Voice;
typedef struct Global {
 Shared shared;
 Voice voices[MAX_AGENTS];
 SpeakerConfig speakers[MAX_SPEAKERS];
 double doppler_strength;
 int32_t numActiveSpeakers;
 float audiogain, reverbgain;
 void (*update)(struct Global& app, double dt);
} Global;
void agent_reset(Agent& a);
Global * global_get();
]]
local ffi = require 'ffi'
ffi.cdef(header)
return header