local ffi = require 'ffi'
local lib = ffi.C

ffi.cdef [[
	typedef struct al_Main al_Main;
	typedef double (*taskfunc)(double t);
	
	al_Main * al_main_get();
	void al_main_start();
	
	double al_main_now();
	double al_main_realtime();
	double al_main_cpu();
	int al_main_isrunning();
	
	void al_main_task(double at, taskfunc f);
	
	void al_sleep(double);
]]

-- the module:
local Main = {
	start = lib.al_main_start,
	now = lib.al_main_now,
	realtime = lib.al_main_realtime,
	cpu = lib.al_main_cpu,
	isRunning = lib.al_main_isrunning,
}
Main.__index = Main

function Main.sched(t, f)
	if type(t) == "function" then
		f = t
		t = 0
	end
	lib.al_main_task(t, f)
end

return Main