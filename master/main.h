#ifndef MAIN_H
#define MAIN_H

#ifdef __cplusplus
#include "allocore/al_Allocore.hpp"
typedef al::Vec3f vec3f;
typedef al::Vec3d vec3;
typedef al::Vec4f vec4f;
typedef al::Vec4d vec4;
typedef al::Quatf quatf;
typedef al::Quatd quat;
typedef al::Color Color;
extern "C" {
#else
// C declarations here
typedef struct vec3 { double x, y, z; } vec3;
typedef struct vec3f { float x, y, z; } vec3f;
typedef struct vec4 { double x, y, z, w; } vec4;
typedef struct vec4f { float x, y, z, w; } vec4f;
typedef struct quat { double x, y, z, w; } quat;
typedef struct quatf { float x, y, z, w; } quatf;
typedef struct Color { float r, g, b, a; } Color;
#endif

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
	// body goes first so that (audiomsg *) cast works:
	audiomsg body;
	// message time (in samples)
	double t;	
} audiomsg_packet;

typedef struct SpeakerConfig {
	
	vec4 weights;
} SpeakerConfig;

static const int MAX_SPEAKERS = 4;
static const int MAX_AGENTS = 150;

// C-friendly state amenable to FFI in Lua and serialization to disk, network etc.

typedef struct Agent {
	
	// used in rendering:
	Color color;
	quat rotate;
	vec3 position;
	vec3 scale;
	
	// controls:
	vec3 turn, move;
	 
	// cached for simulation:
	vec3 ux, uy, uz;
	vec3 direction;	// from camera
	double distance;	
		
	// audio:
	void (*synthesize)(struct Agent&, int, double, float *);
	vec4 encode; // the previous frame's encoding matrix
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

#ifdef __cplusplus
}
#endif

#endif