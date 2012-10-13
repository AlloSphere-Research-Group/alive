
#include "avm_dev.h"

av_Audio audio;


unsigned long framecount;

int av_portaudio_callback(	const void *input, 
							void *output,
							unsigned long frameCount,
							const PaStreamCallbackTimeInfo* timeInfo,
							PaStreamCallbackFlags statusFlags,
							void *userData ) {
	
	double newtime = audio.time + frameCount * audio.samplerate;
	
	if (audio.callback) {
		(audio.callback)(&audio, newtime);
	}
	
	printf(".\n");
	
	audio.time = newtime;
}

void * av_audio_open(int inchannels, int outchannels, double samplerate,int blocksize, int * err) {
	PaStream * stream;
	*err = Pa_OpenDefaultStream(
		&stream,
		inchannels,
		outchannels,
		paFloat32 | paNonInterleaved,
		samplerate,
		(unsigned long)blocksize,
		av_portaudio_callback,
		0
	);
	return stream;
}

void av_audio_init() {
	static bool initialized = 0;
	if (initialized) return;
	
	audio.samplerate = 44100;
	audio.time = 0;
	
	audio.callback = 0;
	
	initialized = 1;
}

av_Audio * av_audio_get() {
	return &audio;
}