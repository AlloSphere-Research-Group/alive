#include "avm_dev.h"
#include "uv_utils.h"

#include <string.h>
#include <libgen.h>

// the path from where it was invoked, e.g. user workspace:
char workpath[PATH_MAX];
// the path where the binary actually resides, e.g. with resources:
char apppath[PATH_MAX];

// the main-thread UV loop:
uv_loop_t * mainloop;
// the main-thread Lua state:
lua_State * L = 0;

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
	#ifdef __APPLE__
		if (argc > 0) {
			realpath(argv[0], tmppath);
		}
		snprintf(apppath, PATH_MAX, "%s/", dirname(tmppath));
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
	// Windows only:
	// GetModuleFileName(NULL, apppath, PATH_MAX)
	printf("apppath %s\n", apppath);
}

void av_tick() {
	uv_run_once(mainloop);
}

void av_sleep(double seconds) {
	// there may be better options than this, but it will do for now: 
	Pa_Sleep(seconds * 1000);
}

int main_idle(int status) {
	//printf("main_idle\n");
	return 1;
}

int main_modified(const char * filename) {
	printf("main modified %s\n", filename);
	
	if (luaL_dofile(L, filename)) {
		printf("error: %s\n", lua_tostring(L, -1));
	}
	
	return 1;
}

lua_State * initLua(const char * apppath) {
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
	
	return L;
}

int main(int argc, char * argv[]) {
	glutInit(&argc, argv);
	
	// initialize paths:
	getpaths(argc, argv);
	
	// execute in the context of wherever this is run from:
	chdir("./");
	
	// initialize UV:
	mainloop = uv_default_loop();
	
	// initialize Lua:
	L = initLua(apppath);
	
	// add an idler to prevent uv loop blocking:
	new Idler(mainloop, main_idle);
	
	// initialize window:
	av_Window * win = av_window_create();
	
	// initialize audio:
	av_Audio * audio = av_audio_get();
	
	// start watching:
	const char * main_filename = "main.lua";
	new FileWatcher(mainloop, main_filename, main_modified);
	
	glutMainLoop();
	return 0;
}
