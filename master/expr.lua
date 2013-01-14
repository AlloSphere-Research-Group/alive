local format = string.format
local concat = table.concat

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

-- returns true if v is an expression-object:
local
function isexpr(v)
	return type(v) == "table" and getmetatable(v) == e
end	

-- pretty-print an expression (as probably almost-valid Lua code)
function e:__tostring()
	return self.tostring and self:tostring() or format("%s(%s)", self.op, concats(self, ","))
end

function e.serialize(v)
	if isexpr(v) then
		local r = {}
		for i, v in ipairs(t) do r[i] = e.serialize(v) end
		format("%s(%s)", capitalize(self.op), concat(r, ","))
	else
		return format("%q", v)
	end
end

-- calling an expr object evaluates it
function e:__call(env)
	env = env or _G
	local args = {}
	for i, v in ipairs(self) do
		if isexpr(v) or type(v) == "function" then
			args[i] = v(env)
		else
			args[i] = v
		end
	end
	return self.impl(env, unpack(args))
end

-- standard constructor for a constant-expression-object:
function e.number(v)
	return setmetatable({ op="number", impl=function(env, n) return tonumber(n) end, v }, e)
end

-- standard constructor for a variable-expression-object:
function e.var(name)
	return setmetatable({ op="var", impl=function(env, name) return env[name] end, name }, e)
end

-- evaluate an expr:
local 
function eval(v, env)
	env = env or _G
	if isexpr(v) then
		return v(env)
	elseif type(v) == "function" then
		return v(env)
	else
		return v
	end
end

-- coercing constructor, turns Lua numbers/strings into constants/vars, 
-- passes existing expressions through
-- errors on anything else
local 
function expr(v)
	if type(v) == "number" then
		return e.number(v)
	elseif type(v) == "string" then
		return e.var(v)
	elseif isexpr(v) then
		return v
	else
		error(format("bad type %s for expr", type(v)))
	end
end

-- utility for defining infix unary operators
local 
function unop(op, impl)
	local unop_tostring = function(self)
		return format("(%s%s)", 
			self.op, 
			tostring(self[1])
		)
	end
	return function(a, b)
		return setmetatable({ 
			op=op, 
			impl=impl, 
			format="unop",
			tostring = unop_tostring,
			expr(a),
		}, e)
	end
end

-- utility for defining infix binary operators
local 
function binop(op, impl)
	local binop_tostring = function(self)
		return format("(%s %s %s)", 
			tostring(self[1]), 
			self.op, 
			tostring(self[2])
		)
	end
	return function(a, b)
		return setmetatable({ 
			op=op, 
			impl=impl, 
			format="binop",
			tostring = binop_tostring,
			expr(a), expr(b) 
		}, e)
	end
end

-- define all metamethod operators:
e.__unm = unop("-", function(env, a) return -a end)
e.__add = binop("+", function(env, a, b) return a + b end)
e.__sub = binop("-", function(env, a, b) return a - b end)
e.__mul = binop("*", function(env, a, b) return a * b end)
e.__div = binop("/", function(env, a, b) return a / b end)
e.__pow = binop("^", function(env, a, b) return a ^ b end)
e.__mod = binop("%", function(env, a, b) return a % b end)

-- define a new operator (using function call syntax)
-- if op is a table, then all key-value pairs are defined (recursive)
-- else impl should nominally be a Lua function to map to the op name
-- (but if impl is a table, the table is indexed to find the function)
local 
function define(op, impl)
	if type(op) == "table" then
		-- install a whole library:
		for k, v in pairs(op) do define(k, v) end
	else
		-- install a single operator:
		local lib
		if type(impl) == "table" then 
			impl = impl[op] 
		end
		local eimpl = function(env, ...) return impl(...) end
		local expr_constructor = function(...)
			return setmetatable({ 
				op=op, 
				impl=eimpl,
				lib=lib, 
				... 
			}, e)
		end
		-- this new expr-constructor is stored in expr itself
		-- (that also means it can be used as a method)
		e[op] = expr_constructor
	end
end

-- standard math:
local function define_from_mathlib(op) return define(op, math) end
define_from_mathlib("abs")
define_from_mathlib("acos")
define_from_mathlib("asin")
define_from_mathlib("atan")
define_from_mathlib("atan2")
define_from_mathlib("ceil")
define_from_mathlib("cos")
define_from_mathlib("cosh")
define_from_mathlib("deg")
define_from_mathlib("exp")
define_from_mathlib("floor")
define_from_mathlib("fmod")
define_from_mathlib("frexp")
define_from_mathlib("ldexp")
define_from_mathlib("log")
define_from_mathlib("log10")
define_from_mathlib("max")
define_from_mathlib("min")
define_from_mathlib("modf")
define_from_mathlib("pow")
define_from_mathlib("rad")
define_from_mathlib("random")
define_from_mathlib("sin")
define_from_mathlib("sinh")
define_from_mathlib("sqrt")
define_from_mathlib("tan")
define_from_mathlib("tanh")

