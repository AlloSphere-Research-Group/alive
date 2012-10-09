#ifndef UV_UTILS_H
#define UV_UTILS_H

#include "uv.h"

#include "stdio.h"
#include "stdlib.h"
//#include "syslimits.h"
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
		
		printf("starting %p on %p\n", this, loop);
		
		uv_timer_init(loop, &handle);
		uv_timer_start(&handle, static_notify, 100, 100); // ms
	}
	
	void notify(int status) {
		printf("tick %p\n", handle.loop);
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
				printf("modified %s\n", filename.c_str());
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

