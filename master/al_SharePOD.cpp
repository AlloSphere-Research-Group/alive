#include "al_SharePOD.hpp"
#include "../../AlloSystem/allocore/src/private/al_ImplAPR.h"

#if defined( __APPLE__ ) && defined( __MACH__ )
	#include "apr-1/apr_general.h"
	#include "apr-1/apr_errno.h"
	#include "apr-1/apr_pools.h"
	#include "apr-1/apr_network_io.h"
	#include "apr-1/apr_time.h"
	#include "apr-1/apr_thread_proc.h"
	#include "apr-1/apr_poll.h"

#else
	#include "apr-1.0/apr_general.h"
	#include "apr-1.0/apr_errno.h"
	#include "apr-1.0/apr_pools.h"
	#include "apr-1.0/apr_network_io.h"
	#include "apr-1.0/apr_time.h"
	#include "apr-1.0/apr_thread_proc.h"
	#include "apr-1.0/apr_poll.h"
#endif

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string>

#define REQUEST_BUFFER_SIZE 1024
#define DEF_POLL_TIMEOUT	(APR_USEC_PER_SEC * 30)

using namespace al;

class SharedBlob::Impl : public ImplAPR {
public:

	// state associated with a server-client session
	struct Session {
		apr_socket_t * client;
		apr_pollfd_t pfd;
		apr_size_t remain;
		char * buffer;
		bool sending;
		
	};
	
	Impl(int bytes) {
		mSock = 0;
		mSockAddr = 0;
		
		mSize = bytes;
		mBuffer = (char *)malloc(bytes);
		
		thd = 0;
		thd_attr = 0;
		
		handler = 0;
	}
	
	~Impl() {
		free(mBuffer);
	}
	
	bool startServer(int port) {
		mPort = port;
		
		// launch thread:
		if (check_apr(apr_threadattr_create(&thd_attr, mPool))) return false;
		if (check_apr(apr_thread_create(&thd, thd_attr, serverThreadFunc, this, mPool))) return false;
		return true;
	}
	
	static void * serverThreadFunc(apr_thread_t * thd, void * data) {
		((Impl *)data)->serverThread();
		return 0;
	}
	
	void serverThread() {
		printf("server listening on port %d\n", mPort);
		
		if (check_apr(apr_sockaddr_info_get(&mSockAddr, NULL, APR_INET, mPort, 0, mPool))) return;
		if (check_apr(apr_socket_create(&mSock, mSockAddr->family, SOCK_STREAM, APR_PROTO_TCP, mPool))) return;
		
		// configure non-blocking:
		check_apr(apr_socket_opt_set(mSock, APR_SO_NONBLOCK, 1));
		check_apr(apr_socket_timeout_set(mSock, 0));
		apr_socket_opt_set(mSock, APR_SO_REUSEADDR, 1); // this is useful for a server(socket listening) process 
		
		// bind:
		if (check_apr(apr_socket_bind(mSock, mSockAddr))) return;
		if (check_apr(apr_socket_listen(mSock, SOMAXCONN))) return;
		
		// create a pollset for this socket
		apr_pollset_t *pollset;
		apr_pollset_create(&pollset, 16, mPool, 0);
		
		// add poll watcher to notify when it is ready to read (POLLIN):
		{
			apr_pollfd_t pfd = { mPool, APR_POLL_SOCKET, APR_POLLIN, 0, { NULL }, NULL };
			pfd.desc.s = mSock;
			apr_pollset_add(pollset, &pfd);
		}
				
		while (true) {
			apr_int32_t numActiveSockets;
			const apr_pollfd_t *ret_pfd;
			
			// find out how many sockets have activity:
			apr_status_t rv = check_apr(apr_pollset_poll(pollset, DEF_POLL_TIMEOUT, &numActiveSockets, &ret_pfd));
			if (rv == APR_SUCCESS && numActiveSockets > 0) {
				
				// scan active sockets:
				for (int i=0; i<numActiveSockets; i++) {
					//printf("activity on socket %d\n", i);
					
					// if this is the server socket:
					if (ret_pfd[i].desc.s == mSock) {
						// there is activity on our listener socket
						// this indicates we accepted a connection
						
						apr_socket_t * client;	// accepted socket
						if (0 == check_apr(apr_socket_accept(&client, mSock, mPool))) {
							//printf("listener accepted\n");
							
							
							// configure non-blocking:
							apr_socket_opt_set(client, APR_SO_NONBLOCK, 1);
							apr_socket_timeout_set(client, 0);
							
							// add client to our pollset:
							Session * session = new Session;
							session->client = client;
							session->sending = false;
							
							session->pfd.p = mPool;
							session->pfd.desc_type = APR_POLL_SOCKET;
							session->pfd.reqevents = APR_POLLIN;
							session->pfd.rtnevents = 0;
							session->pfd.desc.s = session->client;
							session->pfd.client_data = (void *)session;
							
							apr_pollset_add(pollset, &session->pfd);
						}
						
					} else {
						// must be some other client socket activity:
						Session * session = (Session *)ret_pfd[i].client_data;
						// check session state:
						if (session->sending) {
							//printf("sending to %d %p (%d remain)\n", i, session, session->remain);
							
							// try to send:
							apr_size_t len = session->remain;
							check_apr(apr_socket_send(session->client, session->buffer, &len));
							//printf("sent %d\n", (int)len);
							
							if (len == 0) {
								// finished sending:
								session->remain = 0;
								
								// remove sender:
								apr_pollset_remove(pollset, &session->pfd);
								
								// go back to being a receiver:
								session->sending = false;
								session->pfd.reqevents = APR_POLLIN;
								apr_pollset_add(pollset, &session->pfd);
																
							} else {
								session->remain -= len;
							}
							
						} else {
							//printf("receiving from %d %p\n", i, session);
							
							// try to receive data:
							char buf[REQUEST_BUFFER_SIZE];
							apr_size_t len = REQUEST_BUFFER_SIZE - 1; // -1 for a null-terminated
							apr_status_t rv1 = check_apr(apr_socket_recv(session->client, buf, &len));
							buf[len] = '\0';
							//printf("received %s\n", buf);
							
							// remove reader:
							apr_pollset_remove(pollset, &session->pfd);
							
							if (len) {
								// add writer:
								session->sending = true;
								session->pfd.reqevents = APR_POLLOUT;
								session->remain = mSize;
								session->buffer = handler->onSendSharedBlob();
								apr_pollset_add(pollset, &session->pfd);
							} 
						}
					}
				}
			}			
		
			
//			apr_socket_t * client;	// accepted socket
//			if (0 == check_apr(apr_socket_accept(&client, mSock, mPool))) {
//				printf("accepted\n");
//				bool connected = true;
//				
//				// configure blocking:
//				check_apr(apr_socket_opt_set(client, APR_SO_NONBLOCK, 0));
//				check_apr(apr_socket_timeout_set(client, (apr_interval_time_t)(-1)));
//				
//				while (connected) {
//					// receive data:
//					char buf[REQUEST_BUFFER_SIZE];
//					apr_size_t len = REQUEST_BUFFER_SIZE - 1; // -1 for a null-terminated
//					apr_status_t rv = check_apr(apr_socket_recv(client, buf, &len));
//					if (rv == APR_EOF || len == 0) {
//						connected = false;
//						break;
//					}
//					
//					buf[len] = '\0';
//					printf("received %s\n", buf);
//					
//					// now try to send:
//					len = mSize;
//					check_apr(apr_socket_send(client, mBuffer, &len));
//					printf("sent %d\n", (int)len);
//					
//				}
//				apr_socket_close(client);
//			}
		}
		
		apr_socket_close(mSock);
	}
	
	
	
