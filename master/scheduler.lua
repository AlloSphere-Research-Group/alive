local coro, coresume, coyield, corunning, costatus = coroutine.create, coroutine.resume, coroutine.yield, coroutine.running, coroutine.status
local max, min, abs = math.max, math.min, math.abs
local traceback = debug.traceback
local format = string.format

local eventqs = {}	

-- weak map of coroutine to the scheduler/list that contains it:
local Cmap = {}
-- set the map keys to be weak, so that they don't prevent garbage collections:
setmetatable(Cmap, { __mode = "k" })

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
	-- store in map:
	Cmap[q] = m
end

local 
function remove(q, C)
	local p = q.head
	if p then
		if p.C == C then
			-- remove from head:
			q.head = p.next
			return
		else
			while p do
				local n = p.next
				if n and n.C == C then
					-- remove n:
					p.next = n.next
					return
				end
				p = n
			end
		end
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

local task = {}
task.__index = task

function task:__tostring()
	return format("task(%q)", self.C)
end

function task:cancel()
	-- is it temporal or event based?
end

return function()
	local self = { t=0 }
	
	self.cancel = function(C)
		-- find out where the coroutine is scheduled:
		local q = Cmap[C]
		if q then
			if q.t then
				-- it is a scheduler
				remove(q, C)
			else
				-- it is an event list
				for i = 1, #q do
					if q[i] == C then
						table.remove(q, i)
						return
					end
				end
			end
		end
	end
	
	self.now = function()
		return self.t
	end
	
	self.wait = function(e)
		local C = corunning()
		if type(e) == "number" then
			sched(self, { C=C, t=self.t+abs(e) } )
		elseif type(e) == "string" then
			local q = eventq_find(e)
			q[#q+1] = C
			Cmap[q] = C
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
			local C = q[1]
			-- remove from queue:
			table.remove(q, 1)
			-- remove from map:
			Cmap[C] = nil
			-- call it:
			resume(C, ...)
		end
	end	
	
	self.go = function(e, func, ...)
		local args
		if type(e) == "function" then
			args = {func, ...}
			func = e
			e = 0
		else
			args = {...}
		end
		
		local C
		if type(e) == "string" then
			local C = coro(func)
			local q = eventq_find(e)
			q[#q+1] = C
			Cmap[q] = C
			return C
		elseif type(e) == "number" then
			local C = coro(function() return func(unpack(args)) end)
			sched(self, { C=C, t=self.t+e } )
			return C
		else
			error("bad type for go")
		end
	end
	
	self.update = function(t)
		-- check for pending coros:
		local m = self.head
		while m and m.t < t do
			self.t = max(self.t, m.t)
			-- remove from queue:
			local n = m.next
			self.head = n
			-- remove from map:
			Cmap[m.C] = nil
			-- resume it:
			resume(m.C)
			-- continue to next item:
			m = n
		end
		self.t = t
	end
	self.advance = function(dt)
		self.update(self.t + dt)
	end
	
	self.sequence = function(func, time, repeats)
		local _stop = false
		local _scheduler = self
		local count = 0
		local limited = (type(repeats) == 'number')

		local o
		o = {
			run = function()
				while not _stop do
					func()
					wait(time)
					if limited and count < repeats then
						count = count + 1
						if count >= repeats then 
							_stop = true
						end
					end
				end
			end,
			stop = function()
				_stop = true
			end,
			start = function()
				_stop = false
				_scheduler.go(o.run)
			end
		}

		self.go(o.run)

		return o
	end
	
	return self
end