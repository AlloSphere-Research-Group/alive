#ifndef ALIVE_AVM_DEV_H
#define ALIVE_AVM_DEV_H

#include "avm.h"

#if defined(WIN32) || defined(__WINDOWS_MM__) || defined(WIN64)
	#define AV_WINDOWS 1
	// just placeholder really; Windows requires a bit more work yet.

#elif defined( __APPLE__ ) && defined( __MACH__ )
	#define AV_OSX 1
	#include <OpenGL/OpenGL.h>
	#include <GLUT/glut.h>

#else
	#define AV_LINUX 1
	#include <GL/gl.h>
	#include <GL/glut.h>
	
#endif

extern "C" {
	#include "lua.h"
	#include "lualib.h"
	#include "lauxlib.h"
}

#include "stdlib.h"

extern "C" {
	void av_tick();
	
	lua_State * av_init_lua();
}

/*
	A simple FIFO queue
	For fixed-size message types
	Designed for single-reader, single-writer thread communication
*/
template<typename T>
struct Q {
	T * q;
	int size, wrap;
	volatile int read, write;
	
	Q(int count = 16384) {
		size = count;
		wrap = size - 1;
		q = (T *)malloc(sizeof(T) * size);
		memset(q, 0, sizeof(q));
		read = write = 0;
	}
	
	~Q() {
		free(q);
	}
	
	// sender thread:
	T * head() const {
		if (read == ((write + 1) & wrap)) {
			// try sleeping a little bit first:
			av_sleep(0.01);
			if (read == ((write + 1) & wrap)) {
				printf("queue overflow, cannot send\n");
				return 0;
			}
		}
		return &q[write];
	}
	void send() { write = (write + 1) & wrap; }

	// receiver thread:
	T * peek() const {
		return read == write ? 0 : &q[read];
	}
	void next() {
		read = (read + 1) & wrap;
	}
	
	double used() const {
		return ((size + write - read) & wrap)/double(size);
	}
};

#endif
