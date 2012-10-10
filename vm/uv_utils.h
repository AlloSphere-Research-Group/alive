#ifndef UV_UTILS_H
#define UV_UTILS_H

#include "uv.h"

#include "stdio.h"
#include "stdlib.h"
#include "string.h"
#include "unistd.h"
#include "fcntl.h"

#ifdef __cplusplus
#include <string>
extern "C" {
#endif

typedef int (*idle_callback)(int status);
typedef int (*buffer_callback)(char * buffer, int size);
typedef int (*filewatcher_callback)(const char * filename);

#ifdef __cplusplus
}
#endif

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
	
	static void static_read(uv_fs_t *req) { 		
		printf("file read static notify\n");
		((FileOpen *)(req->data))->read(*req); 
	}
	static void static_open(uv_fs_t *req) { 	
		printf("file open static notify\n");
		((FileOpen *)(req->data))->open(*req); 
	}
	static void static_stat(uv_fs_t *req) { 	
		printf("file stat static notify\n");
		((FileOpen *)(req->data))->stat(*req); 
	}
	static void static_close(uv_fs_t *req) { 	
		printf("file close static notify\n");
		((FileOpen *)(req->data))->close(*req);
	}
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
		printf("read static notify\n");
		((FdOpen *)(stream->data))->read(*stream, nread, buf); 
	}
	
	static uv_buf_t alloc_buffer(uv_handle_t *handle, size_t suggested_size) {
		printf("read buf static notify\n");
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
		//printf("idle static notify\n");
		((Idler *)(handle->data))->idle(*handle, status); 
	}
};

// uv_fs_event appears to be somewhat flaky
// resorting to manual stats for now
struct FileWatcher {
	uv_timer_t handle;
	uv_fs_t stat_req;
	time_t modified;
	filewatcher_callback cb;
	std::string filename;
	
	FileWatcher(uv_loop_t * loop, const char* filename, filewatcher_callback cb) {
		handle.data = this;
		stat_req.data = this;
		this->cb = cb;
		this->filename = filename;
		modified = 0;
		
		//printf("starting %p on %p\n", this, loop);
		
		uv_timer_init(loop, &handle);
		uv_timer_start(&handle, static_notify, 100, 100); // ms
	}
	
	void notify(int status) {
		//printf("tick %p\n", handle.loop);
		uv_fs_stat(handle.loop, &stat_req, filename.c_str(), static_stat);
	}
	
	void stat(uv_fs_t& req) {
		//printf("on_stat %p %p %d\n", &req, req.ptr, (int)req.result);
		if (req.result < 0) {
			fprintf(stderr, "error on stat file: %d\n", req.errorno);
		} else {
			struct stat *s = (struct stat *)req.ptr;
			time_t mt = s->st_mtime;
			if (mt > modified) {
				//printf("modified %s\n", filename.c_str());
				modified = mt;
				if (cb(filename.c_str()) == 0) {
					uv_timer_stop(&handle);
					uv_fs_req_cleanup(&req);
					delete this;
				}
			}
		}
	}
	
	static void static_notify(uv_timer_t * handle, int status) {
		((FileWatcher *)(handle->data))->notify(status);
	}
	static void static_stat(uv_fs_t *req) { 	
		((FileWatcher *)(req->data))->stat(*req); 
	}
};
/*
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
			printf("rescheduled filewatcher %s\n", filename.c_str());
			
			//new FileWatcher(handle.loop, filename.c_str(), this->cb);
		} else {
			// cleanup handle?
			//delete this;
		}
	}
	
	static void static_notify(uv_fs_event_t *handle, const char *filename, int events, int status) {
		printf("fw static notify\n");
		((FileWatcher *)(handle->data))->notify(events, status);
	}
};
*/

#endif

