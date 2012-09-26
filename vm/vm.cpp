#include "vm.h"
#include "stdio.h"

#include "alloutil/al_Lua.hpp"
#include "allocore/protocol/al_OSC.hpp"
#include "allocore/system/al_Time.hpp"

/* Apache Portable Runtime */
#include "apr_general.h"
#include "apr_errno.h"
#include "apr_pools.h"
#include "apr_network_io.h"
#include "apr_time.h"

#include "zmq.h"

using namespace al;

al_sec OSC_TIMEOUT = 0.1;
// until we know better:
std::string serverIP = "127.0.01";
Lua L;

void * zcontext;

//  Convert C string to 0MQ string and send to socket
static int
s_send (void *socket, const char *string) {
    zmq_msg_t message;
    zmq_msg_init_size (&message, strlen(string));
    memcpy (zmq_msg_data (&message), string, strlen (string));
    int size = zmq_send (socket, &message, 0);
    zmq_msg_close (&message);
    return (size);
}

class BackgroundThread : public ThreadFunction, public osc::PacketHandler {
public:

	BackgroundThread() 
	:	receiver(8019),
		sender(0),
		active(true),
		thread(*this) 
	{
		receiver.handler(*this);
		
		int rc;
		
		pub = zmq_socket(zcontext, ZMQ_PUB);
		//zmq_setsockopt(sub, ZMQ_LINGER, 0, 0);
		rc = zmq_connect (sub, "epgm://en0;239.255.1.1:5555");
		
//		rc = zmq_bind(pub, "tcp://*:5556");
		if (rc) printf("error binding publisher: %s\n", zmq_strerror(rc));
//		
//		s_send(pub, "hello pubs");
		
		//sub = zmq_socket(zcontext, ZMQ_SUB);
		//zmq_setsockopt(sub, ZMQ_LINGER, 0, 0);
		//rc = zmq_connect (sub, "pgm://en0;239.255.1.1:5555");
		//if (rc) printf("error connecting subscriber: %s\n", zmq_strerror(rc));
		
		//zmq_setsockopt(sub, ZMQ_SUBSCRIBE, "git");
		
	}
	
	virtual ~BackgroundThread() {
		active = false;
		thread.join();
		if (sender) delete sender;
		zmq_close(pub);
	}
	
	virtual void onMessage(osc::Message& m) {
		if (m.addressPattern() == "/git") {
			std::string cmd;
			m >> cmd;
			printf("git %s\n", cmd.c_str());
			// execute git pull
		} else if (m.addressPattern() == "/handshake") {
			m >> serverIP;
			printf("Server IP is: %s\n", serverIP.c_str());
			
			sender = new osc::Send(8010, serverIP.c_str(), serverIP.size());
		} else {
			m.print();
		}
	}

	virtual void operator()() {
		while (active) {
			// poll recv and handle commands
			while(receiver.recv()){
				al_sleep(OSC_TIMEOUT);
			}
			al_sleep(OSC_TIMEOUT);
		}
	}
	
	osc::Recv receiver;
	osc::Send * sender;
	bool active;
	Thread thread;
	
	void * pub;
	void * sub;
};

int main(int argc, char * argv[]) {

	zcontext = zmq_init(1);

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
	BackgroundThread bt;
	
	while(1) {
		al_sleep(1);
	}
	
	bt.active = 0;
	
	zmq_term(zcontext);
	
	printf("bye\n");
	return 0;
}
