local ffi = require "ffi"
local bit = require "bit"
local format = string.format
local min = math.min
local ceil = math.ceil
local band, lshift, rshift = bit.band, bit.lshift, bit.rshift

ffi.cdef [[
	void * memcpy(void *, const void *, size_t);

	typedef union tube_word_t {
		struct {
			uint32_t size;
			uint32_t type;
		} tag;
		double d;
		void * p;
	} tube_word_t;
		
	typedef struct tube_t {
		uint32_t size, wrap, read, write;
		tube_word_t * data;
	} tube_t;
]]
local C = ffi.C

local LUA_TSTRING = 4

-- the alignment size of messages: 
local wordsize = ffi.sizeof("tube_word_t")
local wordwrap = ffi.sizeof("tube_word_t") - 1
local shift = 0
do
	local w = wordsize
	while w > 1 do
		w = w / 2
		shift = shift + 1
	end
end

-- round up to nearest multiple of wordsize
-- is there any easier way to do this?
local function aligned(sz)
	if sz > 0 then
		return lshift(1+rshift(sz-1, shift), shift)
	else
		return 0
	end
end

-- the number of words available for writing
local function writespace(atube)
	local r, w = atube.read, atube.write
	if r == w then
		-- the maximum writable size, ever:
		return atube.size - wordsize
	else
		return band(atube.size + r - w, atube.wrap) - 1
	end
end

-- the number of words available for reading
local function readspace(atube)
	local r, w = atube.read, atube.write
	return band(atube.size + w - r, atube.wrap)
end

-- Copy sz bytes into the ringbuffer
-- Returns false & error msg if insufficient space
-- (copy is necessary because of ring boundary)
-- Actual memory used is rounded up to a multiple of tube_word_t size
local function write(atube, src, sz) 
	-- cache
	local size, wrap, w = atube.size, atube.wrap, atube.write
	-- align to word:
	local asz = aligned(sz)
	
	local space = writespace(atube)
	if space < asz then
		return false, format("insufficient space (%d) for sought %d (aligned %d)", space, sz, asz)
	end
	
	-- last byte:
	local e = w + sz
	if e < atube.size then
		C.memcpy(atube.data+w, src, sz)
	else
		local split = size-w
		e = band(e, wrap)
		C.memcpy(atube.data+w, src, split)
		C.memcpy(atube.data, ffi.cast("char *", src)+split, e)
	end
	-- align to word:
	atube.write = band(w + asz, wrap)
	return true
end

local function peekdouble(atube)
	if readspace(atube) > ffi.sizeof("double") then
		local t = ffi.cast("tube_word_t *", atube.data + atube.read)
		return t[0]
	end
end

-- Read data and advance the read pointer
-- sz is the maximum amount to copy
-- Returns bytes actually copied
-- (copy is necessary because of ring boundary)
local function read(atube, dst, sz)
	-- cache
	local size, wrap, r = atube.size, atube.wrap, atube.read
	
	local space = readspace(atube)
	sz = min(sz, space)
	if sz < 1 then return 0 end
	
	-- align to word:
	local asz = aligned(sz)
	
	-- last byte:
	local e = r + sz
	
	if e < atube.size then
		C.memcpy(ffi.cast("char *", dst), atube.data+r, sz)
	else
		local split = atube.size-r
		e = band(e, atube.wrap)
		C.memcpy(ffi.cast("char *", dst), atube.data+r, split)
		C.memcpy(ffi.cast("char *", dst)+split, atube.data, e)
	end
	
	-- align to word:
	atube.read = band(w + asz, wrap)
	return sz
end

--------------------------------------------------------------------------------

local sender = {}
sender.__index = sender

function sender:send_number(n, w)
	self.data[w].d = n
	return band(w + 1, self.wrap)
end
function sender:send_pointer(p, w)
	self.data[w].p = p
	return band(w + 1, self.wrap)
end
function sender:send_tag(s, t, w)
	self.data[w].tag.size = s
	self.data[w].tag.type = t
	return band(w + 1, self.wrap)
end

-- warning: this will fail if sz < 1.
function sender:send_bytes(s, w)
	w = self:send_tag(sz, LUA_TSTRING, w)
	-- convert bytes to words:
	local wsz = 1+rshift(sz-1, shift)
	local e = w + wsz
	if e < self.size then
		C.memcpy(self.data+w, src, sz)
		return e
	else
		local split = self.size - w
		local splitbytes = split * wordsize
		local remainbytes = sz - splitbytes
		C.memcpy(self.data+w, src, splitbytes)
		C.memcpy(self.data, ffi.cast("char *", src)+split, remainbytes)
		return band(e, selfwrap)
	end
end

function sender:send_string(s, w)
	local sz = #s
	if sz > 0 then
		w = self:send_tag(sz, LUA_TSTRING, w)
		w = self:send_bytes(sz, s, w)
	end
	return w
end

local
function required_size(arg, sz)
	if type(arg) == "number" or type(arg) == "userdata" then
		sz = sz + 1
	elseif type(arg) == "string" then
		sz = sz + #arg + 1
	elseif type(arg) == "table" then
		for i = 1, #arg do
			sz = send_size(arg[i], sz)
		end 
	else
		error("type not supported for sending")
	end
end

function sender:send_arg(arg, w)
	if type(arg) == "number" then
		w = self:send_number(arg, w)
	elseif type(arg) == "userdata" then
		w = self:send_pointer(arg, w)
	elseif type(arg) == "string" then
		w = self:send_string(arg, w)
	elseif type(arg) == "table" then
		for i = 1, #arg do
			w = self:send_arg(arg[i], w)
		end 
	else
		error("type not supported for sending")
	end
	return w
end

function sender:send(t, args)
	-- determine required size:
	local sz = required_size(args, 1)
	-- ensure size is available
	if writespace(self.tube) < sz then
		error("insufficient space to send")
	end
	
	-- write timestamp & data
	local w = self.tube.write
	w = self:send_number(t, w)
	w = self:send_arg(args, w)
	-- update write ptr
	self.tube.write = w
end

local function recv(atube)
	local wrap, r = atube.wrap, atube.read
	local space = readspace(atube)
	if space > 0 then
		local x = atube.data[r].d
		atube.read = band(r + 1, wrap)
		return x
	end
end

-- use a metatype?

return {
	write = write,
	read = read,
	
	send = send,
	recv = recv,
	
	sender = function(atube)
		return setmetatable({
			tube = atube,
			data = tube.data,
			size = tube.size,
			wrap = tube.wrap,
		}, sender)
	end
}