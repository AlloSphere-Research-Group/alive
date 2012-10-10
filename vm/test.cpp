
#include <OpenGL/OpenGL.h>
#include <GLUT/glut.h>

#include "stdio.h"

#define AL_STRINGIFY(...) #__VA_ARGS__

struct Vec3f { 
	float x, y, z; 
};

Vec3f vertices[] = { 
	{ 0, 0, -1 },
	{ 1, 0, 0 },
	{ -1, 0, 0 },
	
	{ 0, 1, 0 },
	{ 1, 0, 0 },
	{ -1, 0, 0 },
		
	{ 0, 1, 0 },
	{ 0, 0, -1 },
	{ 1, 0, 0 },
		
	{ -1, 0, 0 },
	{ 0, 1, 0 },
	{ 0, 0, -1 }
};

GLuint buffer;
GLuint program;
GLint attr_position;

int win;
int w = 640, h = 480;

const char * vs = AL_STRINGIFY(
	attribute vec3 position;

	void main() {
		gl_Position = gl_ModelViewProjectionMatrix * vec4(position, 1.0);
	}
);

const char * fs = AL_STRINGIFY(
	void main() {
		gl_FragColor = vec4(1, 0, 1, 1);
	}
);

GLuint createShader(GLenum kind, const char * code) {
	GLuint shader = glCreateShader(kind);
	if (code) {
		GLint status;
		glShaderSource(shader, 1, &code, NULL);
		glCompileShader(shader);
		glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
		if (status == GL_FALSE) {
			GLint infoLogLength;
			glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &infoLogLength);
			char strInfoLog[infoLogLength+1];
			glGetShaderInfoLog(shader, infoLogLength, 0, strInfoLog);
			printf("%s\n", strInfoLog);
		}
	}
	return shader;
}

GLuint createProgram(GLuint v, GLuint f) {
	GLuint program = glCreateProgram();
	
	glAttachShader(program, v);
	glAttachShader(program, f);
	glLinkProgram(program);
		
	GLint status;
	glGetProgramiv(program, GL_LINK_STATUS, &status);
	if (status == GL_FALSE) {
		GLint infoLogLength;
		glGetProgramiv(program, GL_INFO_LOG_LENGTH, &infoLogLength);
		char strInfoLog[infoLogLength+1];
		glGetProgramInfoLog(program, infoLogLength, 0, strInfoLog);
		printf("%s\n", strInfoLog);	
	}
	
	glDetachShader(program, v);
	glDetachShader(program, f);
	return program;
}

void draw() {
	static int frame = 0;
	if (frame == 0) {
		// create everything
		GLuint vert = createShader(GL_VERTEX_SHADER, vs);
		GLuint frag = createShader(GL_FRAGMENT_SHADER, fs);
		program = createProgram(vert, frag);
		
		glUseProgram(program);
		attr_position = glGetAttribLocation(program, "position");
		glUseProgram(0);
		
		glGenBuffers(1, &buffer);
		glBindBuffer(GL_ARRAY_BUFFER, buffer);
		//-- STATIC, STREAM (regularly replace en-masse), DYNAMIC (regularly modify)
		glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_DYNAMIC_DRAW);
		glBindBuffer(GL_ARRAY_BUFFER, 0);
	}

	glViewport(0, 0, w, h);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	glUseProgram(program);
	attr_position = glGetAttribLocation(program, "position");
	
	// modern vertex buffer mode:
	glBindBuffer(GL_ARRAY_BUFFER, buffer);
	glEnableVertexAttribArray(attr_position);
	glVertexAttribPointer(
		attr_position,  //-- attribute
		3, //-- size
		GL_FLOAT, //-- type
		GL_FALSE, //-- normalized
		sizeof(float)*3, //-- stride
		(void *)0  //-- offset
	);
	glDrawArrays(GL_TRIANGLES, 0, 12);
	glDisableVertexAttribArray(attr_position);
	glBindBuffer(GL_ARRAY_BUFFER, 0);
	
	// new school vertex array mode:
//	glEnableVertexAttribArray(attr_position);
//	glVertexAttribPointer(
//		attr_position,  //-- attribute
//		3, //-- size
//		GL_FLOAT, //-- type
//		GL_FALSE, //-- normalized
//		sizeof(float)*3, //-- stride
//		(void *)vertices  //-- offset
//	);
//	
//	glDrawArrays(GL_TRIANGLES, 0, 12);
//	glDisableVertexAttribArray(attr_position);
	
	// old school vertex array mode:
//	glEnableClientState(GL_VERTEX_ARRAY);
//	glVertexPointer(3, GL_FLOAT, 0, vertices);
//	glDrawArrays(GL_TRIANGLES, 0, 12);
//	glDisableClientState(GL_VERTEX_ARRAY);
		
	// old school immediate mode:
//	glBegin(GL_TRIANGLES);
//		glColor3f(1, 0, 0);
//		glVertex3f(0, 0, -1);
//		glVertex3f(1, 0, 0);
//		glVertex3f(-1, 0, 0);
//		
//		glColor3f(0, 0, 1);
//		glVertex3f(0, 1, 0);
//		glVertex3f(1, 0, 0);
//		glVertex3f(-1, 0, 0);
//		
//		glColor3f(1, 1, 0);
//		glVertex3f(0, 1, 0);
//		glVertex3f(0, 0, -1);
//		glVertex3f(1, 0, 0);
//		
//		glColor3f(0, 1, 1);
//		glVertex3f(-1, 0, 0);
//		glVertex3f(0, 1, 0);
//		glVertex3f(0, 0, -1);
//	glEnd();
	
	glUseProgram(0);
	frame++;
}

void timerfunc(int id) {
	// do stuff
	printf(".");
	draw();
	
	glutSwapBuffers();
	glutTimerFunc((unsigned int)(1000.0/30.), timerfunc, 0);
}

void reshape(int w, int h) {
	printf("reshape %d %d\n", w, h);
}

void display() {}

void enterFullscreen() {
	glutFullScreen();
}

void exitFullscreen() {
	glutReshapeWindow(w, h);
}

//int mod = glutGetModifiers();
//int	alt = (mod & GLUT_ACTIVE_ALT);
//int	ctrl = (mod & GLUT_ACTIVE_CTRL);
//int	shift = (mod & GLUT_ACTIVE_SHIFT);

int main(int argc, char * argv[]) {
	glutInit(&argc,argv);

	int sw = glutGet(GLUT_SCREEN_WIDTH);
	int sh = glutGet(GLUT_SCREEN_HEIGHT);
	
	glutInitWindowSize(w, h);
	glutInitWindowPosition(0, 0);
	glutInitDisplayMode(GLUT_RGBA | GLUT_DOUBLE | GLUT_DEPTH);
	win = glutCreateWindow("");
	glutSetWindow(win);
	//glutSetWindowTitle("");
	glutIgnoreKeyRepeat(1);
	
//	glutKeyboardFunc(cbKeyboard);
//	glutKeyboardUpFunc(cbKeyboardUp);
//	glutMouseFunc(cbMouse);
//	glutMotionFunc(cbMotion);
//	glutPassiveMotionFunc(cbPassiveMotion);
//	glutSpecialFunc(cbSpecial);
//	glutSpecialUpFunc(cbSpecialUp);
//	glutVisibilityFunc(cbVisibility);
	glutReshapeFunc(reshape);
	glutDisplayFunc(display);

	glutTimerFunc((unsigned int)(1000.0/30.), timerfunc, 0);
	
	//glutSetCursor(GLUT_CURSOR_NONE);
	
	glutMainLoop();
					
	return 0;
}
