#include "vm.h"
#include "stdio.h"

#include "alloutil/al_Lua.hpp"
#include "allocore/protocol/al_OSC.hpp"
#include "allocore/system/al_Time.hpp"
#include "allocore/io/al_Window.hpp"

/* Apache Portable Runtime */
#include "apr_general.h"
#include "apr_errno.h"
#include "apr_pools.h"
#include "apr_network_io.h"
#include "apr_time.h"


using namespace al;

al_sec OSC_TIMEOUT = 0.1;
// until we know better:
std::string serverIP = "127.0.01";
Lua L;

Window win;

int main(int argc, char * argv[]) {

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
	//if (L.dofile(argc > 1 ? argv[1] : "./start.lua")) return -1;
	
	printf("starting\n");
	
	// implemented in C++?
	//BackgroundThread bt;
	
	win.create();
	win.startLoop();
	
	//bt.active = 0;
	
	
	
	printf("bye\n");
	return 0;
}
