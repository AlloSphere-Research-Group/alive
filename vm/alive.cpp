#include "alive.h"
#include "uv.h"

#include "stdio.h"
#include "stdlib.h"
#include "syslimits.h"
#include "unistd.h"
#include "fcntl.h"

#include "allocore/io/al_AudioIO.hpp"
#include "allocore/math/al_Random.hpp"
#include "alloutil/al_Lua.hpp"

////////////////////////////////////////////////////////////////////////////////


int flag = 0;

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
		
		flag = 1;
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
		flag = 1;
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
		flag = 1;
		if (buffer) { free(buffer); }
	}
	
	void close(uv_fs_t& req) {
		//printf("on close %p %p %d\n", &req, this, (int)req.result);
		uv_fs_req_cleanup(&req);
		delete this;
		flag = 1;
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
		flag = 1;
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
		flag = 1;
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

////////////////////////////////////////////////////////////////////////////////


al::rnd::Random<> rng;


uv_loop_t *loop;
uv_loop_t *audioloop;

al::Lua L;
al::AudioIO audio;

// communication between threads
// pipe is one option
int audiopipe[2];
FILE *outstream;
FILE *instream;

struct audiomsg {
	double t;
	char cmd[4];
	void * obj;
	void * ctx;
	double values[4];
};
	
// another option is a shared buffer
// shared buffer for srsw fifo case is lock free
// very fast, so long as the buffer never gets full
// audio triggers more frequently, so this is reasonable
// tricky part of ring buffer is the wrap boundary
// one option is to copy-on-read, ensuring maximal use of memory and fastest recycle
// another is to skip boundary, avoiding memcpy 
// but wasting memory for large packets and possibly slower recycle
// for over-full buffer spill into heap memory until buffer clears?
/*
	In our case most messages are short:
		timestamp	cmd	ptr
						ptr		ptr
						ptr		paramidx	paramval	offset	count
						size	stringbuffer...
		8			8	8		8			8			8		8
longest is 54 = 300 param messages in a 16384 queue
main thread at 30fps = 9000 updates per frame if audio is fast enough
270000 updates per second seems reasonable!
boundary skip eliminates only 1 of these, inconsequential.
Even an array of pre-defined structs could be viable.
*/ 


void audioCB(al::AudioIOData& io) {

	//putchar(fgetc(instream));
	char buf[10];
	while (read(audiopipe[0], buf, 10) > 0) {
		printf("%s\n", buf);
	}
	
	uv_run_once(audioloop);

	//if (io.time() < 0.1) printf("audio thread %lu\n", uv_thread_self());
	if (flag) {
		float * out = io.outBuffer(0);
		for (int i=0; i<io.framesPerBuffer(); i++) {
			out[i] = rng.uniformS() * 0.03;
		}
	}
	flag = 0;
}

int main(int argc, char * argv[]) {
	
	// execute in the context of wherever this is run from:
	chdir("./");
	
	// do not abort if SIGPIPE is received:
	// i.e. KILL THE ZOMBIES
	signal(SIGPIPE, SIG_IGN);
	
	// setup fifo
	if (pipe (audiopipe)) {
		fprintf (stderr, "Pipe failed.\n");
		return EXIT_FAILURE;
	}
	
	printf("sizeof(audiomsg) %d\n", sizeof(audiomsg));
	
	// output:
	outstream = fdopen (audiopipe[1], "w");
	printf("outstream %p\n", outstream);
	//fprintf(outstream, "hello, world!\n");
	
	// input:
	printf("nonblock %d\n", fcntl(audiopipe[0], F_SETFL, O_NONBLOCK));
	instream = fdopen (audiopipe[0], "r");
	printf("instream %p\n", instream);

	// initialize libuv:
	loop = uv_default_loop();
	audioloop = uv_loop_new();
	
	printf("main thread %lu\n", uv_thread_self());
	
	// set up the Lua state:
	lua_newtable(L);
	for (int i=0; i<argc; i++) {
		lua_pushstring(L, argv[i]);
		lua_rawseti(L, -2, i+1);
	}
	lua_setglobal(L, "argv");
	
	// run startup script:
	if (L.dofile("./alivetest.lua")) return -1;
	
	
	
	audio.callback = audioCB;
	audio.start();
	
	// simulated rendering loop:
	while (1) {
		uv_run_once(loop);
		al_sleep(0.5);
		fflush(stdin);
		fflush(stdout);
		fflush(stderr);
		//printf("some txt %f\n", al_time());
		//fprintf(stderr, "bad txt %f\n", rng.uniform());
		
		
		fprintf(outstream, "tick");
		fflush(outstream);
	}
	
	
	fclose (outstream);
	fclose (instream);
	
	return 0;
}