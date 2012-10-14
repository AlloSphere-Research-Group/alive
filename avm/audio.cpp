
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
		//(audio.callback)(&audio, newtime);
	}
	
	printf(".\n");
	
	audio.time = newtime;
}

void * av_audio_open(int inchannels, int outchannels, double samplerate,int blocksize, int indev, int outdev, int * errptr) {
	PaStream * stream = 0;
	int err = paNoError;
	
	PaStreamParameters inputparams;
	inputparams.device = indev;
	inputparams.channelCount = inchannels;
	inputparams.sampleFormat = paFloat32 | paNonInterleaved;
	inputparams.suggestedLatency = 0;
	inputparams.hostApiSpecificStreamInfo = 0;
	
	PaStreamParameters outputparams;
	outputparams.device = outdev;
	outputparams.channelCount = outchannels;
	outputparams.sampleFormat = paFloat32 | paNonInterleaved;
	outputparams.suggestedLatency = 0;
	outputparams.hostApiSpecificStreamInfo = 0;
	
	err = Pa_IsFormatSupported(
		&inputparams,
		&outputparams,
		samplerate
	);
	
	if (err == paNoError) {
		err = Pa_OpenStream( 
			&stream,
			&inputparams,
			&outputparams,
			samplerate,
			blocksize,
			paNoFlag,
			av_portaudio_callback,
			0
		); 	
	}
	
	*errptr = err;
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
