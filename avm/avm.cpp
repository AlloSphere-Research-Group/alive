
#include "uv_utils.h"
#include "avm_dev.h"

#ifdef AV_WINDOWS
	#include <windows.h>
#else
	#include <sys/time.h>
	#include <time.h>
	#include <libgen.h>
#endif

#include <string.h>

// the path from where it was invoked, e.g. user workspace:
char workpath[PATH_MAX];
// the path where the binary actually resides, e.g. with resources:
char apppath[PATH_MAX];

// the main-thread UV loop:
static uv_loop_t * loop;
// the main-thread Lua state:
static lua_State * L = 0;

void getpaths(int argc, char ** argv) {
	char wd[PATH_MAX];
	if (getcwd(wd, PATH_MAX) == 0) {
		printf("could not derive working path\n");
		exit(0);
	}
	snprintf(workpath, PATH_MAX, "%s/", wd);
	
	printf("workpath %s\n", workpath);
	
	// get binary path:
	char tmppath[PATH_MAX];
	#ifdef AV_OSX
		if (argc > 0) {
			realpath(argv[0], tmppath);
		}
		snprintf(apppath, PATH_MAX, "%s/", dirname(tmppath));
	#elif defined(AV_WINDOWS)
		// Windows only:
		// GetModuleFileName(NULL, apppath, PATH_MAX)
	#else
		// Linux only?
		int count = readlink("/proc/self/exe", tmppath, PATH_MAX);
		if (count > 0) {
			tmppath[count] = '\0';
		} else if (argc > 0) {
			realpath(argv[0], tmppath);
		}
		snprintf(apppath, PATH_MAX, "%s/", dirname(tmppath));
	#endif
	printf("apppath %s\n", apppath);
}

void av_sleep(double seconds) {
	#ifdef AV_WINDOWS
		Sleep((DWORD)(seconds * 1.0e3));
	#else
		time_t sec = (time_t)seconds;
		long long int nsec = 1.0e9 * (seconds - (double)sec);
		timespec tspec = { sec, nsec };
		while (nanosleep(&tspec, &tspec) == -1) {
			continue;
		}
	#endif
}

void av_tick() {
	uv_run_once(loop);
}

int main_idle(int status) {
	//printf("main_idle\n");
	return 1;
}

int main_modified(const char * filename) {
	if (luaL_dofile(L, filename)) {
		printf("error: %s\n", lua_tostring(L, -1));
	}
	return 1;
}

lua_State * av_init_lua() {
	// initialize Lua:
	lua_State * L = lua_open();
	luaL_openlibs(L);
	
	// set up module search paths:
	if (luaL_loadstring(L, "package.path = ... .. 'modules/?.lua;' .. ... .. 'modules/?/init.lua;' .. package.path")) printf("error %s\n", lua_tostring(L, -1));
	lua_pushstring(L, apppath);
	if (lua_pcall(L, 1, 0, 0)) printf("error %s\n", lua_tostring(L, -1));

	if (luaL_loadstring(L, "package.cpath = ... .. 'modules/?.so;' .. package.cpath")) printf("error %s\n", lua_tostring(L, -1));
	lua_pushstring(L, apppath);
	if (lua_pcall(L, 1, 0, 0)) printf("error %s\n", lua_tostring(L, -1));
	
	printf("initialized Lua\n");
	
	return L;
}

int main(int argc, char * argv[]) {
	
	// initialize paths:
	getpaths(argc, argv);
	
	// execute in the context of wherever this is run from:
	chdir("./");
	
	// initialize window:
	printf("creating window\n");
	//av_Window * win = 
	av_window_create();
	printf("created window\n");
	
	// initialize UV:
	loop = uv_default_loop();
	
	// initialize Lua:
	L = av_init_lua();
	
	// add an idler to prevent uv loop blocking:
	new Idler(loop, main_idle);
	printf("created idler\n");
	
	// initialize audio:
	//av_Audio * audio = 
	//av_audio_get();
	
	// start watching:
	const char * main_filename = "main.lua";
	new FileWatcher(loop, main_filename, main_modified);
	
	printf("starting\n");
	glutMainLoop();
	return 0;
}
