local uv_h = [[

void	*malloc(size_t);

typedef long ssize_t;
typedef long __darwin_time_t;

typedef struct ngx_queue_s ngx_queue_t;
struct ngx_queue_s {
    ngx_queue_t *prev;
    ngx_queue_t *next;
};

struct timespec
{
 __darwin_time_t tv_sec;
 long tv_nsec;
};

struct stat { 
	int32_t st_dev; 
	uint16_t st_mode; 
	uint16_t st_nlink; 
	uint64_t st_ino; 
	uint32_t st_uid; 
	uint32_t st_gid; 
	int32_t st_rdev; 
	struct timespec st_atimespec; struct timespec st_mtimespec; struct timespec st_ctimespec; struct timespec st_birthtimespec; 
	int64_t st_size; int64_t st_blocks; int32_t st_blksize; 
	uint32_t st_flags; uint32_t st_gen; int32_t st_lspare; int64_t st_qspare[2]; 
};

typedef enum {
  UV_UNKNOWN_HANDLE = 0,

  UV_ASYNC, UV_CHECK, UV_FS_EVENT, UV_FS_POLL, UV_HANDLE, UV_IDLE, UV_NAMED_PIPE, UV_POLL, UV_PREPARE, UV_PROCESS, UV_STREAM, UV_TCP, UV_TIMER, UV_TTY, UV_UDP, UV_SIGNAL,

  UV_FILE,
  UV_HANDLE_TYPE_MAX
} uv_handle_type;

typedef enum {
  UV_UNKNOWN_REQ = 0,

  UV_REQ, UV_CONNECT, UV_WRITE, UV_SHUTDOWN, UV_UDP_SEND, UV_FS, UV_WORK, UV_GETADDRINFO,

 
  UV_REQ_TYPE_MAX
} uv_req_type;

typedef enum {
  UV_UNKNOWN = -1, UV_OK = 0, UV_EOF = 1, UV_EADDRINFO = 2, UV_EACCES = 3, UV_EAGAIN = 4, UV_EADDRINUSE = 5, UV_EADDRNOTAVAIL = 6, UV_EAFNOSUPPORT = 7, UV_EALREADY = 8, UV_EBADF = 9, UV_EBUSY = 10, UV_ECONNABORTED = 11, UV_ECONNREFUSED = 12, UV_ECONNRESET = 13, UV_EDESTADDRREQ = 14, UV_EFAULT = 15, UV_EHOSTUNREACH = 16, UV_EINTR = 17, UV_EINVAL = 18, UV_EISCONN = 19, UV_EMFILE = 20, UV_EMSGSIZE = 21, UV_ENETDOWN = 22, UV_ENETUNREACH = 23, UV_ENFILE = 24, UV_ENOBUFS = 25, UV_ENOMEM = 26, UV_ENOTDIR = 27, UV_EISDIR = 28, UV_ENONET = 29, UV_ENOTCONN = 31, UV_ENOTSOCK = 32, UV_ENOTSUP = 33, UV_ENOENT = 34, UV_ENOSYS = 35, UV_EPIPE = 36, UV_EPROTO = 37, UV_EPROTONOSUPPORT = 38, UV_EPROTOTYPE = 39, UV_ETIMEDOUT = 40, UV_ECHARSET = 41, UV_EAIFAMNOSUPPORT = 42, UV_EAISERVICE = 44, UV_EAISOCKTYPE = 45, UV_ESHUTDOWN = 46, UV_EEXIST = 47, UV_ESRCH = 48, UV_ENAMETOOLONG = 49, UV_EPERM = 50, UV_ELOOP = 51, UV_EXDEV = 52, UV_ENOTEMPTY = 53, UV_ENOSPC = 54, UV_EIO = 55, UV_EROFS = 56, UV_ENODEV = 57, UV_ESPIPE = 58, UV_ECANCELED = 59,
  UV_MAX_ERRORS
} uv_err_code;

typedef enum {
  UV_FS_UNKNOWN = -1,
  UV_FS_CUSTOM,
  UV_FS_OPEN,
  UV_FS_CLOSE,
  UV_FS_READ,
  UV_FS_WRITE,
  UV_FS_SENDFILE,
  UV_FS_STAT,
  UV_FS_LSTAT,
  UV_FS_FSTAT,
  UV_FS_FTRUNCATE,
  UV_FS_UTIME,
  UV_FS_FUTIME,
  UV_FS_CHMOD,
  UV_FS_FCHMOD,
  UV_FS_FSYNC,
  UV_FS_FDATASYNC,
  UV_FS_UNLINK,
  UV_FS_RMDIR,
  UV_FS_MKDIR,
  UV_FS_RENAME,
  UV_FS_READDIR,
  UV_FS_LINK,
  UV_FS_SYMLINK,
  UV_FS_READLINK,
  UV_FS_CHOWN,
  UV_FS_FCHOWN
} uv_fs_type;

typedef struct uv_loop_s uv_loop_t;
typedef struct uv_err_s uv_err_t;
typedef struct uv_handle_s uv_handle_t;
typedef struct uv_stream_s uv_stream_t;
typedef struct uv_tcp_s uv_tcp_t;
typedef struct uv_udp_s uv_udp_t;
typedef struct uv_pipe_s uv_pipe_t;
typedef struct uv_tty_s uv_tty_t;
typedef struct uv_poll_s uv_poll_t;
typedef struct uv_timer_s uv_timer_t;
typedef struct uv_prepare_s uv_prepare_t;
typedef struct uv_check_s uv_check_t;
typedef struct uv_idle_s uv_idle_t;
typedef struct uv_async_s uv_async_t;
typedef struct uv_process_s uv_process_t;
typedef struct uv_fs_event_s uv_fs_event_t;
typedef struct uv_fs_poll_s uv_fs_poll_t;
typedef struct uv_signal_s uv_signal_t;


typedef struct uv_req_s uv_req_t;
typedef struct uv_getaddrinfo_s uv_getaddrinfo_t;
typedef struct uv_shutdown_s uv_shutdown_t;
typedef struct uv_write_s uv_write_t;
typedef struct uv_connect_s uv_connect_t;
typedef struct uv_udp_send_s uv_udp_send_t;
typedef struct uv_fs_s uv_fs_t;
typedef struct uv_work_s uv_work_t;


typedef struct uv_counters_s uv_counters_t;
typedef struct uv_cpu_info_s uv_cpu_info_t;
typedef struct uv_interface_address_s uv_interface_address_t;

typedef int uv_file;
typedef int uv_os_sock_t;
typedef struct stat uv_statbuf_t;

typedef struct eio_req eio_req;
typedef struct eio_dirent eio_dirent;

typedef struct {
	char* base;
	size_t len;
} uv_buf_t;

typedef uv_buf_t (*uv_alloc_cb)(uv_handle_t* handle, size_t suggested_size);
typedef void (*uv_read_cb)(uv_stream_t* stream, ssize_t nread, uv_buf_t buf);
typedef void (*uv_read2_cb)(uv_pipe_t* pipe, ssize_t nread, uv_buf_t buf,
    uv_handle_type pending);
typedef void (*uv_write_cb)(uv_write_t* req, int status);
typedef void (*uv_connect_cb)(uv_connect_t* req, int status);
typedef void (*uv_shutdown_cb)(uv_shutdown_t* req, int status);
typedef void (*uv_connection_cb)(uv_stream_t* server, int status);
typedef void (*uv_close_cb)(uv_handle_t* handle);
typedef void (*uv_poll_cb)(uv_poll_t* handle, int status, int events);
typedef void (*uv_timer_cb)(uv_timer_t* handle, int status);
typedef void (*uv_async_cb)(uv_async_t* handle, int status);
typedef void (*uv_prepare_cb)(uv_prepare_t* handle, int status);
typedef void (*uv_check_cb)(uv_check_t* handle, int status);
typedef void (*uv_idle_cb)(uv_idle_t* handle, int status);
typedef void (*uv_exit_cb)(uv_process_t*, int exit_status, int term_signal);
typedef void (*uv_walk_cb)(uv_handle_t* handle, void* arg);
typedef void (*uv_fs_cb)(uv_fs_t* req);
typedef void (*uv_work_cb)(uv_work_t* req);
typedef void (*uv_after_work_cb)(uv_work_t* req);
typedef void (*uv_getaddrinfo_cb)(uv_getaddrinfo_t* req,
                                  int status,
                                  struct addrinfo* res);
typedef void (*uv_fs_event_cb)(uv_fs_event_t* handle, const char* filename,
    int events, int status);
typedef void (*uv_signal_cb)(uv_signal_t* handle, int signum);

typedef enum {
  UV_LEAVE_GROUP = 0,
  UV_JOIN_GROUP
} uv_membership;

struct uv_err_s {
  uv_err_code code;
  int sys_errno_;
};

struct uv_req_s {
	void* data; ngx_queue_t active_queue; uv_req_type type;
};

struct uv_idle_s {
	uv_close_cb close_cb; 
	void* data; 
	uv_loop_t* loop; 
	uv_handle_type type; 
	ngx_queue_t handle_queue; 
	int flags; 
	uv_handle_t* next_closing;
	uv_idle_cb idle_cb; 
	ngx_queue_t queue;
};

struct uv_fs_s {
	void* data; ngx_queue_t active_queue; uv_req_type type;
	uv_fs_type fs_type;
	uv_loop_t* loop;
	uv_fs_cb cb;
	ssize_t result;
	void* ptr;
	const char* path;
	uv_err_code errorno;
	uv_statbuf_t statbuf; 
	//uv_file file; eio_req* eio;
};

uv_loop_t* uv_loop_new(void);
void uv_loop_delete(uv_loop_t*);
uv_loop_t* uv_default_loop(void);

int uv_run(uv_loop_t*);
int uv_run_once(uv_loop_t*);

void uv_ref(uv_handle_t*);
void uv_unref(uv_handle_t*);

void uv_update_time(uv_loop_t*);
int64_t uv_now(uv_loop_t*);

uv_err_t uv_last_error(uv_loop_t*);
const char* uv_strerror(uv_err_t err);
const char* uv_err_name(uv_err_t err);

int uv_idle_init(uv_loop_t*, uv_idle_t* idle);
int uv_idle_start(uv_idle_t* idle, uv_idle_cb cb);
int uv_idle_stop(uv_idle_t* idle);

void uv_fs_req_cleanup(uv_fs_t* req);

int uv_fs_close(uv_loop_t* loop, uv_fs_t* req, uv_file file,
    uv_fs_cb cb);
int uv_fs_open(uv_loop_t* loop, uv_fs_t* req, const char* path,
    int flags, int mode, uv_fs_cb cb);
int uv_fs_read(uv_loop_t* loop, uv_fs_t* req, uv_file file,
    void* buf, size_t length, int64_t offset, uv_fs_cb cb);
int uv_fs_unlink(uv_loop_t* loop, uv_fs_t* req, const char* path,
    uv_fs_cb cb);
int uv_fs_write(uv_loop_t* loop, uv_fs_t* req, uv_file file,
    void* buf, size_t length, int64_t offset, uv_fs_cb cb);
int uv_fs_mkdir(uv_loop_t* loop, uv_fs_t* req, const char* path,
    int mode, uv_fs_cb cb);
int uv_fs_rmdir(uv_loop_t* loop, uv_fs_t* req, const char* path,
    uv_fs_cb cb);
int uv_fs_readdir(uv_loop_t* loop, uv_fs_t* req,
    const char* path, int flags, uv_fs_cb cb);
int uv_fs_stat(uv_loop_t* loop, uv_fs_t* req, const char* path,
    uv_fs_cb cb);
int uv_fs_fstat(uv_loop_t* loop, uv_fs_t* req, uv_file file,
    uv_fs_cb cb);
int uv_fs_rename(uv_loop_t* loop, uv_fs_t* req, const char* path,
    const char* new_path, uv_fs_cb cb);
int uv_fs_fsync(uv_loop_t* loop, uv_fs_t* req, uv_file file,
    uv_fs_cb cb);
int uv_fs_fdatasync(uv_loop_t* loop, uv_fs_t* req, uv_file file,
    uv_fs_cb cb);
int uv_fs_ftruncate(uv_loop_t* loop, uv_fs_t* req, uv_file file,
    int64_t offset, uv_fs_cb cb);
int uv_fs_sendfile(uv_loop_t* loop, uv_fs_t* req, uv_file out_fd,
    uv_file in_fd, int64_t in_offset, size_t length, uv_fs_cb cb);
int uv_fs_chmod(uv_loop_t* loop, uv_fs_t* req, const char* path,
    int mode, uv_fs_cb cb);
int uv_fs_utime(uv_loop_t* loop, uv_fs_t* req, const char* path,
    double atime, double mtime, uv_fs_cb cb);
int uv_fs_futime(uv_loop_t* loop, uv_fs_t* req, uv_file file,
    double atime, double mtime, uv_fs_cb cb);
int uv_fs_lstat(uv_loop_t* loop, uv_fs_t* req, const char* path,
    uv_fs_cb cb);
int uv_fs_link(uv_loop_t* loop, uv_fs_t* req, const char* path,
    const char* new_path, uv_fs_cb cb);
int uv_fs_symlink(uv_loop_t* loop, uv_fs_t* req, const char* path,
    const char* new_path, int flags, uv_fs_cb cb);
int uv_fs_readlink(uv_loop_t* loop, uv_fs_t* req, const char* path,
    uv_fs_cb cb);
int uv_fs_fchmod(uv_loop_t* loop, uv_fs_t* req, uv_file file,
    int mode, uv_fs_cb cb);
int uv_fs_chown(uv_loop_t* loop, uv_fs_t* req, const char* path,
    int uid, int gid, uv_fs_cb cb);
int uv_fs_fchown(uv_loop_t* loop, uv_fs_t* req, uv_file file,
    int uid, int gid, uv_fs_cb cb);

]]


