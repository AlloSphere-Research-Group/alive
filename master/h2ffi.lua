#!/usr/bin/luajit

local args = {...}
local input = assert(args[1], "specify file to parse")
local output = args[2]

local r = {
	"local header = [[",
	string.format("// generated from %s on %s", input, os.date()),
}

local h = io.popen(string.format("gcc -E %s", input))
for l in h:lines() do
	local s = l:gsub("(#[^\n]+)", "")
	if #s > 0 then
		r[#r+1] = s
	end
end

r[#r+1] = "]]"
r[#r+1] = "local ffi = require 'ffi'"
r[#r+1] = "ffi.cdef(header)"
r[#r+1] = "return header"

local code = table.concat(r, "\n")

if output then
	io.open(output, "w"):write(code)
else
	print(code)
end