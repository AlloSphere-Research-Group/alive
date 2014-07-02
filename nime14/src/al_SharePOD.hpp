#ifndef AL_SHAREPOD_H
#define AL_SHAREPOD_H

#include "allocore/system/al_Config.h"

#include <string>

#define SHAREPOD_DEFAULT_PORT 4141

namespace al {

/*
	SharePOD runs a server, which will serve the latest POD to any client requesting it
	
	TODO:	
		server handler to provide the POD ptr
		client handler to use/apply the received POD
		timestamps applied to POD messages
		ringbuffering of PODs
		zeroconf to avoid needing explicit server name 
*/
class SharedBlob {
public:

	class Handler {
	public:
	
		// this handler is called when a client receives blob from the server
		virtual void onReceivedSharedBlob(const char * blob, size_t size) = 0;
		
		// this handler is called when a server requires data to send to a client
		virtual char * onSendSharedBlob() = 0;
	
	};

	// bytes sets the size of blob data to be sent/received
	SharedBlob(int bytes);
	~SharedBlob();
	
	// start listening for client requests on this port
	// (runs in a background thread)
	// warning: the handler pointer must outlive the SharedBlob
	bool startServer(Handler * h, int port=SHAREPOD_DEFAULT_PORT); 
	
	// start requesting updates from the server
	// (runs in a background thread)
	// warning: the handler pointer must outlive the SharedBlob
	bool startClient(Handler * h, const std::string& serverName, int port=SHAREPOD_DEFAULT_PORT); 
	
	// client only: signal for a data request:
	void clientRequest();
	
protected:
	class Impl;
	Impl * mImpl;
};

/*
	POD must be a 'plain old data' struct
	POD means:	no pointers, 
				no objects with pointers, 
				no virtuals, 
				no strings (only char arrays) 
				etc.
	Just: term = atomic or array(term) or struct(terms)
*/
template<typename POD>
class SharePOD : public SharedBlob {
public:

	// bytes sets the size of blob data to be sent/received
	SharePOD() 
	:	SharedBlob(sizeof(POD))
	{}
	
	virtual ~SharePOD() {}
	
protected:

};

} // al::

#endif // AL_SHAREPOD_H