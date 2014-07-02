local format = string.format
local concat = table.concat
local random = math.random
local min = math.min
local max = math.max

-- utility to call tostring() on terms while concatenating a table:
local 
function concats(t, sep)
	if type(t) == "table" then
		local r = {}
		for i, v in ipairs(t) do r[i] = tostring(v) end
		return concat(r, sep)
	elseif type(t) == "string" then
		return format("%q", t)
	else
		return tostring(t)
	end
end

-- this is the expression-object metatable:
local e = {}
e.__index = e

-- the collection of operators:
local ops = {}

-- returns true if v is an expression-object:
local
function isexpr(v)
	return type(v) == "table" and getmetatable(v) == e
end	

-- pretty-print an expression (as probably almost-valid Lua code)
function e:__tostring()
	return self.tostring and self:tostring() or format("%s(%s)", self.op, concats(self, ","))
end

-- generic coercing constructor:
local 
function expr(v)
	if type(v) == "number" then
		return ops.Number(v)
	elseif type(v) == "string" then
		return ops.Var(v)
	elseif type(v) == "nil" then
		return ops.Number(0)
	elseif isexpr(v) then
		return v
	else
		error(format("bad type %s for expr", type(v)))
	end
end

-- coerce all subexpressions to be expr type:
function e:conform()
	for i, v in ipairs(self) do
		if not isexpr(v) then
			self[i] = expr(v)
		else
			-- recursively:
			v:conform()
		end
	end
	return self
end

local impls = {}

local 
function unop(def)
	local ctor = function (a)
		return setmetatable({ op=def.name, a }, e)
	end
	ops[def.name] = ctor
	impls[def.name] = def.lua
	return ctor
end

local 
function binop(def)
	local ctor = function(a, b)
		return setmetatable({ op=def.name, a, b }, e)
	end
	ops[def.name] = ctor
	impls[def.name] = def.lua
	return ctor
end

e.__unm = unop{ name = "Neg", lua = function(env, a) return -a end, }
e.__add = binop{ name = "Add", lua = function(env, a, b) return a+b end, }
e.__sub = binop{ name = "Sub", lua = function(env, a, b) return a-b end, }
e.__mul = binop{ name = "Mul", lua = function(env, a, b) return a*b end, }
e.__div = binop{ name = "Div", lua = function(env, a, b) return a/b end, }
e.__pow = binop{ name = "Pow", lua = function(env, a, b) return a^b end, }
e.__mod = binop{ name = "Mod", lua = function(env, a, b) return a%b end, }

unop{ name = "Number", lua = function(env, a) return a end, }
-- Var has no Lua implementation, as it is implemented in eval()
unop{ name = "Var",	lua = nil, } 

unop{ name = "Random", lua = function(env, a) return random(a) end, }
binop{ name = "Max", lua = function(env, a, b) return max(a, b) end, }
binop{ name = "Min", lua = function(env, a, b) return min(a, b) end, }

local
function eval(self, env)
	env = env or _G
	if isexpr(self) then
		if self.op == "Var" then
			return env[ self[1] ] or 0
		end
		local args = {}
		for i, v in ipairs(self) do
			args[i] = eval(v, env)
		end
		local impl = impls[self.op]
		return impl(env, unpack(args))
	elseif type(self) == "string" then
		return env[self] or 0
	elseif type(self) == "number" then
		return self
	else
		return 0
	end
end

e.eval = eval
e.__call = eval

local lib = {}

function lib:globalize(env)
	env = env or _G
	for k, v in pairs(ops) do env[k] = v end
	return lib
end

for k, v in pairs(ops) do lib[k] = v end

return setmetatable(lib, {
	__call = function(s, v) return expr(v) end,
})