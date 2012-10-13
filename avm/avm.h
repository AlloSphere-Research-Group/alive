#ifndef ALIVE_AVM_H
#define ALIVE_AVM_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct Window {
	int id;
	int width, height;
	int fullscreen;
	
	void (*onframe)(struct Window * self);
} Window;

Window * window_get();

#ifdef __cplusplus
}
#endif

#endif
