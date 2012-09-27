#include "vm.h"
#include "stdio.h"

#include "alloutil/al_Lua.hpp"
#include "allocore/protocol/al_OSC.hpp"
#include "allocore/system/al_Time.hpp"
#include "allocore/io/al_AudioIO.hpp"
#include "allocore/io/al_Window.hpp"
#include "allocore/graphics/al_Graphics.hpp"
#include "allocore/types/al_MsgTube.hpp"

/* Apache Portable Runtime */
#include "apr_general.h"
#include "apr_errno.h"
#include "apr_pools.h"
#include "apr_network_io.h"
#include "apr_time.h"

extern "C" {

	typedef union tube_word_t {
		struct {
			uint32_t size;
			uint32_t type;
		} tag;
		double d;
		void * p;
	} tube_word_t;
		
	typedef struct tube_t {
		uint32_t size, wrap, read, write;
		char * data;
	} tube_t;
}

tube_t atube;

using namespace al;

al_sec OSC_TIMEOUT = 0.1;
// until we know better:
std::string serverIP = "127.0.01";
Lua L, A;
SingleRWRingBuffer audiotube(16384);

AudioIO audio;
Window win;

class App : public AudioCallback, public WindowEventHandler, public InputEventHandler {
public:

	App() {
		audio.append(*(AudioCallback *)this);
		win.append(*(WindowEventHandler *)this);
		win.append(*(InputEventHandler *)this);
	}

	virtual ~App() {
		
	}
	
	virtual void onAudioCB(AudioIOData& io) {
	
		
		
		// call into A:
		A.getglobal("onAudioCB");
		if (lua_isfunction(A, -1)) {
			A.pcall(0);
		}
	}

	virtual bool onKeyDown(const Keyboard& k){return true;}	///< Called when a keyboard key is pressed
	virtual bool onKeyUp(const Keyboard& k){return true;}	///< Called when a keyboard key is released

	virtual bool onMouseDown(const Mouse& m){return true;}	///< Called when a mouse button is pressed
	virtual bool onMouseDrag(const Mouse& m){return true;}	///< Called when the mouse moves while a button is down
	virtual bool onMouseMove(const Mouse& m){return true;}	///< Called when the mouse moves
	virtual bool onMouseUp(const Mouse& m){return true;}	///< Called when a mouse button is released
	virtual bool onCreate(){ return true; }					///< Called after window is created with valid OpenGL context
	virtual bool onDestroy(){ return true; }				///< Called before the window and its OpenGL context are destroyed
	
	
	virtual bool onResize(int dw, int dh){ return true; }	///< Called whenever window dimensions change
	virtual bool onVisibility(bool v){ return true; }		///< Called when window changes from hidden to shown and vice versa
	
	virtual bool onFrame(){ 
		Graphics gl;
		gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
		
		L.getglobal("onFrame");
		if (lua_isfunction(L, -1)) {
			L.pcall(0);
		}
		
		fflush(stdout);
		fflush(stderr);
		return true; 
	}
	
};

App app;

// expose for use in Lua states:
extern "C" {

	float * audio_outbuffer(int chan) { return audio.outBuffer(chan); }
	const float * audio_inbuffer(int chan) { return audio.inBuffer(chan); }
	float * audio_busbuffer(int chan) { return audio.busBuffer(chan); }
	float audio_samplerate() { return audio.fps(); }
	int audio_buffersize() { return audio.framesPerBuffer(); }
	int audio_channelsin() { return audio.channelsIn(); }
	int audio_channelsout() { return audio.channelsOut(); }
	int audio_channelsbus() { return ((AudioIOData &)audio).channelsBus(); }
	double audio_time() { return audio.time(); }
	void audio_zeroout() { audio.zeroOut(); }
	
	size_t audiotube_writespace() { return audiotube.writeSpace(); }
	size_t audiotube_readspace() { return audiotube.readSpace(); }
	size_t audiotube_write(const char * src, size_t sz) { return audiotube.write(src, sz); }
	size_t audiotube_read(char * dst, size_t sz) { return audiotube.read(dst, sz); }
	size_t audiotube_peek(char * dst, size_t sz) { return audiotube.peek(dst, sz); }
	//char * audiotube_head() { return audiotube.
	
	tube_t * atube_get() { return &atube; }
}

int main(int argc, char * argv[]) {

	// initialize tube:
	atube.size = 1024;
	atube.wrap = atube.size - 1;
	atube.read = 0;
	atube.write = 0;
	atube.data = new char[atube.size * 8];
	printf("atube %p\n", &atube);


	/*
		This is a vm runtime launcher providing services
			it hosts (loads & runs) user code from a git repo
				- needs to know what the start file is
				
			Background thread connects to a server 
				to receive notifications to pull the latest git code
				and send feedback (prints & errors) back to server
					- dup pipe, but in a thread-safe way (al_msgqueue?)
			
			it watches file dates & reloads with notifications to hosted code
				- needs to know dependency hierarchy for reloading?
			
			it provides OS services to the hosted code (GL window, audio cb etc.)		
				- via C API usable in C++ as well as LuaJIT
		
		Write this vm in C++ or LuaJIT?
		
		Should we use zmq instead of OSC? 
			+ easy multicast
			+ auto-reconnection
	*/
	
	// execute in the contenxt of wherever this is run from:
	chdir("./");
	
	// add some useful globals:
	L.push(al::Socket::hostName().c_str());
	lua_setglobal(L, "hostname");
	
	// TODO: duplicate stdout/stderr to OSC/zmq sender
	// (in a thread safe way...)

	// run a startup script:
	if (L.dofile(argc > 1 ? argv[1] : "./start.lua")) return -1;
	
	if (A.dofile(argc > 1 ? argv[1] : "./sounds.lua")) return -1;
	
	printf("starting\n");
	
	// implemented in C++?
	//BackgroundThread bt;
	
	win.create();
	AudioDevice::printAll();
	audio.print();
	audio.start();
	
	
	win.startLoop();
	delete[] atube.data;
	
	printf("bye\n");
	return 0;
}
