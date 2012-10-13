#ifndef ALIVE_AVM_DEV_H
#define ALIVE_AVM_DEV_H

#include "avm.h"

#ifdef __APPLE__
#include <OpenGL/OpenGL.h>
#include <GLUT/glut.h>
#else
#include <GL/gl.h>
#include <GL/glut.h>
#endif

extern "C" {
	#include "lua.h"
	#include "lualib.h"
	#include "lauxlib.h"
}


extern "C" {
	void av_tick();
}

#endif