-- boolean operations:
define("bool", function(env, a) return a ~= 0 and 1 or 0 end)
define("not", function(env, a) return a ~= 0 and 0 or 1 end)
define("eq", function(env, a, b) return a == b end)
define("neq", function(env, a, b) return a ~= b end)
define("gt", function(env, a, b) return a > b end)
define("gte", function(env, a, b) return a >= b end)
define("lt", function(env, a, b) return a < b end)
define("lte", function(env, a, b) return a <= b end)

-- some extended math:
define("sign", function(env, a) 
	return a > 0 and 1 or (a < 0 and -1 or 0) 
end)
define("mean", function(env, ...) 
	local n = select('#', ...)
	local sum = 0
	for i = 1, n do sum = sum + select(i, ...) end
	return sum/n
end)
define("clip", function(env, a, min, max) 
	return a < min and min or (a > max and max or a) 
end)
define("mix", function(env, a, b, t) 
	return a + t * (b-a) 
end)

-- aliases:
e.clamp = e.clip
e.linear = e.mix
	
-- also create aliases for metamethods:
e.add = e.__add
e.sub = e.__sub
e.mul = e.__mul
e.div = e.__div
e.mod = e.__mod
e.pow = e.__pow
e.unm = e.__unm

-- install all the e.* operators as global functions
-- the names are Capitalized to show that they are constructors
local
function globalize(self)
	local t = _G
	for k, v in pairs(e) do
		local firstchar = k:sub(1,1)
		if firstchar ~= "_" and type(v) == "function" then
			local propername = firstchar:upper() .. k:sub(2)
			--print("installing", propername)
			t[propername] = v
		end
	end
	-- return for convenience
	return self
end

-- convert an expr to a string of Lua code
local
function tolua(ctx, v)
	--print("tolua", v)
	if isexpr(v) then
		-- special case of constants:
		if v.op == "number" then 
			return tostring(v[1]) 
		elseif v.op == "var" then
			local name = v[1]
			ctx.stats[#ctx.stats+1] = format("local %s = %s", name, name)
			return name
		end
		-- general case creates a local:
		local rhs
		local args = {}
		for i, a in ipairs(v) do 
			args[i] = tolua(ctx, a)
		end
		if v.format == "unop" then
			rhs = format("%s%s", v.op, args[1])		
		elseif v.format == "binop" then
			rhs = format("%s %s %s", args[1], v.op, args[2])
		else
			-- default format:
			rhs = format("%s(%s)", v.op, concat(args, ","))
		end
		ctx.id = ctx.id + 1
		local name = format("v%d", ctx.id)
		ctx.stats[#ctx.stats+1] = format("local %s = %s", name, rhs)
		return name
	elseif type(v) == "string" then
		return format("%q", v)
	else
		return tostring(v)
	end
end

local lua_template = [[
$init
return function(env, dt)
	$stats
end
]]
local
function lua(v)
	local ctx = {
		id = 0,
		init = {},
		stats = {},
	}
	local r = format("return %s", tolua(ctx, v))
	ctx.stats[#ctx.stats+1] = r
	ctx.stats = concat(ctx.stats, "\n\t")
	ctx.init = concat(ctx.init, "\n")
	local code = lua_template:gsub("%$(%w+)", ctx)
	return code
end

-- walks the expr tree and converts expressions with constant arguments 
-- into the evaluated constant result
-- TODO: mark some operators as stateful / not-foldable, e.g. Random
local
function constantfold(self)
	local args = {}
	local isconstant = true
	for i, v in ipairs(self) do
		if type(v) == "table" then
			self[i] = constantfold(v)
		end
		if type(v) ~= "number" then
			isconstant = false
		end
	end
	if isconstant then
		return self.impl(unpack(self))
	else
		return self
	end
end

-- return the Lua module with useful methods
-- e.g. E = require("expr"); E:globalize()
-- make the module callable. calling the module creates a new expression-object
-- e.g. E = require("expr"); local e42 = E(42)
return setmetatable({
	globalize = globalize,
	define = define,
	constantfold = constantfold,
	lua = lua,
	isexpr = isexpr,
	eval = eval,
},{
	__call = function(mod, v) return expr(v) end,
})

