
#include "avm_dev.h"

// the window
av_Window win;

static bool initialized = 0;

void timerfunc(int id) {

	// trigger scheduled events via uv_run_once()
	av_tick();
	
	// update window:
	if (win.draw) {
		(win.draw)(&win);
	}	
	glutSwapBuffers();
	
	// reschedule:
	glutTimerFunc((unsigned int)(1000.0/win.fps), timerfunc, 0);
}

void av_window_settitle(av_Window * self, const char * name) {
	glutSetWindowTitle(name);
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
	if (win.onmouse) {
		(win.onmouse)(&win, 2, win.button, x, y);
	}
}

void onpassivemotion(int x, int y) {
	if (win.onmouse) {
		(win.onmouse)(&win, 3, win.button, x, y);
	}
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

void initwindow() {
	if (initialized) return;

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
	
	glutTimerFunc((unsigned int)(1000.0/win.fps), timerfunc, 0);

	initialized = true;
}

av_Window * av_window_create() {
	initwindow();
	return &win;
}
