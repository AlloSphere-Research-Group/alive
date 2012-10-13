#include "avm.h"
#include "uv_utils.h"

uv_loop_t * mainloop;
int win;

int w = 720, h = 480;

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
	return 1;
}

void display() {}

void enterFullscreen() {
	glutFullScreen();
}

void exitFullscreen() {
	glutReshapeWindow(w, h);
}

int main(int argc, char * argv[]) {
	glutInit(&argc, argv);
	
	// execute in the context of wherever this is run from:
	chdir("./");

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

//	glutKeyboardFunc(cbKeyboard);
//	glutKeyboardUpFunc(cbKeyboardUp);
//	glutMouseFunc(cbMouse);
//	glutMotionFunc(cbMotion);
//	glutPassiveMotionFunc(cbPassiveMotion);
//	glutSpecialFunc(cbSpecial);
//	glutSpecialUpFunc(cbSpecialUp);
//	glutVisibilityFunc(cbVisibility);
//	glutReshapeFunc(reshape);
	glutDisplayFunc(display);
	
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
