#ifndef AL_FFI_H
#define AL_FFI_H

#include "allocore/graphics/al_Image.hpp"
#include "allocore/graphics/al_Asset.hpp"
#include "allocore/graphics/al_Font.hpp"
#include "allocore/system/al_MainLoop.hpp"
#include "allocore/system/al_Thread.hpp"
#include "allocore/io/al_File.hpp"
#include "allocore/io/al_Window.hpp"
#include "allocore/math/al_Random.hpp"
#include "allocore/spatial/al_HashSpace.hpp"

#include "alloutil/al_Field3D.hpp"
#include "alloutil/al_Lua.hpp"

class al_Window;
typedef void (*onWindowFunc)(al_Window * win);
typedef void (*onWindowResizeFunc)(al_Window * win, int w, int h);
typedef void (*onWindowMouseFunc)(al_Window * win, const char * event, int btn, int x, int y);
typedef void (*onWindowKeyboardFunc)(al_Window * win, const char * event, int key);

class al_Window : public al::Window {
public:
	al_Window() 
	:	Window(), 
		onFrameFunc(0), onCreateFunc(0), onDestroyFunc(0), onResizeFunc(0), onKeyFunc(0), onMouseFunc(0) {}
	
	
	virtual bool onKeyDown(const al::Keyboard& k){
		if (onKeyFunc) onKeyFunc(this, "down", k.key()); 
		return true;
	}	
	virtual bool onKeyUp(const al::Keyboard& k){
		if (onKeyFunc) onKeyFunc(this, "up", k.key()); 
		return true;
	}	
	virtual bool onMouseDown(const al::Mouse& m){
		if (onMouseFunc) onMouseFunc(this, "down", m.button(), m.x(), m.y()); 
		return true;
	}	
	virtual bool onMouseDrag(const al::Mouse& m){
		if (onMouseFunc) onMouseFunc(this, "drag", m.button(), m.x(), m.y()); 
		return true;
	}	
	virtual bool onMouseMove(const al::Mouse& m){
		if (onMouseFunc) onMouseFunc(this, "move", m.button(), m.x(), m.y()); 
		return true;
	}	
	virtual bool onMouseUp(const al::Mouse& m){
		if (onMouseFunc) onMouseFunc(this, "up", m.button(), m.x(), m.y()); 
		return true;
	}	
	
	virtual bool onCreate(){ 
		if (onCreateFunc) onCreateFunc(this); 
		return true; 
	}					
	virtual bool onDestroy(){ 
		if (onDestroyFunc) onDestroyFunc(this); 
		return true;
	}
	virtual bool onFrame(){ 
		if (onFrameFunc) onFrameFunc(this); 
		return true;
	}
	virtual bool onResize(int dw, int dh){ 
		if (onResizeFunc) onResizeFunc(this, this->width(), this->height());
		return true; 
	}	
	virtual bool onVisibility(bool v){ return true; }		
	
	
	onWindowFunc onFrameFunc;
	onWindowFunc onCreateFunc;
	onWindowFunc onDestroyFunc;
	onWindowResizeFunc onResizeFunc;
	onWindowKeyboardFunc onKeyFunc;
	onWindowMouseFunc onMouseFunc;
};

#endif
