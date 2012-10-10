#include "alive.h"
#include "al_ffi.h"
#include "uv_utils.h"

#include "syslimits.h"

#include "allocore/io/al_AudioIO.hpp"
#include "allocore/graphics/al_Graphics.hpp"
#include "allocore/math/al_Random.hpp"
#include "allocore/system/al_Time.hpp"
#include "alloutil/al_Lua.hpp"

using namespace al;

////////////////////////////////////////////////////////////////////////////////

void idle(idle_callback cb) {
	new Idler(uv_default_loop(), cb);
}

void openfile(const char * path, buffer_callback cb) {
	new FileOpen(uv_default_loop(), path, cb);
}

void openfd(int fd, buffer_callback cb) {
	new FdOpen(uv_default_loop(), fd, cb);
}

void watchfile(const char * filename, filewatcher_callback cb) {
	new FileWatcher(uv_default_loop(), filename, cb);
}

//////////////////////////////////////////////////////////////////////////////////

/*
	Since the audio thread clears the queue so much faster, 
	the main bottleneck is how many pending messages per frame,
	and how much the audiolag adds to this.
	
	To deal with clock drift, use the audio clock for the main thread time
	(audio time plus audiolag)
	but a backup is needed if the audio thread is inactive
		
	Another problem is how to cache messages if overflow occurs.
	A brief sleep is tried first, but then fall back to a heap queue?
		Check if audio is still active?
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
			al_sleep(0.01);
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
		printf("%d %d\n", read, write);
		return ((size + write - read) & wrap)/double(size);
	}
};


////////////////////////////////////////////////////////////////////////////////

rnd::Random<> rng1;
uv_loop_t *loop;
Lua L, LA;
AudioIO audio;
Q<audiomsg_packet> audioq;
double audiotime = 0;
double maintime = 0;
double audiolag = 2000; // in samples
uv_loop_t *audioloop;
audio_callback audiocb = 0;
al_Window win;

al_Window * alive_window() {
	return &win;
}

void alive_tick() {
	//printf("uv\n");
	int res = uv_run_once(loop);
	//printf("%d\n", res);
	
	fflush(stdin);
	fflush(stdout);
	fflush(stderr);
	
	// process scheduled events up to t:
	double t = audiotime + audiolag;
	// (task queue loop goes here)
	maintime = t;
	
//	printf("used %04.1f%%\n", 100.*audioq.used() );
}

////////////////////////////////////////////////////////////////////////////////

float * audio_outbuffer(int chan) { return audio.outBuffer(chan); }
const float * audio_inbuffer(int chan) { return audio.inBuffer(chan); }
float * audio_busbuffer(int chan) { return audio.busBuffer(chan); }
float audio_samplerate() { return audio.fps(); }
int audio_buffersize() { return audio.framesPerBuffer(); }
int audio_channelsin() { return audio.channelsIn(); }
int audio_channelsout() { return audio.channelsOut(); }
int audio_channelsbus() { return ((al::AudioIOData &)audio).channelsBus(); }
double audio_time() { return audiotime; }
void audio_zeroout() { audio.zeroOut(); }
double audio_cpu() { return audio.cpu(); }

void audio_set_callback(audio_callback cb) {
	audiocb = cb;
}

audiomsg * audioq_head() {
	return (audiomsg *)audioq.head();
}
void audioq_send() {
	audioq.q[audioq.write].t = audiotime + audiolag;
	audioq.send();
}

audiomsg * audioq_peek(double maxtime) {
	audiomsg_packet * p = audioq.peek();
	return (p && p->t < maxtime) ? (audiomsg *)p : 0;
}
audiomsg * audioq_next(double maxtime) {
	audioq.next();
	return audioq_peek(maxtime);
}

void audioCB(al::AudioIOData& io) {

	if (audiotime == 0) {
		printf("audio started %d %f\n", io.framesPerBuffer(), io.framesPerSecond());
	}

	double nexttime = audiotime + io.framesPerBuffer();
	
	// libuv in audio thread?
	uv_run_once(audioloop);
	
	if (audiocb) audiocb(audiotime);
	
	//printf(".\n");
	
	audiotime = nexttime;

	//if (io.time() < 0.1) printf("audio thread %lu\n", uv_thread_self());
}

int modifedaudiolua(const char * filename) {
	printf("modified %s\n", filename);
	return LA.dofile(filename) == 0;
}

int modifedmainlua(const char * filename) {
	printf("modified %s\n", filename);
	int result = L.dofile(filename);
	printf("result %d\n", result);
	return 1;
}

int audio_idle(int status) {
	return 1;
}

int main_idle(int status) {
	//printf("main_idle\n");
	return 1;
}

int main(int argc, char * argv[]) {

	// execute in the context of wherever this is run from:
	chdir("./");
	
	// do not abort if SIGPIPE is received:
	// i.e. KILL THE ZOMBIES
	signal(SIGPIPE, SIG_IGN);

	// initialize libuv:
	loop = uv_default_loop();
	audioloop = uv_loop_new();
	
	// configure audio:
	audio.framesPerBuffer(256);
	audio.callback = audioCB;
	
	// set up the Lua state(s):
	lua_newtable(L);
	for (int i=0; i<argc; i++) {
		lua_pushstring(L, argv[i]);
		lua_rawseti(L, -2, i+1);
	}
	lua_setglobal(L, "argv");
	
	const char * main_filename = "./alivetest.lua";
	if (modifedmainlua(main_filename) == 0) return -1;
	new FileWatcher(uv_default_loop(), main_filename, modifedmainlua);
	// for some reason need this to stop loop from blocking:
	new Idler(uv_default_loop(), main_idle);
	
	/*
	lua_newtable(LA);
	for (int i=0; i<argc; i++) {
		lua_pushstring(LA, argv[i]);
		lua_rawseti(LA, -2, i+1);
	}
	lua_setglobal(LA, "argv");
	
	const char * audio_filename = "./alivetestaudio.lua";
	if (modifedaudiolua(audio_filename) == 0) return -1;
	new FileWatcher(audioloop, audio_filename, modifedaudiolua);
	// for some reason need this to stop loop from blocking:
	new Idler(audioloop, audio_idle);
	
	// start threads:
	audio.start();
	*/
	
	win.create(al::Window::Dim(400, 800), "alive");
	win.startLoop();
	
	return 0;
}
