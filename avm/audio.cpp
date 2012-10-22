
#include "avm_dev.h"
#include "uv_utils.h"

#include "RtAudio.h"
#include "math.h"

static av_Audio audio;

// the internal object:
static RtAudio rta;

// the message queue for the audio thread:
static Q<av_audiomsg_packet> audioq;

// the audio-thread UV loop:
static uv_loop_t * loop;
// the audio-thread Lua state:
static lua_State * L = 0;


av_audiomsg * av_audio_message() {
	return (av_audiomsg *)audioq.head();
}
void av_audio_send() {
	audioq.q[audioq.write].t = audio.time + audio.lag;
	audioq.send();
}

av_audiomsg * av_audio_peek(double maxtime) {
	av_audiomsg_packet * p = audioq.peek();
	return (p && p->t < maxtime) ? (av_audiomsg *)p : 0;
}
av_audiomsg * av_audio_next(double maxtime) {
	audioq.next();
	return av_audio_peek(maxtime);
}

// any idle process for audio UV loop:
int idle(int status) {
	return 1;
}

int av_rtaudio_callback(void *outputBuffer, 
						void *inputBuffer, 
						unsigned int frames,
						double streamTime, 
						RtAudioStreamStatus status, 
						void *data) {
	// catch up with UV events:
	uv_run_once(loop);
						
	audio.input = (float *)inputBuffer;
	audio.output = (float *)outputBuffer;
	audio.frames = frames;
	
	double newtime = audio.time + frames / audio.samplerate;
	
	// zero outbuffers:
	memset(outputBuffer, 0, sizeof(float) * frames);
	
	// this calls back into Lua:
	if (audio.onframes) {
		(audio.onframes)(&audio, newtime, audio.input, audio.output, frames);
	}
	
	audio.time = newtime;
	
	return 0;
}

void av_audio_start() {

	if (!rta.isStreamRunning()) {
		if (rta.isStreamOpen()) {
			// close it:
			rta.closeStream();
		}	
		
		unsigned int devices = rta.getDeviceCount();
		if (devices < 1) {
			printf("no audio devices found\n");
			return;
		}
		
		RtAudio::DeviceInfo info;
		
		info = rta.getDeviceInfo(audio.indevice);
		printf("input %d: %dx%d (%d) %s\n", audio.indevice, info.inputChannels, info.outputChannels, info.duplexChannels, info.name.c_str());
		
		info = rta.getDeviceInfo(audio.outdevice);
		printf("output %d: %dx%d (%d) %s\n", audio.outdevice, info.inputChannels, info.outputChannels, info.duplexChannels, info.name.c_str());
		
		RtAudio::StreamParameters iParams, oParams;
		
		iParams.deviceId = audio.indevice;
		iParams.nChannels = audio.inchannels;
		iParams.firstChannel = 0;
		
		oParams.deviceId = audio.outdevice;
		oParams.nChannels = audio.outchannels;
		oParams.firstChannel = 0;

		RtAudio::StreamOptions options;
		options.flags |= RTAUDIO_NONINTERLEAVED;
		options.streamName = "av";
		
		try {
			rta.openStream( &oParams, &iParams, RTAUDIO_FLOAT32, audio.samplerate, &audio.blocksize, &av_rtaudio_callback, NULL, &options );
			rta.startStream();
		}
		catch ( RtError& e ) {
			fprintf(stderr, "%s\n", e.getMessage().c_str());
		}
	}
}

av_Audio * av_audio_get() {
	static bool initialized = false;
	if (!initialized) {
		
		rta.showWarnings( true );		
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
		audio.lag = 0.04;
		audio.indevice = rta.getDefaultInputDevice();
		audio.outdevice = rta.getDefaultOutputDevice();
		
		audio.onframes = 0;
		
		initialized = true;
		
		L = av_init_lua();
		
		// unique to audio thread:
		if (luaL_dostring(L, "require 'avm.audiothread'")) {
			printf("error: %s\n", lua_tostring(L, -1));
		}
	}
	return &audio;
}
