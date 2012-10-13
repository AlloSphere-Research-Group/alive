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
Window win;



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
	
	if (win.onframe) {
		(win.onframe)(&win);
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
	if (!win.fullscreen) {
		win.width = w;
		win.height = h;
	}
	printf("reshaped %d %d\n", win.width, win.height);
}

void gofullscreen(bool b=true) {
	win.fullscreen = b;
	if (b) {
		glutFullScreen();
	} else {
		glutReshapeWindow(win.width, win.height);
	}
}

void onkeydown(unsigned char k, int x, int y) {
	printf("key %d\n", k);
	if (k == 27) {
		gofullscreen(!win.fullscreen);
	}
}

void initwindow() {
	// initialize window:
	win.id = 0;
	win.width = 720;
	win.height = 480;
	win.fullscreen = false;
	win.fps = 40.;
	win.onframe = 0;
	
//	screen_width = glutGet(GLUT_SCREEN_WIDTH);
//	screen_height = glutGet(GLUT_SCREEN_HEIGHT);	
	
	glutInitWindowPosition(0, 0);
	glutInitWindowSize(win.width, win.height);
	glutInitDisplayMode(GLUT_RGBA | GLUT_DOUBLE | GLUT_DEPTH);
	win.id = glutCreateWindow("");
	glutSetWindow(win.id);
	
//	glutSetWindowTitle("");
//	glutIgnoreKeyRepeat(1);
//	glutSetCursor(GLUT_CURSOR_NONE);

	glutKeyboardFunc(onkeydown);
//	glutKeyboardUpFunc(cbKeyboardUp);
//	glutMouseFunc(cbMouse);
//	glutMotionFunc(cbMotion);
//	glutPassiveMotionFunc(cbPassiveMotion);
//	glutSpecialFunc(cbSpecial);
//	glutSpecialUpFunc(cbSpecialUp);
//	glutVisibilityFunc(cbVisibility);
	glutReshapeFunc(onreshape);
	glutDisplayFunc(ondisplay);

}

Window * window_get() {
	return &win;
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
