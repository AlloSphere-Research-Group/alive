
#include "av_dev.h"

struct GLUTWindow : public av_Window {
	GLUTWindow() {
		width = 960;
		height = 480;
		button = 0;
		is_fullscreen = false;
		fps = 40.;
		
		ondraw = 0;
		oncreate = 0;
		onresize = 0;
		onvisible = 0;
		onkey = 0;
		onmouse = 0;
		
		id = 0;
		non_fullscreen_width = width;
		non_fullscreen_height = height;
	}
	
	// private fields:
	int id;
	int non_fullscreen_width, non_fullscreen_height;
};

// the window
GLUTWindow win;

static bool reload = true;

void timerfunc(int id) {

	// trigger scheduled events via uv_run_once()
	av_tick();
	
	// update window:
	if (reload && win.oncreate) {
		(win.oncreate)(&win);
		reload = false;
	}
	if (win.ondraw) {
		(win.ondraw)(&win);
	}	
	glutSwapBuffers();
	
	// reschedule:
	glutTimerFunc((unsigned int)(1000.0/win.fps), timerfunc, 0);
}

void av_window_settitle(av_Window * self, const char * name) {
	glutSetWindowTitle(name);
}

void av_window_setfullscreen(av_Window * self, int b) {
	reload = true;
	win.is_fullscreen = b;
	if (b) {
		glutFullScreen();
	} else {
		glutReshapeWindow(win.non_fullscreen_width, win.non_fullscreen_height);
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

void onspecialkeydown(int key, int x, int y) {
	getmodifiers();
	
	#define CS(k) case GLUT_KEY_##k: key = AV_KEY_##k; break;
	switch(key){
		CS(LEFT) CS(UP) CS(RIGHT) CS(DOWN)
		CS(PAGE_UP) CS(PAGE_DOWN)
		CS(HOME) CS(END) CS(INSERT)

		CS(F1) CS(F2) CS(F3) CS(F4)
		CS(F5) CS(F6) CS(F7) CS(F8)
		CS(F9) CS(F10)	CS(F11) CS(F12)
	}
	#undef CS
	
	if (win.onkey) {
		(win.onkey)(&win, 1, key);
	}
}

void onspecialkeyup(int key, int x, int y) {
	getmodifiers();
	
	#define CS(k) case GLUT_KEY_##k: key = AV_KEY_##k; break;
	switch(key){
		CS(F1) CS(F2) CS(F3) CS(F4)
		CS(F5) CS(F6) CS(F7) CS(F8)
		CS(F9) CS(F10)	CS(F11) CS(F12)
		
		CS(LEFT) CS(UP) CS(RIGHT) CS(DOWN)
		CS(PAGE_UP) CS(PAGE_DOWN)
		CS(HOME) CS(END) CS(INSERT)
	}
	#undef CS
	
	if (win.onkey) {
		(win.onkey)(&win, 2, key);
	}
}

void onmouse(int button, int state, int x, int y) {
	getmodifiers();
	win.button = button;
	if (win.onmouse) {
		(win.onmouse)(&win, state, win.button, x, y);
	}
}

void onmotion(int x, int y) {
	if (win.onmouse) {
		(win.onmouse)(&win, 2, win.button, x, y);
	}
}

void onpassivemotion(int x, int y) {
	if (win.onmouse) {
		(win.onmouse)(&win, 3, win.button, x, y);
	}
}

void onvisibility(int state) {
	if (win.onvisible) (win.onvisible)(&win, state);
}

void ondisplay() {}
void onreshape(int w, int h) {
	win.width = w;
	win.height = h;
	if (!win.is_fullscreen) {
		win.non_fullscreen_width = win.width;
		win.non_fullscreen_height = win.height;
	}
	if (win.onresize) {
		(win.onresize)(&win, w, h);
	}
}

void terminate() {
	printf("exit -- bye\n");
}

void initwindow() {
	static bool initialized = false;
	if (initialized) return;
	
	int argc = 0;
	char * argv[] = {
		NULL
	};
	glutInit(&argc, argv);
	
//	screen_width = glutGet(GLUT_SCREEN_WIDTH);
//	screen_height = glutGet(GLUT_SCREEN_HEIGHT);	
	
	glutInitDisplayMode(GLUT_RGBA | GLUT_DOUBLE | GLUT_DEPTH);
	glutInitWindowSize(win.width, win.height);
	glutInitWindowPosition(0, 0);
	printf("glutCreateWindow:\n");
	win.id = glutCreateWindow("");	// << FAIL?
	printf("initializing window\n");
	glutSetWindow(win.id);
	
//	glutIgnoreKeyRepeat(1);
//	glutSetCursor(GLUT_CURSOR_NONE);

	glutKeyboardFunc(onkeydown);
	glutKeyboardUpFunc(onkeyup);
	glutMouseFunc(onmouse);
	glutMotionFunc(onmotion);
	glutPassiveMotionFunc(onpassivemotion);
	glutSpecialFunc(onspecialkeydown);
	glutSpecialUpFunc(onspecialkeyup);
	glutVisibilityFunc(onvisibility);
	glutReshapeFunc(onreshape);
	glutDisplayFunc(ondisplay);
	
	glutTimerFunc((unsigned int)(1000.0/win.fps), timerfunc, 0);
	
	atexit(terminate);

	initialized = true;
}

av_Window * av_window_create() {
	initwindow();
	return &win;
}
