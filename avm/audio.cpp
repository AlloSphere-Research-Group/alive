
#include "avm_dev.h"
#include "uv_utils.h"

#include "RtAudio.h"

#include <iostream>
#include <map>

// the FFI-friendly object:
static av_Audio audio;

// the internal object:
static RtAudio rta;

// the audio-thread UV loop:
static uv_loop_t * loop;
// the audio-thread Lua state:
static lua_State * L = 0;

// any idle process for audio UV loop:
int idle(int status) {
	return 1;
}

// for debugging:
float p;

int av_rtaudio_callback(void *outputBuffer, 
						void *inputBuffer, 
						unsigned int frames,
						double streamTime, 
						RtAudioStreamStatus status, 
						void *data) {
	// catch up with UV events:
	uv_run_once(loop);
						
	//float * input = (float *)inputBuffer;
	float * output = (float *)outputBuffer;
	
	double newtime = audio.time + frames * audio.samplerate;
	
	float * out0 = output;
	float * out1 = output + frames;
	
	for (unsigned int i=0; i<frames; i++) {
		p = p + 440 * M_PI * 2./audio.samplerate;
		out0[i] = sin(p);
		out1[i] = out0[i];
	}
	
	
	if (audio.callback) {
		//(audio.callback)(&audio, newtime);
	}
	
	audio.time = newtime;
	
	return 0;
}


void av_audio_start(av_Audio * self) {
	
	unsigned int devices = rta.getDeviceCount();
	if (devices < 1) {
		printf("no audio devices found\n");
		return;
	}
	
	RtAudio::DeviceInfo info;
	
	info = rta.getDeviceInfo(self->indevice);
	printf("input %d: %dx%d (%d) %s\n", self->indevice, info.inputChannels, info.outputChannels, info.duplexChannels, info.name.c_str());
	
	info = rta.getDeviceInfo(self->outdevice);
	printf("output %d: %dx%d (%d) %s\n", self->outdevice, info.inputChannels, info.outputChannels, info.duplexChannels, info.name.c_str());
	
	RtAudio::StreamParameters iParams, oParams;
	iParams.deviceId = self->indevice;
	iParams.nChannels = self->inchannels;
	iParams.firstChannel = 0;
	
	oParams.deviceId = self->outdevice;
	oParams.nChannels = self->outchannels;
	oParams.firstChannel = 0;

	RtAudio::StreamOptions options;
	options.flags |= RTAUDIO_NONINTERLEAVED;
	options.streamName = "av";
	
	try {
		rta.openStream( &oParams, &iParams, RTAUDIO_FLOAT32, self->samplerate, &self->blocksize, &av_rtaudio_callback, NULL, &options );
		rta.startStream();
	}
	catch ( RtError& e ) {
		fprintf(stderr, "%s\n", e.getMessage().c_str());
	}
}

av_Audio * av_audio_get() {
	static bool initialized = false;
	if (!initialized) {
		
		rta.showWarnings( true );
		
		L = av_init_lua();
		
		loop = uv_loop_new();
		// for some reason need this to stop loop from blocking:
		// (maybe uv_ref() would have the same effect?)
		new Idler(loop, idle);
		
		// set defaults:
		audio.samplerate = 44100;
		audio.blocksize = 256;
		audio.inchannels = 2;
		audio.outchannels = 2;
		audio.time = 0;
		audio.callback = 0;
		audio.indevice = rta.getDefaultInputDevice();
		audio.outdevice = rta.getDefaultOutputDevice();
		
		initialized = true;
	}
	return &audio;
}
