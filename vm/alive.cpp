#include "alive.h"
#include "uv.h"

#include "stdio.h"
#include "stdlib.h"
#include "syslimits.h"
#include "unistd.h"
#include "fcntl.h"

#include "allocore/io/al_AudioIO.hpp"
#include "allocore/io/al_Window.hpp"
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
	
	}
	
	void read(uv_stream_t& stream, ssize_t nread, uv_buf_t& buf) {
		if (nread == -1) {
			if (uv_last_error(stream.loop).code == UV_EOF) {
				uv_close((uv_handle_t*)&pipe, NULL);
			}
		} else {
			if (nread > 0) {
				cb(buf.base, nread - 1);
			}
		}
		// recycle:
		if (buf.base) { free(buf.base); }
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
		if (cb(status) != 0) {
			uv_idle_stop(&handle);
		}
	}
	
	static void static_idle(uv_idle_t* handle, int status) {
		((Idler *)(handle->data))->idle(*handle, status); 
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
	T * next() {
		read = (read + 1) & wrap;
		return peek();
	}
	
	double used() const {
		printf("%d %d\n", read, write);
		return ((size + write - read) & wrap)/double(size);
	}
};


////////////////////////////////////////////////////////////////////////////////

rnd::Random<> rng;
uv_loop_t *loop;
Lua L, LA;
AudioIO audio;
Q<audiomsg> audioq;
double audiotime = 0;
double maintime = 0;
double audiolag = 2000; // in samples
uv_loop_t *audioloop;
audio_callback audiocb = 0;
Window win;

void tick() {
	uv_run_once(loop);
	
	fflush(stdin);
	fflush(stdout);
	fflush(stderr);
	
	// process scheduled events up to t:
	double t = audiotime + audiolag;
	
	// e.g. send a message:
	//for (int i=0; i<100; i++) {
	if (rng.uniform() < 0.1) {
		audiomsg * m = audioq.head();
		if (m) {
			m->t = t;
			audioq.send();
		}
	}
	
	maintime = t;
	
//	printf("used %04.1f%%\n", 100.*audioq.used() );
}

class App : public WindowEventHandler, public InputEventHandler {
public:

	App() {
		win.append(*(WindowEventHandler *)this);
		win.append(*(InputEventHandler *)this);
	}

	virtual ~App() {
		
	}
	
	virtual bool onKeyDown(const Keyboard& k){return true;}	///< Called when a keyboard key is pressed
	virtual bool onKeyUp(const Keyboard& k){return true;}	///< Called when a keyboard key is released

	virtual bool onMouseDown(const Mouse& m){return true;}	///< Called when a mouse button is pressed
	virtual bool onMouseDrag(const Mouse& m){return true;}	///< Called when the mouse moves while a button is down
	virtual bool onMouseMove(const Mouse& m){return true;}	///< Called when the mouse moves
	virtual bool onMouseUp(const Mouse& m){return true;}	///< Called when a mouse button is released
	virtual bool onCreate(){ return true; }					///< Called after window is created with valid OpenGL context
	virtual bool onDestroy(){ return true; }				///< Called before the window and its OpenGL context are destroyed
	
	
	virtual bool onResize(int dw, int dh){ return true; }	///< Called whenever window dimensions change
	virtual bool onVisibility(bool v){ return true; }		///< Called when window changes from hidden to shown and vice versa
	
	virtual bool onFrame(){ 
		Graphics gl;
		gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
		
		tick();

		//printf(".");
		return true; 
	}
	
};

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

audiomsg * audioq_peek(void) {
	return audioq.peek();
}
audiomsg * audioq_next(void) {
	return audioq.next();
}


void audioCB(al::AudioIOData& io) {

	if (audiotime == 0) {
		printf("audio started %d %f\n", io.framesPerBuffer(), io.framesPerSecond());
	}

	double nexttime = audiotime + io.framesPerBuffer();
	
	// libuv in audio thread?
	//uv_run_once(audioloop);
	
	if (audiocb) audiocb(audiotime);
	
	audiotime = nexttime;

	//if (io.time() < 0.1) printf("audio thread %lu\n", uv_thread_self());
}

int main(int argc, char * argv[]) {
	
	// execute in the context of wherever this is run from:
	chdir("./");
	
	// do not abort if SIGPIPE is received:
	// i.e. KILL THE ZOMBIES
	signal(SIGPIPE, SIG_IGN);

	// initialize libuv:
	loop = uv_default_loop();
	//audioloop = uv_loop_new();
	
	// configure audio:
	audio.framesPerBuffer(256);
	audio.callback = audioCB;

	// set up the Lua state:
	lua_newtable(L);
	for (int i=0; i<argc; i++) {
		lua_pushstring(L, argv[i]);
		lua_rawseti(L, -2, i+1);
	}
	lua_setglobal(L, "argv");
	
	// run startup script:
	if (L.dofile("./alivetest.lua")) return -1;
	
	// run startup script:
	if (LA.dofile("./alivetestaudio.lua")) return -1;
	
	// start threads:
	audio.start();
	
	App app;
	win.create(al::Window::Dim(300, 200), "alive");
	win.startLoop();
	
	return 0;
}