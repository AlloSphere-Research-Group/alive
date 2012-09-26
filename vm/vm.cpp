/*
 *  vm.cpp
 *  alive
 *
 *  Created by Graham Wakefield on 9/25/12.
 *  Copyright 2012 UCSB. All rights reserved.
 *
 */

#include "vm.h"
#include "stdio.h"

#include "alloutil/al_Lua.hpp"
#include "allocore/io/al_Socket.hpp"

/* Apache Portable Runtime */
#include "apr_general.h"
#include "apr_errno.h"
#include "apr_pools.h"
#include "apr_network_io.h"
#include "apr_time.h"

static const int ALIVE_PORT = 8082;

using namespace al;

Lua L;

struct AprObject {
	apr_pool_t * pool;
	
	static apr_status_t check_apr(apr_status_t err) {
		char errstr[1024];
		if (err != APR_SUCCESS) {
			apr_strerror(err, errstr, 1024);
			printf("%s\n", errstr);
		}
		return err;
	}
};

struct Recv : public AprObject {
	apr_sockaddr_t * sa;
	apr_socket_t * sock;
	apr_port_t port;
	
	Recv() {
		port = ALIVE_PORT;
		check_apr(apr_pool_create(&pool, NULL));
		
		/* @see http://dev.ariel-networks.com/apr/apr-tutorial/html/apr-tutorial-13.html */
		
		check_apr(apr_sockaddr_info_get(&sa, NULL, APR_INET, port, 0, pool));
		// for TCP, use SOCK_STREAM and APR_PROTO_TCP instead
		check_apr(apr_socket_create(&sock, sa->family, SOCK_DGRAM, APR_PROTO_UDP, pool));
		// bind socket to address:
		check_apr(apr_socket_bind(sock, sa));
		check_apr(apr_socket_opt_set(sock, APR_SO_NONBLOCK, 1));
	}
	
	~Recv() {
		check_apr(apr_socket_close(sock));
		apr_pool_destroy(pool);
	}
};


int main(int argc, char * argv[]) {
	chdir("./");
	
	// add some useful globals:
	L.push(al::Socket::hostName().c_str());
	lua_setglobal(L, "hostname");

	// run a startup script:
	if (L.dofile(argc > 1 ? argv[1] : "./start.lua")) return -1;
	
	printf("bye\n");
	return 0;
}
