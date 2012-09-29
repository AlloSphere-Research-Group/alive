

extern "C" {
	typedef int (*idle_callback)(int status);
	typedef void (*buffer_callback)(char * buffer, int size);
	
	void idle(idle_callback cb);
	
	void openfile(const char * path, buffer_callback cb);
	void openfd(int fd, buffer_callback cb);
	
	double al_time();
	void al_sleep(double);
}