	bool startClient(const std::string& serverName, int port) {
		mPort = port;
		mServerName = serverName;
		
		// launch thread:
		if (check_apr(apr_threadattr_create(&thd_attr, mPool))) return false;
		if (check_apr(apr_thread_create(&thd, thd_attr, clientThreadFunc, this, mPool))) return false;
		return true;
	}
	
	static void * clientThreadFunc(apr_thread_t * thd, void * data) {
		((Impl *)data)->clientThread();
		return 0;
	}
	
	void clientThread() {
		printf("client requesting from %s on port %d\n", mServerName.c_str(), mPort);
		
		if (check_apr(apr_sockaddr_info_get(&mSockAddr, mServerName.c_str(), APR_INET, mPort, 0, mPool))) return;
		if (check_apr(apr_socket_create(&mSock, mSockAddr->family, SOCK_STREAM, APR_PROTO_TCP, mPool))) return;
		if (!mSock) return;
		
		while (true) {
		
			// configure blocking:
			check_apr(apr_socket_opt_set(mSock, APR_SO_NONBLOCK, 0));
			check_apr(apr_socket_timeout_set(mSock, -1));
			
			// wait for connection accept (does not appear to be blocking, not sure why?)
			if (0 == check_apr(apr_socket_connect(mSock, mSockAddr))) {
				
				bool connected = true;
				printf("connected to %s!\n", mServerName.c_str());
				
				// apparently need to configure blocking again:
				check_apr(apr_socket_opt_set(mSock, APR_SO_NONBLOCK, 0));
				check_apr(apr_socket_timeout_set(mSock, -1));
				
				for (int frame = 0; connected; frame++) {
					
					// send a request:
					const char * header = "GIMME";	// could add hostname here etc.
					apr_size_t headerlen = strlen(header);
					if (0 == check_apr(apr_socket_send(mSock, header, &headerlen))) {
					
						// initialize frame writer:
						apr_time_t start = apr_time_now();
						apr_size_t remain = mSize;
						apr_size_t len = remain;
						char * writeptr = mBuffer;	
						
						// start receiving the response:
						while (remain) {
							apr_status_t rv = check_apr(apr_socket_recv(mSock, writeptr, &len));
							if (rv == APR_EOF || len == 0) {
								// message terminated:
								break;
							}
							
							// update frame writer:
							writeptr += len;
							remain -= len;
						}
						
						if (remain == 0) {
							// completed transfer:
							handler->onReceivedSharedBlob(mBuffer, mSize);
							
							if (frame % 25 == 0) printf("frame %d complete\n", frame);
						} else {
							// assume error
							connected = false;
						}

					} else {
						// assume connection lost?
						connected = false;
					}

				}
			}
			
			//apr_socket_close(mSock);
			//return;
		}
		
		apr_socket_close(mSock);
	}
	
	int mPort;
	std::string mServerName;
	
	// the listener thread:
	apr_threadattr_t * thd_attr;
	apr_thread_t * thd;
	
	apr_sockaddr_t * mSockAddr;
	apr_socket_t * mSock;
	
	apr_size_t mSize;
	char * mBuffer;
	
	SharedBlob::Handler * handler;
};

SharedBlob::SharedBlob(int bytes) {
	mImpl = new Impl(bytes);
}

SharedBlob::~SharedBlob() {
	delete mImpl;
}

bool SharedBlob :: startServer(Handler * h, int port) {
	mImpl->handler = h;
	return mImpl->startServer(port);
}

bool SharedBlob :: startClient(Handler * h, const std::string& serverName, int port) {
	mImpl->handler = h;
	return mImpl->startClient(serverName, port);
}