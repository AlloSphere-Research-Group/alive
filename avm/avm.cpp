#include "avm.h"
#include "uv.h"

#include <unistd.h>
#include <stdlib.h>

uv_loop_t * mainloop;
char exepath[PATH_MAX];
size_t exepath_size = PATH_MAX;
char thecwd[PATH_MAX];

// for child proc:
uv_process_options_t options;
char* args[3];

uv_pipe_t stdin_pipe, stdout_pipe;
uv_pipe_t in, out;

void initialization() {
	mainloop = uv_default_loop();
	
	int r = uv_exepath(exepath, &exepath_size);
	if (r) {
		printf("error deriving exepath: %d\n", r);
		exit(0);
	}
	exepath[exepath_size] = '\0';
	
	uv_err_t err = uv_cwd(thecwd, PATH_MAX);
	if (err.code) {
		printf("error deriving thecwd: %d\n", err.code);
		exit(0);
	}
	
	printf("running: %s\n", exepath);
	printf("in: %s\n", thecwd);
}

// this means reader needs to call free()
uv_buf_t on_alloc(uv_handle_t* handle, size_t suggested_size) {
	return uv_buf_init((char*) malloc(suggested_size), suggested_size);
}

void on_close(uv_handle_t* handle) {
	printf("closed handle\n");
}

void on_read(uv_stream_t* stream, ssize_t nread, uv_buf_t buf) {
	uv_err_t err = uv_last_error(stream->loop);
	if (nread > 0) {
		printf("received: %s\n", (char *)buf.base);
	} else if (nread < 0) {
		if(err.code == UV_EOF) {
			uv_close((uv_handle_t*)stream, on_close);
		}
	}
}

void on_read_stdin(uv_stream_t* stream, ssize_t nread, uv_buf_t buf) {
	uv_err_t err = uv_last_error(stream->loop);
	if (nread > 0) {
		printf("received: %s\n", (char *)buf.base);
	} else if (nread < 0) {
		if(err.code == UV_EOF) {
			uv_close((uv_handle_t*)stream, on_close);
		}
	}
}

void write_cb(uv_write_t* req, int status) {
	//ASSERT(status == 0);
	uv_close((uv_handle_t*)req->handle, on_close);
}

void on_close_child(uv_handle_t* handle) {
	printf("closed child\n");
}

void on_exit_child(uv_process_t* process, int exit_status, int term_signal) {
	printf("exit child %d %d\n", exit_status, term_signal);
	
	uv_close((uv_handle_t*)process, on_close_child);
	//uv_close((uv_handle_t*)&in, close_cb);	
	//uv_close((uv_handle_t*)&out, close_cb);
}

int main(int argc, char * argv[]) {
	int r;
	uv_process_t child;
	
	initialization();
	
	r = uv_pipe_init(mainloop, &stdin_pipe, 0);
	if (r) printf("failed to create pipe\n");
	r = uv_pipe_open(&stdin_pipe, 0);
	if (r) printf("failed to open pipe\n");
	
	r = uv_pipe_init(mainloop, &in, 0);
	if (r) printf("failed to create pipe\n");
	r = uv_pipe_init(mainloop, &out, 0);
	if (r) printf("failed to create pipe\n");
	
	char * args[] = { "luajit", NULL };
	options.file = "luajit";
	options.args = args;
	options.exit_cb = on_exit_child;
	options.flags = 0;
	
	uv_stdio_container_t stdio[2];
	stdio[0].flags = (uv_stdio_flags)(UV_CREATE_PIPE | UV_READABLE_PIPE);
	stdio[0].data.stream = (uv_stream_t*)&in;
	stdio[1].flags = (uv_stdio_flags)(UV_CREATE_PIPE | UV_WRITABLE_PIPE);
	stdio[1].data.stream = (uv_stream_t*)&out;
	options.stdio_count = 2;
	options.stdio = stdio;
	
	uv_spawn(mainloop, &child, options);
	
	uv_write_t write_req;
	char msg[] = "print(1234)";
	uv_buf_t buf;
	buf.base = msg;
	buf.len = strlen(msg);
	r = uv_write(&write_req, (uv_stream_t*)&in, &buf, 1, write_cb);
	
	r = uv_read_start((uv_stream_t*)&out, on_alloc, on_read);
	if (r) printf("failed to start reading pipe\n");
	
	r = uv_read_start((uv_stream_t*)&stdin_pipe, on_alloc, on_read_stdin);
	if (r) printf("failed to start reading pipe\n");
	
	
	// it would be nice to learn how to use fork() and communicate with a child
	// process here, streaming back & forth in such a way that the child can
	// crash without taking down the master
	// not sure if fork() actually achieves this. AFAICT fork is still in the 
	// same shared memory space (can see same ptrs), is it really a separate 
	// process?
	
	// it can be done through node.js spawn(), 
	// and presumably through uv_spawn(), though I haven't figured out exactly
	// how yet
	
	// how far can this go...? can it work as a library?
	
	// what Windows equivalents are possible?
	
	// the master could start by simply serving a webpage, and maybe even 
	// opening it by default, presenting a REPL to the Lua state in the child
	
	uv_run(mainloop);
		
	return 0;
}