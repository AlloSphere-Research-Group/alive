#include "al_ffi.h"

using namespace al;

static void * globals = NULL;
static Graphics gl;

extern "C" {
	void * al_globals_get() { return globals; }
	void al_globals_set(void * p) { globals = p; }
	
	void al_sleep(double);
	
	double al_filedate(const char * path) {
		if (File::exists(path)) {
			return al::File::modified(path);
		} else {
			return 0;
		}
	}

};


// Random ffi:
rnd::Random<> rng;
extern "C" {
	void al_rnd_seed(uint32_t v) { rng.seed(v); }
	float al_rnd_uniform() { return rng.uniform(); }
	float al_rnd_uniformS() { return rng.uniformS(); }
	float al_rnd_gaussian() { return rng.gaussian(); }
	int al_rnd_prob(float p) { return rng.prob(p); }
}

typedef double (*taskfunc)(double t);

struct Sender {
	Sender(double at, taskfunc func) : func(func) {
		update(at);
	}
	
	void update(double t) {
		double rpt = func(t);
		if (rpt > 0) {
			Main::get().queue().send(t + rpt, this, &Sender::update);
		} else {
			delete this;
		}
	}
	
	taskfunc func;
};	

// Main ffi:
typedef al::Main al_Main;
extern "C" {
	
	al_Main * al_main_get() { return &Main::get(); }
	void al_main_start() { Main::get().start(); }
	
	double al_main_now() { return Main::get().now(); }
	double al_main_realtime() { return Main::get().realtime(); }
	double al_main_cpu() { return Main::get().cpu(); }
	int al_main_isrunning() { return Main::get().isRunning(); }
	
	void al_main_task(double at, taskfunc f) { new Sender(at, f); }
}

// Thread ffi:
struct LuaThread : public Thread, public ThreadFunction {
	LuaThread(const char * path, double period) : path(path), period(period) {}
	virtual ~LuaThread(){}

	virtual void operator()() { 
		L.loadfile(path);
		int res = L.resume();
		while (res == LUA_YIELD) {
			al_sleep(period);
			res = L.resume();
		}
	}
	
	std::string path;
	double period;
	Lua L;
};

typedef LuaThread al_Thread;
extern "C" {
	al_Thread * al_thread_new(const char * scriptpath, double period) { 
		return new LuaThread(scriptpath, period); 
	}
	void al_thread_free(al_Thread * self) { delete self; }
	
	int al_thread_start(al_Thread * self) {
		return self->start(*self);
	}
}

// Image ffi:
typedef al::Image al_Image;
extern "C" {
	al_Image * al_image_new() { return new Image(); }
	void al_image_free(al_Image * im) { delete im; }
	int al_image_load(al_Image * im, const char * filepath) { return im->load(filepath); }
	void * al_image_pixels(al_Image * im) { return im->pixels<void *>(); }
	int al_image_width(al_Image * im) { return im->array().width(); }
	int al_image_height(al_Image * im) { return im->array().height(); }
	int al_image_format(al_Image * im) { return im->array().components(); }
	
	int al_image_write(const char * path, uint8_t * pixels, int w, int h, int channels) {
		return al::Image::write<uint8_t>(path, pixels, w, h, (al::Image::Format)(channels-1));
	}
}

// HashSpace ffi:
typedef al::HashSpace al_HashSpace;
al::HashSpace::Query nearestquery(8);
extern "C" {
	al_HashSpace * al_hashspace_new(int resolution, int objects) { 
		al_HashSpace * self = new HashSpace(resolution, objects); 
		printf("hashspace %p dim %d objs %d\n", self, self->dim(), self->numObjects());
		return self;
	}
	void al_hashspace_free(al_HashSpace * self) { delete self; }
	
	void al_hashspace_move(al_HashSpace * self, int id, double x, double y, double z) {
		Vec3d pos = self->wrap(Vec3d(x, y, z));
		self->move(id, pos);
	}
	
	void al_hashspace_remove(al_HashSpace * self, int id) {
		self->remove(id);
	}
	
	int al_hashspace_nearest(al_HashSpace * self, int id, double maxradius) {
		int results = nearestquery(*self, &(self->object(id)), maxradius);
		if (results > 0) {
			// double distance = query.distance(0);
			return nearestquery[0]->id;
		} else {
			return -1;
		}
	}
}

