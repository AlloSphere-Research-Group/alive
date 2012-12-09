#ifndef MAIN_H
#define MAIN_H

#ifdef __cplusplus
#include "allocore/al_Allocore.hpp"
typedef al::Vec3f vec3f;
typedef al::Vec3d vec3;
typedef al::Quatf quat;
typedef al::Quatd quatf;
extern "C" {
#else
// C declarations here
typedef struct vec3 { double x, y, z; } vec3;
typedef struct quat { double x, y, z, w; } quat;

typedef struct vec3f { float x, y, z; } vec3f;
typedef struct quatf { float x, y, z, w; } quatf;
#endif

static const int MAX_AGENTS = 256;

// C-friendly state amenable to FFI in Lua and serialization to disk, network etc.

typedef struct Agent {

	quat rotate;
	vec3 translate, scale;
	
} Agent;


typedef struct Shared {
	
	Agent agents[MAX_AGENTS];

	
} Shared;

Shared * app_get();

#ifdef __cplusplus
}
#endif

#endif