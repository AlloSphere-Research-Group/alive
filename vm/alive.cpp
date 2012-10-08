#include "alive.h"
#include "al_ffi.h"
#include "uv.h"

#include "stdio.h"
#include "stdlib.h"
#include "syslimits.h"
#include "unistd.h"
#include "fcntl.h"

#include "allocore/io/al_AudioIO.hpp"
#include "allocore/graphics/al_Graphics.hpp"
#include "allocore/math/al_Random.hpp"
#include "allocore/system/al_Time.hpp"
#include "alloutil/al_Lua.hpp"

using namespace al;

////////////////////////////////////////////////////////////////////////////////

struct FileOpen {	
	uv_fs_t open_req;
	uv_fs_t stat_req;
	uv_fs_t read_req;
	uv_fs_t close_req;
	buffer_callback cb;
	char path[1024];
	char * buffer;
	int32_t size;
	
	FileOpen(uv_loop_t * loop, const char * path, buffer_callback cb) {
		open_req.data = this;
		read_req.data = this;
		stat_req.data = this;
		close_req.data = this;
		this->cb = cb;
		strcpy(this->path, path);
		buffer = 0;
		size = 0;
		
		uv_fs_open(loop, &open_req, path, O_RDONLY, 0, static_open);
	}

	~FileOpen() {
		//printf("released memory\n");
	}
	
	void open(uv_fs_t& req) {
		//printf("on_open %p %p %d\n", &req, this, (int)req.result);
		// need to know file size to allocate a buffer for it...
		uv_fs_stat(req.loop, &stat_req, path, static_stat);
		uv_fs_req_cleanup(&req);
	}
	
	void stat(uv_fs_t& req) {
		//printf("on_stat %p %p %d\n", &req, req.ptr, (int)req.result);
		if (req.result < 0) {
			fprintf(stderr, "error opening file: %d\n", req.errorno);
			uv_fs_close(req.loop, &close_req, open_req.result, static_close);
		} else {
			struct stat *s = (struct stat *)req.ptr;
			size = s->st_size;
			buffer = (char *)malloc(size + 1); // extra char for null terminator
			buffer[size] = '\0';
			
			// now trigger read:
			uv_fs_read(req.loop, &read_req, open_req.result, buffer, size, -1, static_read);
		}
		uv_fs_req_cleanup(&req);
	}
	
	void read(uv_fs_t& req) {
		//printf("on_read %p %p %d\n", &req, req.data, (int)req.result);
		if (req.result < 0) {
			fprintf(stderr, "Read error: %s\n", uv_strerror(uv_last_error(req.loop)));
		} else if (req.result != 0) {
			cb(buffer, size);
		}
		uv_fs_close(req.loop, &close_req, open_req.result, static_close);
		uv_fs_req_cleanup(&req);
		
		// recycle:
		if (buffer) { free(buffer); }
	}
	
	void close(uv_fs_t& req) {
		//printf("on close %p %p %d\n", &req, this, (int)req.result);
		uv_fs_req_cleanup(&req);
		delete this;
	}
	
	static void static_read(uv_fs_t *req) { ((FileOpen *)(req->data))->read(*req); }
	static void static_open(uv_fs_t *req) { ((FileOpen *)(req->data))->open(*req); }
	static void static_stat(uv_fs_t *req) { ((FileOpen *)(req->data))->stat(*req); }
	static void static_close(uv_fs_t *req) { ((FileOpen *)(req->data))->close(*req); }
};

struct FdOpen {
	int fd;
	buffer_callback cb;
	uv_pipe_t pipe;

	FdOpen(uv_loop_t * loop, int fd, buffer_callback cb) {
		this->fd = fd;
		this->cb = cb;
		pipe.data = this;
		
		uv_pipe_init(loop, &pipe, 0);
		uv_pipe_open(&pipe, fd); 
		uv_read_start((uv_stream_t*)&pipe, alloc_buffer, static_read);
	}
	
	~FdOpen() {
		uv_close((uv_handle_t*)&pipe, NULL);
	}
	
	void read(uv_stream_t& stream, ssize_t nread, uv_buf_t& buf) {
		if (nread == -1) {
			if (uv_last_error(stream.loop).code == UV_EOF) {
				delete this;
			}
		} else {
			if (nread > 0) {
				if (cb(buf.base, nread - 1) == 0) {
					// kill it.
					free(buf.base);
					uv_read_stop((uv_stream_t*)&pipe);
					delete this;
				}
			}
		}
		// recycle:
		if (buf.base) { free(buf.base); }
		
		//void uv_close(uv_handle_t* handle, uv_close_cb close_cb)
	}
	
	static void static_read(uv_stream_t *stream, ssize_t nread, uv_buf_t buf) {
		((FdOpen *)(stream->data))->read(*stream, nread, buf); 
	}
	
	static uv_buf_t alloc_buffer(uv_handle_t *handle, size_t suggested_size) {
		return uv_buf_init((char*) malloc(suggested_size), suggested_size);
	}
};

struct Idler {
	uv_idle_t handle;
	idle_callback cb;
	
	Idler(uv_loop_t * loop, idle_callback cb) {
		handle.data = this;
		this->cb = cb;
		
		uv_idle_init(loop, &handle);
		uv_idle_start(&handle, static_idle);
	}
	
	void idle(uv_idle_t& handle, int status) {
		if (cb(status) == 0) {
			uv_idle_stop(&handle);
			delete this;
		}
	}
	
	static void static_idle(uv_idle_t* handle, int status) {
		((Idler *)(handle->data))->idle(*handle, status); 
	}
};

struct FileWatcher {
	uv_fs_event_t handle;
	filewatcher_callback cb;
	std::string filename;
	
	FileWatcher(uv_loop_t * loop, const char* filename, filewatcher_callback cb) {
		handle.data = this;
		this->cb = cb;
		this->filename = filename;
		uv_fs_event_init(loop, &handle, filename, static_notify, UV_FS_EVENT_RECURSIVE);
		//printf("created fw %p %s on loop %p\n", &handle, filename, loop);
	}
	
	void notify(int events, int status) {
		if (cb(filename.c_str()) != 0) {
			uv_fs_event_init(handle.loop, &handle, filename.c_str(), static_notify, UV_FS_EVENT_RECURSIVE);
		} else {
			// cleanup handle?
			delete this;
		}
	}
	
	static void static_notify(uv_fs_event_t *handle, const char *filename, int events, int status) {
		((FileWatcher *)(handle->data))->notify(events, status);
	}
};

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
	uv_run_once(loop);
	
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
	return L.dofile(filename) == 0;
}

int audio_idle(int status) {
	return 1;
}

int main_idle(int status) {
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
	
	win.create(al::Window::Dim(400, 800), "alive");
	win.startLoop();
	
	return 0;
}