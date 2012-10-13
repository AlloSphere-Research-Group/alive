#include "avm.h"
#include "uv_utils.h"

#include <string.h>
#include <libgen.h>

// the path from where it was invoked, e.g. user workspace:
char wd[PATH_MAX];
// the path where the binary actually resides, e.g. with resources:
char apppath[PATH_MAX];

uv_loop_t * mainloop;
int win;
bool fullscreen = false;
int w = 720, h = 480;

lua_State * L = 0;

void timerfunc(int id) {
	// do stuff
	int res = uv_run_once(mainloop);
	//printf("uv: %d\n", res);
	
	//draw();
	glClearColor(0., 0.2, 0.5, 1.);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	glutSwapBuffers();
	glutTimerFunc((unsigned int)(1000.0/30.), timerfunc, 0);
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
void onreshape(int w1, int h1) {
	if (!fullscreen) {
		w = w1;
		h = h1;
	}
	printf("reshaped %d %d\n", w, h);
}

void gofullscreen(bool b=true) {
	fullscreen = b;
	if (b) {
		glutFullScreen();
	} else {
		glutReshapeWindow(w, h);
	}
}

void onkeydown(unsigned char k, int x, int y) {
	printf("key %d\n", k);

	if (k == 27) {
		gofullscreen(!fullscreen);
	}
}

int main(int argc, char * argv[]) {
	glutInit(&argc, argv);
	
	if (getcwd(wd, PATH_MAX) == 0) {
		printf("could not derive working path\n");
		exit(0);
	}
	printf("wd %s\n", wd);
	
	// get binary path:
	char tmppath[PATH_MAX];
	#ifdef __APPLE__
		if (argc > 0) {
			realpath(argv[0], apppath);
		}
	#else
		// Linux only?
		int count = readlink("/proc/self/exe", tmppath, PATH_MAX);
		if (count > 0) {
			tmppath[count] = '\0';
		} else if (argc > 0) {
			realpath(argv[0], tmppath);
		}
	#endif
	// Windows only:
	// GetModuleFileName(NULL, apppath, PATH_MAX)
	
	snprintf(apppath, PATH_MAX, "%s/", dirname(tmppath));
	printf("path %s\n", apppath);
	
	// see also realpath(), which gets rid of ~, ../ etc.
	
	// execute in the context of wherever this is run from:
	chdir("./");
	
	if (getcwd(wd, PATH_MAX) == 0) {
		printf("could not derive working path\n");
		exit(0);
	}
	printf("wd %s\n", wd);
	
	L = lua_open();
	luaL_openlibs(L);

//	screen_width = glutGet(GLUT_SCREEN_WIDTH);
//	screen_height = glutGet(GLUT_SCREEN_HEIGHT);	
	
	glutInitWindowPosition(0, 0);
	glutInitWindowSize(w, h);
	glutInitDisplayMode(GLUT_RGBA | GLUT_DOUBLE | GLUT_DEPTH);
	win = glutCreateWindow("");
	glutSetWindow(win);
	
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
	
	glutTimerFunc((unsigned int)(1000.0/30.), timerfunc, 0);
	
	
	mainloop = uv_default_loop();
	
	const char * main_filename = "main.lua";
	new FileWatcher(mainloop, main_filename, main_modified);
	// add an idler to prevent runloop blocking:
	new Idler(mainloop, main_idle);
	
	printf("starting\n");
	glutMainLoop();
		
	printf("bye\n");
	return 0;
}
