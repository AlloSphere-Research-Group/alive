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
#include "allocore/protocol/al_OSC.hpp"

using namespace al;

Lua L;


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