// Asset ffi:
extern "C" {
	int al_asset_import(const char * path, double s) {
		Mesh mesh;
		Graphics gl;
		Scene * scene;
		Scene::verbose(0);
		scene = Scene::import(path);
		for (unsigned i=0; i<scene->meshes(); i++) scene->meshAlt(i, mesh);
		delete scene;
		mesh.scale(s);
		//mesh.invertNormals();
		int id = glGenLists(1);
		glNewList(id, GL_COMPILE); 
		gl.draw(mesh);
		glEndList();
		return id;
	}
}

// Field ffi:
typedef al::Fluid3D<float> al_Fluid;
typedef al::Field3D<float> al_Field;

extern "C" {
	al_Fluid * al_fluid_new(int dimx, int dimy, int dimz) {
		return new al_Fluid(dimx, dimy, dimz);
	}
	void al_fluid_free(al_Fluid * self) { 
		delete self; 
	}
	void al_fluid_update(al_Fluid * self) { self->update(); }
	
	float * al_fluid_ptr(al_Fluid * self) {
		return self->velocities.ptr();
	}
	void al_fluid_add_gradient(al_Fluid * self, double x, double y, double z, float g) {
		self->addGradient(Vec3f(x, y, z), g);
	}
	void al_fluid_add_velocity(al_Fluid * self, double x, double y, double z, double vx, double vy, double vz) {
		self->addVelocity(Vec3f(x, y, z), Vec3d(vx, vy, vz));
	}
	Vec3f al_fluid_velocity(al_Fluid * self, double x, double y, double z) {
		Vec3f res;
		self->readVelocity(Vec3d(x, y, z), res);
		return res;
	}
	
	al_Field * al_field_new(int components, int dimx, int dimy, int dimz) {
		return new al_Field(components, dimx, dimy, dimz);
	}
	void al_field_free(al_Field * self) { delete self; }
	
	void al_field_add(al_Field * self, double x, double y, double z, float * data) {
		self->add(Vec3d(x, y, z), data);
	}
	void al_field_diffuse(al_Field * self, double diffusion) {
		self->diffuse(diffusion);
	}
	void al_field_advect(al_Field * self, al_Fluid * fluid, double amt) {
		self->advect(fluid->velocities.front(), amt);
	}
	void al_field_scale(al_Field * self, double amt) {
		self->scale(amt);
	}
	float * al_field_ptr(al_Field * self) {
		return self->ptr();
	}
}

// Mesh ffi:
typedef al::Mesh al_Mesh;
extern "C" {
	al_Mesh * al_mesh_new() { return new Mesh(); }
	void al_mesh_free(al_Mesh * self) { delete self; }
	void al_mesh_reset(al_Mesh * self) { self->reset(); }
	void al_mesh_scale(al_Mesh * self, double s) { self->scale(s); }
	void al_mesh_draw(al_Mesh * self) { gl.draw(*self); }
	
	void al_mesh_primitive(al_Mesh * self, int primitive) {
		self->primitive(primitive);
	}
	void al_mesh_vertex(al_Mesh * self, double x, double y, double z) {
		self->vertex(x, y, z);
	}
	void al_mesh_texcoord2(al_Mesh * self, double x, double y) {
		self->texCoord(x, y);
	}
	
	void al_mesh_import(al_Mesh * self, const char * obj) {
		Scene * scene;
		Scene::verbose(0);
		scene = Scene::import(obj);
		for (unsigned i=0; i<scene->meshes(); i++) scene->mesh(i, *self);
		delete scene;
	}
}

