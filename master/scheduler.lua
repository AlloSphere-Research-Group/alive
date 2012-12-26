local coro, coresume, coyield, corunning, costatus = coroutine.create, coroutine.resume, coroutine.yield, coroutine.running, coroutine.status
local max, min, abs = math.max, math.min, math.abs
local traceback = debug.traceback

local eventqs = {}	

local 
function eventq_find(e) 
	local q = rawget(eventqs, e)
	if not q then
		q = {}
		rawset(eventqs, e, q)
	end
	return q
end

local 
function sched(q, m)
	if not q.head then
		q.head = m
	elseif m.t < q.head.t then
		m.next = q.head
		q.head = m
	else
		-- insertion sort, nothing fancy
		local p = q.head
		local n = p.next
		while n and n.t <= m.t do
			p = n
			n = n.next
		end
		m.next = n
		p.next = m
	end
end

local 
function resume(C, ...)
	local status = costatus(C)
	if status == "suspended" then
		local ok, err = coresume(C, ...)
		if not ok then print(traceback(C, err)) end
	end
end

return function()
	local self = { t=0 }
	self.now = function()
		return self.t
	end
	self.wait = function(e)
		local C = corunning()
		if type(e) == "number" then
			sched(self, { C=C, t=self.t+abs(e) } )
		elseif type(e) == "string" then
			table.insert(eventq_find(e), C)
		end
		return coyield()
	end
	self.event = function(e, ...)
		local q = eventq_find(e)
		--for each coro in the list, schedule it (and remove it from the list)
		--check number waiting at this point, 
		--since within resume() a coro may re-await on the same event
		local size = #q
		for i = 1,size do
			local C = q[1]; table.remove(q, 1)
			resume(C, ...)
		end
	end	
	self.go = function(e, func, ...)
		local args
    print('TYPE' .. type(e))
		if type(e) == "function" then
			args = {func, ...}
			func = e
			e = 0
		else
			args = {...}
		end
		
		if type(e) == "string" then
			local C = coro(func)
			table.insert(eventq_find(e), C)
		elseif type(e) == "number" then
			local C = coro(function() return func(unpack(args)) end)
			sched(self, { C=C, t=self.t+e } )
		else
			error("bad type for go")
		end
	end
	self.update = function(t)
		-- check for pending coros:
		local m = self.head
		while m and m.t < t do
			self.t = max(self.t, m.t)
			local n = m.next
			self.head = n
			-- resume it:
			resume(m.C)
			m = n
		end
		self.t = t
	end
	self.advance = function(dt)
		self.update(self.t + dt)
	end
  self.sequence = function(func, time)
    local _stop = false
    local _scheduler = self
    local o = {
      run = function()
        while not _stop do
          func()
          wait(time)
        end
      end,
      stop = function()
        _stop = true
      end,
    }
    o.start = function()
      _stop = false
      _scheduler.go(o.run)
    end
    
    self.go(o.run)
    
    return o
  end
	
	return self
end