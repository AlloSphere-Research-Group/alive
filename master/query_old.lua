
local q = {}

function query(base, ...)
	return setmetatable({
		base, ...
	}, q)
end

function q:__tostring()
	local args = {}
	for i = 1, #self do args[i] = tostring(rawget(self, i)) end
	return string.format("query(%s)", 
		table.concat(args, ".")
	)
end

function q:__index(k)
	local meta = rawget(q, k)
	if meta then 
		return meta 
	else
		-- create a sub-query:
		local q1 = { unpack(self) }
		q1[#q1+1] = k
		return setmetatable(q1, q)
	end
end

function q:pick(n)
	-- create a sub-query:
	local q1 = { unpack(self) }
	q1[#q1+1] = function(item)
		if math.random() < n then return item end
	end
	return setmetatable(q1, q)
end

function q:__newindex(k, v)
	--print("newindex", self, k, v)
	local base = rawget(self, 1)
	for i = 1, #base do
		local item = base[i]
		local j = 2
		while item and j <= #self do
			local term = rawget(self, j)
			if type(term) == "function" then
				item = term(item)
			else
				item = item[term]
			end
			j = j + 1
		end
		--print("item.newindex", i, item, k, v)
		if item then
			if item[k] then
				-- replacing an existing item...
			end
			if type(v) == "function" then
				item[k] = v()	-- what args to this function?
			else
				item[k] = v
			end
		end
	end
end

function q:__call(path, ...)
	--print("call", self, path, ...)
	local base = rawget(self, 1)
	
	-- we could detect method calls here, by comparing self & path
	-- if self is an immediate child of path...
	local methodcall = true
	if getmetatable(path) == q and getmetatable(self) == q then
		if #self == #path + 1 then
			for i = 1, #path do
				if rawget(self, i) ~= rawget(path, i) then
					methodcall = false
					break
				end
			end
		else
			methodcall = false
		end
	else
		methodcall = false
	end
	
	for i = 1, #base do
		local item = base[i]
		--print("item", i, item)
		local j = 2
		while item and j <= #self do
			local term = rawget(self, j)
			if j == #self then
				-- apply behavior here:
				local f = item[term]
				--print("apply", i, item, term, f)
				if type(f) == "function" then
					-- how did we know it was a method call?
					if methodcall then
						f(item, ...)
					else
						f(path, ...)
					end
				elseif f then
					print('attempt to call non-function', f)
				end
			else
				if type(term) == "function" then
					item = term(item)
				else
					item = item[term]
				end
				--print("term", term, i, j, item)
			end
			j = j + 1
		end
	end
end

local alltags = {}

local t = {}

function maketag(name)
	local obj = setmetatable({ name=name }, t)
	
	alltags[name] = obj
	
	-- return as query:
	return query(obj)
end	

function t:__tostring()
	return string.format("tag('%s', %d)", self.name, #self)
end

function t:__index(k)
	return rawget(t, k) or query(self, k)
end

function t:__newindex(k, v)
	query(self)[k] = v
end

-- tag(obj) inserts the object into the tag
function t:__call(obj)
	-- maybe want to make sure it isn't already inserted?
	rawset(self, #self+1, obj)
end
t.attach = t.__call

function add(name, obj)
	local tag = alltags[name]
	tag:attach(obj)
end

------------------ TEST ------------------
--[[
local beep = maketag("beep")

function test(self, k)
	print("test", self[k])
end

add("beep", { foo = { bar = { finger = "a", test=test } }, test=test })
add("beep", { foo = {  } })
add("beep", { foo = { bar = { finger = "c", test=test } }, test=test })

-- make some changes:
beep.foo.bar:test("finger")
beep.foo.bar.finger = 10
beep.foo.bar:test("finger")
beep.foo.bar.test({ finger=8 }, "finger")
beep.foo = 10
beep:test("foo")

print("done")
--]]

return query