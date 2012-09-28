#include "alive.h"
#include "uv.h"

#include "stdio.h"
#include "stdlib.h"

extern "C" {
	void al_sleep(double);
}

uv_loop_t *loop;
uv_fs_t open_req, read_req;
char buffer[16384];

int64_t counter = 0;
void wait_for_a_while(uv_idle_t* handle, int status) {
    counter++;

    if (counter >= 1000) {
		printf("counter %d\n", (int)counter);
        uv_idle_stop(handle);
	}
}

uv_buf_t alloc_buffer(uv_handle_t *handle, size_t suggested_size) {
    return uv_buf_init((char*) malloc(suggested_size), suggested_size);
}


void on_read(uv_fs_t *req) {
    printf("on_read %p %d\n", req, (int)req->result);
	if (req->result < 0) {
        fprintf(stderr, "Read error: %s\n", uv_strerror(uv_last_error(loop)));
    } else if (req->result == 0) {
        uv_fs_t close_req;
        // synchronous
        uv_fs_close(loop, &close_req, open_req.result, NULL);
    } else {
		printf("read %d bytes\n", (int)req->result);
		printf("%s\n", buffer);
	}

	uv_fs_req_cleanup(req);
	delete req;
}

void on_open(uv_fs_t *req) {
	printf("on_open %p %d\n", req, (int)req->result);
	// need to know file size to allocate a buffer for it...
	
	if (req->result != -1) {
        uv_fs_read(loop, new uv_fs_t, req->result, buffer, sizeof(buffer), -1, on_read);
    } else {
        fprintf(stderr, "error opening file: %d\n", req->errorno);
    }
	
    uv_fs_req_cleanup(req);
	delete req;
}

uv_pipe_t stdin_pipe;
void read_stdin(uv_stream_t *stream, ssize_t nread, uv_buf_t buf) {
    if (nread == -1) {
        if (uv_last_error(loop).code == UV_EOF) {
            uv_close((uv_handle_t*)&stdin_pipe, NULL);
            //uv_close((uv_handle_t*)&stdout_pipe, NULL);
            //uv_close((uv_handle_t*)&file_pipe, NULL);
        }
    } else {
        if (nread > 0) {
			printf("read %d %s\n", (int)nread, (char *)buf.base);
            //write_data((uv_stream_t*)&stdout_pipe, nread, buf, on_stdout_write);
            //write_data((uv_stream_t*)&file_pipe, nread, buf, on_file_write);
			
			// open this file:
			printf("open request %p\n", &open_req);
			uv_fs_open(loop, new uv_fs_t, (char *)buf.base, O_RDONLY, 0, on_open);
        }
    }
    if (buf.base) {
        free(buf.base);
	}
}

int main(int argc, char * argv[]) {
	
	// do not abort if SIGPIPE is received:
	signal(SIGPIPE, SIG_IGN);

	// initialize
	loop = uv_default_loop();
	
	uv_idle_t idler;
    uv_idle_init(loop, &idler);
    uv_idle_start(&idler, wait_for_a_while);
	
	// callback for stdin input:
	uv_pipe_init(loop, &stdin_pipe, 0);
    uv_pipe_open(&stdin_pipe, 0); // fd 0
	uv_read_start((uv_stream_t*)&stdin_pipe, alloc_buffer, read_stdin);
	
	uv_fs_open(loop, new uv_fs_t, "test.lua", O_RDONLY, 0, on_open);
	
	// simulated rendering loop:
	while (1) {
		printf("run %d\n", uv_run_once(loop)); 
		printf("run %d\n", uv_run_once(loop)); 
		printf("run %d\n", uv_run_once(loop)); 
		al_sleep(1);
		fflush(stdin);
		fflush(stdout);
		fflush(stderr);
	}
	return 0;
}