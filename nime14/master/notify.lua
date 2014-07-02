
-- notifications:
local events = {}
local
function register(k, v)
	-- get or create map:
	local e = events[k]
	if not e then 
		e = {} 
		events[k] = e
	end
	-- add to map:
	e[v] = true
end

local 
function unregister(k, v)
	local e = events[k]
	e[v] = nil
end

local 
function trigger(k, ...)
	local e = events[k]
	if e then
		for o in pairs(e) do
			o:notify(k, ...)
		end
	end
end

return {
	register = register,
	unregister = unregister,
	trigger = trigger,
}