
#ifdef __APPLE__
#include <OpenGL/OpenGL.h>
#include <GLUT/glut.h>
#else
#include <GL/gl.h>
#include <GL/glut.h>
#endif

#include "uv_utils.h"

uv_loop_t * mainloop;
int win;

void timerfunc(int id) {
	// do stuff
	int res = uv_run_once(mainloop);
	//printf("uv: %d\n", res);
	
	//draw();
	glClear(GL_COLOR_BUFFER_BIT);
	glutSwapBuffers();
	glutTimerFunc((unsigned int)(1000.0/30.), timerfunc, 0);
}

int main_idle(int status) {
	//printf("main_idle\n");
	return 1;
}


int main_modified(const char * filename) {
	printf("modified %s\n", filename);
	return 1;
}



int main(int argc, char * argv[]) {

	glutInit(&argc, argv);
	
	mainloop = uv_default_loop();	
	
	win = glutCreateWindow("");
	glutSetWindow(win);
	
	glutTimerFunc((unsigned int)(1000.0/30.), timerfunc, 0);
	
	const char * main_filename = "uvtest.cpp";
	new FileWatcher(mainloop, main_filename, main_modified);
	// add an idler to prevent runloop blocking:
	new Idler(mainloop, main_idle);
	
	printf("starting\n");
	glutMainLoop();
		
	printf("bye\n");
	return 0;
}
