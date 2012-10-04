#ifndef ALIVE_H
#define ALIVE_H

#ifdef __cplusplus

#include "al_ffi.h"

extern "C" {
#else
typedef struct al_Window al_Window;
#endif

	typedef int (*idle_callback)(int status);
	typedef int (*buffer_callback)(char * buffer, int size);
	typedef int (*filewatcher_callback)(const char * filename);
	
	void idle(idle_callback cb);
	
	void openfile(const char * path, buffer_callback cb);
	void openfd(int fd, buffer_callback cb);
	void watchfile(const char * filename, filewatcher_callback cb);
	
	al_Window * alive_window();
	void alive_tick();
	
	void al_sleep(double);
	
		
	typedef void (*audio_callback)(double sampletime);
	
	float * audio_outbuffer(int chan);
	const float * audio_inbuffer(int chan);
	float * audio_busbuffer(int chan);
	float audio_samplerate();
	int audio_buffersize();
	int audio_channelsin();
	int audio_channelsout();	
	int audio_channelsbus();
	double audio_time();
	void audio_zeroout();
	double audio_cpu();
	void audio_set_callback(audio_callback cb);
	
	typedef struct audiomsg {
		double t;
		char data[24];
	} audiomsg;
	
	audiomsg * audioq_peek(void);
	audiomsg * audioq_next(void);
	
	al_Window * al_window_get();

#ifdef __cplusplus
}
#endif

#endif