#ifndef ALIVE_AVM_H
#define ALIVE_AVM_H

#ifdef __cplusplus
extern "C" {
#endif

void av_sleep(double seconds);

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
void av_window_setdim(av_Window * self, int x, int y);


typedef struct av_Audio {
	double time;		// in seconds
	double samplerate;
	unsigned int blocksize;
	unsigned int indevice, outdevice;
	unsigned int inchannels, outchannels;
	
	void (*callback)(struct av_Audio * self, double sampletime);
} av_Audio;

av_Audio * av_audio_get();

void av_audio_start(av_Audio * self);

#ifdef __cplusplus
}
#endif

#endif