local ffi = require "ffi"
local C = ffi.C

ffi.cdef(uv_h)
local uv = {
	O_RDONLY	= 0x0000, -- open for reading only */
	O_WRONLY	= 0x0001, -- open for writing only */
	O_RDWR		= 0x0002, -- open for reading and writing */
	O_ACCMODE	= 0x0003, -- mask for above modes */
}
setmetatable(uv, {
	__index = function(self, k) 
		local name = "uv_" .. k
		uv[k] = C[name]
		return uv[k]
	end,
}) 
--------------------------------------------------------------------------------
local loop = uv.default_loop()
print(loop)

local idler = ffi.new("uv_idle_t")	-- gc?
uv.idle_init(loop, idler)
uv.idle_start(idler, function(handle, status)
	-- just something to keep the loop going
	--print("idling", handle, status)
end)

--------------------------------------------------------------------------------

function openfile(path, callback)
	local opener = ffi.new("uv_fs_t")
	uv.fs_open(loop, opener, path, uv.O_RDONLY, 0, function(req)
		if req.result ~= -1 then
			local reader = ffi.new("uv_fs_t")
			local size = 16384
			local buffer = C.malloc(size)
			uv.fs_read(loop, reader, req.result, buffer, size, -1, function(req)
				if req.result < 0 then
					print("Read error:", uv.strerror(uv.last_error(loop)))
				elseif req.result == 0 then
					-- synchronous:
					uv.fs_close(loop, ffi.new("uv_fs_t"), opener.result, 0)
				else
					callback(buffer, req.result)
				end

				uv.fs_req_cleanup(req)

			end)
		end
		local err = req.errorno
		uv.fs_req_cleanup(opener)
		print("error opening file:", err)
	end)
end

openfile("test.lua", function(buffer, size) 
	print("read bytes", size)
	print(ffi.string(buffer, size))
end)



--------------------------------------------------------------------------------
print("--- running ---")
print( uv.run(loop) )
