#include "alive.h"
#include "uv.h"

#include "stdio.h"
#include "stdlib.h"

#include "alloutil/al_Lua.hpp"

al::Lua L;

int main(int argc, char * argv[]) {
	
	// execute in the context of wherever this is run from:
	chdir("./");
	
	lua_newtable(L);
	for (int i=0; i<argc; i++) {
		lua_pushstring(L, argv[i]);
		lua_rawseti(L, -2, i+1);
	}
	lua_setglobal(L, "argv");

	if (L.dofile("./uvtest.lua")) return -1;
	
	return 0;
}