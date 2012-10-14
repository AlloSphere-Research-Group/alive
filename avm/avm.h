#ifndef ALIVE_AVM_H
#define ALIVE_AVM_H

#ifdef __cplusplus
#include <stdint.h>
extern "C" {
#endif

void av_sleep(double seconds);

enum {
	// Standard ASCII non-printable characters 
	AV_KEY_ENTER		=3,		
	AV_KEY_BACKSPACE	=8,		
	AV_KEY_TAB			=9,
	AV_KEY_RETURN		=13,
	AV_KEY_ESCAPE		=27,
	AV_KEY_DELETE		=127,
		
	// Non-standard, but common keys
	AV_KEY_F1=256, 
	AV_KEY_F2, AV_KEY_F3, AV_KEY_F4, AV_KEY_F5, AV_KEY_F6, AV_KEY_F7, AV_KEY_F8, AV_KEY_F9, AV_KEY_F10, AV_KEY_F11, AV_KEY_F12,
	 
	AV_KEY_INSERT, 
	AV_KEY_LEFT, AV_KEY_UP, AV_KEY_RIGHT, AV_KEY_DOWN, 
	AV_KEY_PAGE_DOWN, AV_KEY_PAGE_UP, 
	AV_KEY_END, AV_KEY_HOME
};

typedef struct av_Window {
	int id;
	int width, height;
	int is_fullscreen;
	int button;
	int shift, alt, ctrl;
	
	double fps;
	
	void (*draw)(struct av_Window * self);
	void (*create)(struct av_Window * self);
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
	
	double lag; // in seconds
	
	// only access from audio thread:
	float * input;
	float * output;	
	unsigned int frames;
	void (*callback)(struct av_Audio * self, double sampletime, float * inputs, float * outputs, int frames);
} av_Audio;

typedef enum {
	AV_AUDIO_OTHER = 0,
	AV_AUDIO_CLEAR,
	AV_AUDIO_POS,
	AV_AUDIO_QUAT,
	AV_AUDIO_VOICE_NEW,
	AV_AUDIO_VOICE_FREE,
	AV_AUDIO_VOICE_POS,	
	AV_AUDIO_VOICE_PARAM,
} audiocmd;

typedef union av_audiomsg {
	struct {
		uint32_t cmd;
		uint32_t id;
		union {
			struct { float x, y, z, w; };
			char data[16];
		};
	};
	char str[24];
} av_audiomsg;

typedef struct av_audiomsg_packet {	
	// body goes first so that (audiomsg *) cast works:
	av_audiomsg body;
	// message time (in samples)
	double t;	
} av_audiomsg_packet;

av_Audio * av_audio_get();

// only use from main thread:
void av_audio_start();
av_audiomsg * av_audio_message();
void av_audio_send();

// use only from audio thread:
av_audiomsg * av_audio_peek(double maxtime);
av_audiomsg * av_audio_next(double maxtime);

#ifdef __cplusplus
}
#endif

#endif