// Isosurface:
typedef al::Isosurface al_Isosurface;
extern "C" {
	al_Isosurface * al_isosurface_new() { 
		al_Isosurface * self = new Isosurface();
		self->primitive(Graphics::TRIANGLES);
		return self; 
	}
	void al_isosurface_free(al_Isosurface * self) { delete self; }
	
	void al_isosurface_level(al_Isosurface * self, double level) {
		self->level(level);
	}
	void al_isosurface_generate(al_Isosurface * self, float * data, int dim) {
		self->generate(data, dim, 1./dim);
	}
	void al_isosurface_generate_normals(al_Isosurface * self) {
		self->generateNormals();
	}
	
	void al_isosurface_draw(al_Isosurface * self) {
		Graphics gl;
		gl.draw(*self);
	}
	
	Vec3f * al_isosurface_vertices(al_Isosurface * self) {
		return &((Mesh *)self)->vertices()[0];
	}
	
	Vec3f * al_isosurface_normals(al_Isosurface * self) {
		return &((Mesh *)self)->normals()[0];
	}
	
	unsigned int * al_isosurface_indices(al_Isosurface * self) {
		return &((Mesh *)self)->indices()[0];
	}
	
	unsigned int al_isosurface_num_indices(al_Isosurface * self) {
		return ((Mesh *)self)->indices().size();
	}
	
	
};

// Font ffi:
typedef al::Font al_Font;
extern "C" {
	al_Font * al_font_new(const char * path, int size, int anti_aliased) {
		return new Font(path, size, anti_aliased);
	}
	void al_font_free(al_Font * self) { delete self; }
	
	// returns the width of a text string in pixels
	float al_font_width(al_Font * self, const char * text) { return self->width(text); }
	
	// returns the "above-line" and "below-line" height of the font in pixels
	float al_font_ascender(al_Font * self) { return self->ascender(); }
	float al_font_descender(al_Font * self) { return self->descender(); }
	
	// returns the total height of the font in pixels
	float al_font_size(al_Font * self) { return self->size(); }
	
	void al_font_render(al_Font * self, const char * text) {
		self->render(gl, text);
	}
	
	// al_font_write(font, mesh, "text");
	// al_font_texture_bind(font);
	// al_mesh_draw(mesh);
	// al_font_texture_unbind(font);
	void al_font_write(al_Font * self, al_Mesh * mesh, const char * text) {
		self->write(*mesh, text);
	}
	void al_font_texture_bind(al_Font * self) {
		self->texture().bind();
	}
	
	void al_font_texture_unbind(al_Font * self) {
		self->texture().unbind();
	}
}

// Window ffi:

extern "C" {
	al_Window * al_window_new() { return new al_Window(); }
	
	void al_window_create(al_Window * win) { win->create(); }
	void al_window_startloop(al_Window * win) { win->startLoop(); }
	
	void al_window_oncreate(al_Window * win, onWindowFunc func) {
		win->onCreateFunc = func;
	}
	void al_window_onclosing(al_Window * win, onWindowFunc func) {
		win->onDestroyFunc = func;
	}
	void al_window_onresize(al_Window * win, onWindowResizeFunc func) {
		win->onResizeFunc = func;
	}
	void al_window_ondraw(al_Window * win, onWindowFunc func) {
		win->onFrameFunc = func;
	}
	void al_window_onkey(al_Window * win, onWindowKeyboardFunc func) {
		win->onKeyFunc = func;
	}
	void al_window_onmouse(al_Window * win, onWindowMouseFunc func) {
		win->onMouseFunc = func;
	}	
	
	void al_window_displaymode(al_Window * win, int mode) {
		win->displayMode((Window::DisplayMode)mode);
	}
	
	void al_window_fullscreen(al_Window * win, int fs) {
		win->fullScreen(fs);
	}
	void al_window_cursorhide(al_Window * win, int b) {
		win->cursorHide(b);
	}
	
	void al_window_fps(al_Window * win, double v) {
		win->fps(v);
	}
	
	int al_window_getfullscreen(al_Window * win) {
		return win->fullScreen();
	}
	int al_window_getwidth(al_Window * win) { return win->width(); }
	int al_window_getheight(al_Window * win) { return win->height(); }
	double al_window_getfps(al_Window * win) { return win->fpsAvg(); }
	double al_window_getfpsactual(al_Window * win) { return win->fpsActual(); }
	double al_window_getfpsavg(al_Window * win) { return win->fpsAvg(); }
}
