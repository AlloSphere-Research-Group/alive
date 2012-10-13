#include "avm.h"
#include "uv_utils.h"

#ifdef __APPLE__
#include <OpenGL/OpenGL.h>
#include <GLUT/glut.h>
#else
#include <GL/gl.h>
#include <GL/glut.h>
#endif

extern "C" {
	#include "lua.h"
	#include "lualib.h"
	#include "lauxlib.h"
}

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

// the window
av_Window win;



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


void timerfunc(int id) {
	// do stuff
	//int res = 
	uv_run_once(mainloop);
	//printf("uv: %d\n", res);
	
	//draw();
	glClearColor(0., 0.2, 0.5, 1.);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	
	if (win.draw) {
		(win.draw)(&win);
	}
	
	glutSwapBuffers();
	// reschedule:
	glutTimerFunc((unsigned int)(1000.0/win.fps), timerfunc, 0);
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

void ondisplay() {}
void onreshape(int w, int h) {
	if (!win.is_fullscreen) {
		win.width = w;
		win.height = h;
	}
	if (win.resize) {
		(win.resize)(&win, w, h);
	}
}

void av_window_setfullscreen(av_Window * self, int b) {
	win.is_fullscreen = b;
	if (b) {
		glutFullScreen();
	} else {
		glutReshapeWindow(win.width, win.height);
	}
}

void av_window_setdim(av_Window * self, int x, int y) {
	glutReshapeWindow(x, y);
}

void getmodifiers() {
	int mod = glutGetModifiers();
	win.shift = mod & GLUT_ACTIVE_SHIFT;
	win.alt = mod & GLUT_ACTIVE_ALT;
	win.ctrl = mod & GLUT_ACTIVE_CTRL;
}

void onkeydown(unsigned char k, int x, int y) {
	getmodifiers();
	if (win.onkey) {
		(win.onkey)(&win, 1, k);
	}
}

void onkeyup(unsigned char k, int x, int y) {
	getmodifiers();
	if (win.onkey) {
		(win.onkey)(&win, 2, k);
	}
}

void onspecialkey(int key, int x, int y) {
	getmodifiers();
	printf("special %d\n", key);
	// like function keys etc. what to do with these?
}

void onmouse(int button, int state, int x, int y) {
	getmodifiers();
	win.button = button;
	if (win.onmouse) {
		(win.onmouse)(&win, state, win.button, x, y);
	}
}

void onmotion(int x, int y) {
	getmodifiers();
	if (win.onmouse) {
		(win.onmouse)(&win, 2, win.button, x, y);
	}
}

void onpassivemotion(int x, int y) {
	if (win.onmouse) {
		(win.onmouse)(&win, 3, win.button, x, y);
	}
}

void initwindow() {
	// initialize window:
	win.width = 720;
	win.height = 480;
	win.button = 0;
	win.is_fullscreen = false;
	win.fps = 40.;
	win.draw = 0;
	win.resize = 0;
	win.onkey = 0;
	win.onmouse = 0;
	
//	screen_width = glutGet(GLUT_SCREEN_WIDTH);
//	screen_height = glutGet(GLUT_SCREEN_HEIGHT);	
	
	glutInitWindowPosition(0, 0);
	glutInitWindowSize(win.width, win.height);
	glutInitDisplayMode(GLUT_RGBA | GLUT_DOUBLE | GLUT_DEPTH);
	win.id = glutCreateWindow("");
	glutSetWindow(win.id);
	
//	glutIgnoreKeyRepeat(1);
//	glutSetCursor(GLUT_CURSOR_NONE);

	glutKeyboardFunc(onkeydown);
	glutKeyboardUpFunc(onkeyup);
	glutMouseFunc(onmouse);
	glutMotionFunc(onmotion);
	glutPassiveMotionFunc(onpassivemotion);
//	glutSpecialFunc(onspecialkey);
//	glutSpecialUpFunc(cbSpecialUp);
//	glutVisibilityFunc(cbVisibility);
	glutReshapeFunc(onreshape);
	glutDisplayFunc(ondisplay);

}

av_Window * av_window_create() {
	return &win;
}

void av_window_settitle(av_Window * self, const char * name) {
	glutSetWindowTitle(name);
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
	int r = chdir("./");
	printf("chdir %d\n", r);
	
	// initialize UV:
	mainloop = uv_default_loop();
	// add an idler to prevent uv loop blocking:
	new Idler(mainloop, main_idle);
	
	// start watching:
	const char * main_filename = "main.lua";
	new FileWatcher(mainloop, main_filename, main_modified);
	
	// initialize window:
	initwindow();
	
	// initialize Lua:
	L = initLua(apppath);
	
	glutTimerFunc((unsigned int)(1000.0/win.fps), timerfunc, 0);
	glutMainLoop();
	return 0;
}
