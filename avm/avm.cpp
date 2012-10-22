
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

// the path from where it was invoked:
char launchpath[PATH_MAX];
// the path where the binary actually resides, e.g. with modules:
char apppath[PATH_MAX];
// the path of the start file, e.g. user script / workspace:
char workpath[PATH_MAX];
// filename of the main script:
char mainfile[PATH_MAX];

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
	snprintf(launchpath, PATH_MAX, "%s/", wd);
	
	printf("launchpath %s\n", launchpath);
	
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
	
	char apath[PATH_MAX];
	if (argc > 1) {
		realpath(argv[1], apath);
		
		snprintf(workpath, PATH_MAX, "%s/", dirname(apath));
		snprintf(mainfile, PATH_MAX, "%s", basename(apath));
	} else {
		// just copy the current path:
		snprintf(workpath, PATH_MAX, "%s", launchpath);
		snprintf(mainfile, PATH_MAX, "%s", "main.lua");
	}
	
	printf("workpath %s\n", workpath);
	printf("mainfile %s\n", mainfile);
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
	if (luaL_loadfile(L, filename)) {
		printf("error loading %s: %s\n", filename, lua_tostring(L, -1));
	} else {
		// get debug.traceback
		lua_getfield(L, LUA_REGISTRYINDEX, "debug.traceback");
		lua_insert(L, 1);
		
		if (lua_pcall(L, 0, LUA_MULTRET, 1)) {
			printf("error running %s: %s\n", filename, lua_tostring(L, -1));
		}
		
		// remove debug.traceback
		lua_remove(L, 1); 
	}
	return 0;
}

lua_State * av_dump_lua(lua_State * L, const char * msg) {
	printf("Lua (%p): %s\n", L, msg ? msg : "");
	int top = lua_gettop(L);
	for (int i=1; i<=top; i++) {
		switch(lua_type(L, i)) {
			case LUA_TNIL:
				printf("%i (-%i): nil\n", i, top+1-i); break;
			case LUA_TBOOLEAN:
				printf("%i (-%i): boolean (%s)\n", i, top+1-i, lua_toboolean(L, i) ? "true" : "false"); break;
			case LUA_TLIGHTUSERDATA:
				printf("%i (-%i): lightuserdata (%p)\n", i, top+1-i, lua_topointer(L, i)); break;
			case LUA_TNUMBER:
				printf("%i (-%i): number (%f)\n", i, top+1-i, lua_tonumber(L, i)); break;
			case LUA_TSTRING:
				printf("%i (-%i): string (%s)\n", i, top+1-i, lua_tostring(L, i)); break;
			case LUA_TUSERDATA:
			case 10:	// LuaJIT cdata
//				printf("%i (-%i): userdata (%p)\n", i, top+1-i, lua_topointer(L, i)); break;
				lua_getglobal(L, "tostring");
				lua_pushvalue(L, i);
				lua_call(L, 1, 1);
				printf("%i (-%i): %s\n", i, top+1-i, lua_tostring(L, -1));
				lua_pop(L, 1);
				break;
//				printf("%i (-%i): userdata (%p)\n", i, top+1-i, lua_topointer(L, i)); break;
			default:{
				printf("%i (-%i): %s (%p)\n", i, top+1-i, lua_typename(L, lua_type(L, i)), lua_topointer(L, i));
			}
		}
	}
	return L;
}

lua_State * av_init_lua() {
	// initialize Lua:
	lua_State * L = lua_open();
	luaL_openlibs(L);
	
	// cache debug.traceback:
	lua_getglobal(L, "debug");
	lua_getfield(L, -1, "traceback");
	lua_setfield(L, LUA_REGISTRYINDEX, "debug.traceback");
	lua_pop(L, 1); // debug
	
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
	chdir(workpath);
	
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
	new FileWatcher(loop, mainfile, main_modified);
	
	printf("starting\n");
	glutMainLoop();
	return 0;
}
