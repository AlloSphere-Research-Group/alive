--[[

Given a template, generate a generator.

Graham Wakefield 2012
grrrwaaa@gmail.com

MIT/BSD/whatever-you-like type license, i.e. use it but don't hold me liable... you could let me know if you have any good insights, I'd like that.

--]]

local concat = table.concat
local format = string.format

-- util:
local 
function tree_dump_helper(t, p, strlimit)
	if type(t) == "table" then
		local terms = { "{" }
		local p1 = p .. "  "
		for k, v in pairs(t) do
			terms[#terms+1] = format("[%q] = %s,", k, tree_dump_helper(v, p1, strlimit-2))
		end
		return format("%s\n%s}", concat(terms, "\n"..p1), p)
	elseif type(t) == "number" then
		return tostring(t)
	elseif type(t) == "string" and #t > strlimit then
		return format("%q...", t:sub(1, strlimit))
	else
		return format("%q", t)
	end
end

local 
function tree_dump(t, strlimit)
	print(tree_dump_helper(t, "", strlimit and strlimit or 80))
end

--------------------------------------------------------------------------------
-- Template grammar
--------------------------------------------------------------------------------

local lpeg = require "lpeg"
local P = lpeg.P
local C = lpeg.C
local Carg = lpeg.Carg
local Cc = lpeg.Cc
local Cg = lpeg.Cg
local Ct = lpeg.Ct
local Cp = lpeg.Cp
local V = lpeg.V

-- Basic patterns:

local function delimited(patt)
	return patt * C((1-patt)^0) * patt
end

-- numerics:
local digit = lpeg.R("09")
local integer = digit^1
local quoted_integer	= P'"' * C(integer) * P'"'

-- optional white space:
local _ = (lpeg.S" \t")^0

-- pure alphabetic words:
local alpha = lpeg.R"az" + lpeg.R"AZ"
local symbol = alpha * (alpha)^0

local literal = delimited(P"'") + delimited(P'"')

-- typical C-like variable names:
local name = (alpha + P"_") * (alpha + integer + P"_")^0

-- the patten to pick up the global state:
local g = Carg(1)

-- Rule actions:

-- any: just an inert string
--local any_action = function(s) return format("%q", s) end
local function action_anything(s)
	--print(format("write: %q", s))
	print("write ...")
end

local function action_substitute(s, ...)
	print("write:", s, ...)
	return s
end

local function eval_path(t)
	--print("action_path", t and unpack(t))
	if t then	
		local terms = {}
		for i = 1, #t do
			local v = t[i]
			if type(v) == "number" then
				terms[i] = format("[%d]", v)
			else
				terms[i] = format("[%q]", v)
			end
		end
		return concat(terms)
	else
		return ""	-- empty path
	end
end

local function action_path(t)
	return "env" .. eval_path(t)
end

local function action_index0(s, ...)
	return "i-1"
end

local function action_index1(s, ...)
	return "i"
end

local function action_len(t, ...)
	--print("action_len", t, ...)
	return "#" .. action_path(t)
end

local function action_rule_static(env, rule, ...)
	local call = format("%s(%s)", rule, env)
	print(call, ...)
	return call
end

local function action_rule_inline(env, body, ...)
	local call = format("inline(%s, %s)", env, body)
	print(call, ...)
	return call
end

local function action_rule_dynamic(env, rulepath, ...)
	local rule = action_path(rulepath)
	local call = format("evalrule(%s)(%s)", rule, env)
	print(call, ...)
	return call
end

local function action_map_static(env, rule, ...)
	local call = format("map(%s, %s)", rule, env)
	print("action_map_static", call, ...)
	return call
end

local function action_map_inline(env, body)
	local call = format("map(inline(%s), %s)", env, body)
	print("action_map_inline", call)
	return call
end

local function action_map_dynamic(env, rulepath, ...)
	local rule = action_path(rulepath)
	local call = format("map(evalrule(%s), (%s)", rule, env)
	print("action_map_dynamic", call, ...)
	return call
end

local function action_dynamic_env(t)
	assert(#t > 0, "error: dynamic environment needs at least one element")
	local terms = {}
	for i = 1, #t do
		local v = t[i]
		if type(v) == "table" then
			terms[i] = format("%s = %s", unpack(v))
		else
			terms[i] = v
		end
	end
	local env = format("{ %s }", concat(terms, ", "))
	--print("action_dynamic_env", env)
	return env
end

local function action_if(c, t, f, ...)
	print("action_if", c, t, f, ...)
end

local function action_element(t)
	--print("action_element", unpack(t))
	--for i, v in ipairs(t) do print(i, v) end
	return format("%q", t)
end

local function action_elements(t)
	--print("action_element", unpack(t))
	--for i, v in ipairs(t) do print(i, v) end
	return concat(t, ", ")
end

local function action_compare(a, op, b, ...)
	local call = format("(%s %s %s)", a, op, b)
	--print("action_compare", call, ...)
	return call
end

local function action_exists_rule(rule, ...)
	local call = format("exists_rule(%s)", rule)
	return call
end

local function action_exists(str)
	local call = format("%s ~= nil", str)
	return call
end

local function Rule(patt, name)
	return Ct(
		--Cg(Cp(), "start") *
		patt *
		--Cg(Cp(), "finish") *
		Cg(Cc(name), "rule")
	)
end

local inlined_element	= (V"rule" + Rule(C((P(1) - (P"}}" + V"rule"))^1), "inline_text")) --/action_element)
local inlined			= P"{{" * Rule(inlined_element^0, "inline") * P"}}" --/ action_elements

local pathterm			= C(name) + (integer / tonumber)

local path				= Rule(
							  (C".") 
							+ (pathterm * (P"." * pathterm)^0),
							"path"
						)

local dollar_rule_body  = Rule(P"i0", "i0") --/ action_index0
						+ Rule(P"i1", "i1") --/ action_index1
						+ Rule(P"#" * path, "len") --/ action_len
						+ path --/ action_path

local dollar_rule		= Rule(
							  (P"$<" * dollar_rule_body --[[/ action_substitute--]] * P">")
							+ (P"$" * dollar_rule_body --[[/ action_substitute--]] ),
							"substitute"
						)

local denv_term_value	= V"rule_body_env"
						+ Rule(literal, "literal") --/ action_element
						+ dollar_rule_body

local denv_term			= Rule(C(name) *_* P"=" *_* denv_term_value, "tuple")
						+ denv_term_value
						
local denv_term_list	= (denv_term * (_* P"," *_* denv_term)^0)

local dynamic_env		= Rule(P"{" *_* denv_term_list *_* P"}", "dynamic_env") --/ action_dynamic_env

local rule_env			= (dynamic_env * P":")
						+ ((path --[[/ action_path--]]) * P":")
		
local rule_no_env		= Rule(C"." + Cc".", "path") --(Cc(nil) / action_path)

local dynamic_rule		= P"(" * path * P")"

local rule_body_env		= Rule(rule_env * dynamic_rule, "dynamic_rule") --/ action_rule_dynamic
						+ Rule(rule_env * inlined, "inline_rule") --/ action_rule_inline
						+ Rule(rule_env * C(name), "static_rule") --/ action_rule_static

local rule_body_no_env	= Rule(rule_no_env * dynamic_rule, "dynamic_rule") --/ action_rule_dynamic
						+ Rule(rule_no_env * inlined, "inline_rule") --/ action_rule_inline
						+ Rule(rule_no_env * C(name), "static_rule") --/ action_rule_static
						
local at_rule_body		= rule_body_env + rule_body_no_env

local compare_op		= P"==" + P"~=" + P"!=" + P">=" + P"<=" + lpeg.S"<>"

local compare_arg		= Rule(quoted_integer, "quoted") + dollar_rule_body

local compare			= Rule(compare_arg *_* C(compare_op) *_* compare_arg, "compare")
						--/ action_compare
						
local exists_rule		= Rule(P"?" * (P"(" * path --[[/ action_path--]] * P")"), "exists_rule")
						--/ action_exists_rule
						
local exists			= Rule(P"?" * path, "exists") --/ action_path
						--/ action_exists

local cond				= exists_rule
						+ exists
						+ compare
						+ Rule(path, "exists") --/ action_path
						
local at_if				= P"@if(" * cond * P")<" * rule_body_no_env * P">" 
						* (P"else<" * rule_body_no_env * P">")^-1
						--/ action_if

local at_iter_type		= C"map" + C"rest"

local at_iter_env		= dynamic_env * P":"

local at_iter			= Rule(at_iter_env * dynamic_rule, "iter_dynamic") --/ action_map_dynamic
						+ Rule(at_iter_env * inlined, "iter_inline") --/ action_map_inline
						+ Rule(at_iter_env * C(name), "iter_static") --/ action_map_static

local at_rule			= Rule(at_if, "if")
						+ Rule(P"@" * at_iter_type * at_iter, "iter")
						+ Rule(P"@<" * at_rule_body * P">", "rule")
						+ Rule(P"@" * at_rule_body, "rule")

local rule				= at_rule + dollar_rule

local anything			= Rule(C((P(1) - V"rule")^1), "anything")

local term				= (rule + anything)

-- the final grammar:
local grammar = P{
	-- start symbol (grammar entry point):
	Rule(term^0, "main"),
	
	-- ordered set of rules to match for:
	-- generally anything starting with @ or $:
	rule = rule,
	
	rule_body_env = rule_body_env,
}

--------------------------------------------------------------------------------
-- Unparser
-- useful for parser debugging: reconstructs the template from the tree
-- it also helpfully details the required actions of the generator
--------------------------------------------------------------------------------

local unparse = {}
local write = io.write

function unparse:dispatch(t)
	if type(t) == "table" then
		assert(t.rule, "missing rule")
		local f = self[t.rule]
		if not f then
			tree_dump(t)
			error("no handler for "..t.rule)
		end
		return f(self, t)
	else
		return t
	end
end

function unparse:main(t)
	for i, v in ipairs(t) do
		write(self:dispatch(v))
	end
	write("\n")
end

function unparse:path(t)
	return concat(t, ".")
end

function unparse:i0(t)
	return "i0"
end

function unparse:i1(t)
	return "i1"
end

function unparse:len(t)
	local v = self:dispatch(t[1])
	return "#" .. v
end

function unparse:substitute(t)
	local v = self:dispatch(t[1])
	return "$<" .. v .. ">"
end

function unparse:rule(t)
	local v = self:dispatch(t[1])
	return "@<" .. v .. ">"
end

function unparse:static_rule(t)
	local env = self:dispatch(t[1])
	local rule = self:dispatch(t[2])
	return env .. ":" .. rule
end

function unparse:dynamic_rule(t)
	local env = self:dispatch(t[1])
	local rule = self:dispatch(t[2])
	return env .. ":(" .. rule .. ")"
end

function unparse:inline_rule(t)
	local env = self:dispatch(t[1])
	local rule = self:dispatch(t[2])
	return env .. ":{{" .. rule .. "}}"
end

function unparse:inline(t)
	local terms = {}
	for i, v in ipairs(t) do
		terms[#terms+1] = self:dispatch(v)
	end
	return concat(terms)
end

function unparse:inline_text(t)
	return t[1]
end

function unparse:dynamic_env(t)
	local terms = {}
	for i, v in ipairs(t) do
		terms[#terms+1] = self:dispatch(v)
	end
	return "{ " .. concat(terms, ", ") .. " }"
end

function unparse:tuple(t)
	local k = self:dispatch(t[1])
	local v = self:dispatch(t[2])
	return k .. "=" .. v
end

unparse["if"] = function (self, t)
	local cond = self:dispatch(t[1])
	local a = self:dispatch(t[2])
	local s = "@if("..cond..")<"..a..">"
	if #t == 3 then
		local b = self:dispatch(t[3])
		s = s .. "else<" .. b .. ">"
	end
	return s
end

function unparse:exists(t)
	local k = self:dispatch(t[1])
	return "?" .. k
end

function unparse:exists_rule(t)
	local k = self:dispatch(t[1])
	return "?(" .. k .. ")"
end

function unparse:compare(t)
	local a = self:dispatch(t[1])
	local op = self:dispatch(t[2])
	local b = self:dispatch(t[3])
	return a .. " " .. op .. " " .. b
end

function unparse:iter(t)
	local ty = self:dispatch(t[1])
	local v = self:dispatch(t[2])
	return "@" .. ty .. v
end

function unparse:iter_static(t)
	local env = self:dispatch(t[1])
	local rule = self:dispatch(t[2])
	return env .. ":" .. rule
end

function unparse:iter_dynamic(t)
	local env = self:dispatch(t[1])
	local rule = self:dispatch(t[2])
	return env .. ":(" .. rule .. ")"
end

function unparse:iter_inline(t)
	local env = self:dispatch(t[1])
	local rule = self:dispatch(t[2])
	return env .. ":{{" .. rule .. "}}"
end

function unparse:quoted(t)
	return format("%q", t[1])
end

function unparse:literal(t)
	return format("%q", t[1])
end

function unparse:anything(t)
	return t[1]
end

--------------------------------------------------------------------------------
-- Generator
--------------------------------------------------------------------------------

local generator = {}
local write = io.write

function generator:dispatch(t)
	if type(t) == "table" then
		assert(t.rule, "missing rule")
		assert(self[t.rule], "bad action")
		return self[t.rule](self, t)
	else
		return t
	end
end

function generator:main(t)
	local terms = {[[
return function(env, write)
local rules = {}
local envmake = function() end	
	]]}
	for i, v in ipairs(t) do
		terms[#terms+1] = format("%s", self:dispatch(v))
	end
	return concat(terms, "\n") .. "\nend"
end

function generator:path(t)
	--tree_dump(t)
	if #t == 1 and t[1] == "." then
		return "env"
	end
	
	local terms = {}
	for i, v in ipairs(t) do
		if type(v) == "number" then
			terms[i] = format("[%d]", v)
		else
			terms[i] = format("[%q]", v)
		end
	end
	return format("env%s", concat(terms))
end

function generator:i0(t)
	return "i-1"
end

function generator:i1(t)
	return "i"
end

function generator:len(t)
	local v = self:dispatch(t[1])
	return "#" .. v
end

function generator:substitute(t)
	local v = self:dispatch(t[1])
	return format("write(%s)", v)
end

function generator:rule(t)
	local v = self:dispatch(t[1])
	return v
end

function generator:static_rule(t)
	local env = self:dispatch(t[1])
	local rule = self:dispatch(t[2])
	return format("rule_%s(%s)", rule, env)
end

function generator:dynamic_rule(t)
	local env = self:dispatch(t[1])
	local rule = self:dispatch(t[2])
	return format("rules[%s](%s)", rule, env)
end

function generator:inline_rule(t)
	local env = self:dispatch(t[1])
	local rule = self:dispatch(t[2])
	return format("do\n\tlocal env=%s\n\twrite(%s)\nend", env, rule)
end

function generator:inline(t)
	--tree_dump(t)
	local terms = {}
	for i, v in ipairs(t) do
		terms[#terms+1] = self:dispatch(v)
	end
	return concat(terms, ", ")
end

function generator:inline_text(t)
	return format("%q", t[1])
end

function generator:dynamic_env(t)
	local terms = {}
	for i = 1, #t do
		local v = t[i]
		terms[#terms+1] = self:dispatch(v)
	end
	return "envmake({ i=i, " .. concat(terms, ", ") .. " }, env)"
end

function generator:tuple(t)
	local k = self:dispatch(t[1])
	local v = self:dispatch(t[2])
	return k .. "=" .. v
end

generator["if"] = function (self, t)
	local cond = self:dispatch(t[1])
	local a = self:dispatch(t[2])
	local b = ""
	if #t == 3 then
		b = self:dispatch(t[3])
	end
	return format("if %s then\n\t%s\nelse\n\t%s\nend", cond, a, b)
end

function generator:exists(t)
	local k = self:dispatch(t[1])
	return format("%s ~= nil", k)
end

function generator:exists_rule(t)
	local k = self:dispatch(t[1])
	return format("rules[%s] ~= nil", k)
end

function generator:compare(t)
	local a = self:dispatch(t[1])
	local op = self:dispatch(t[2])
	local b = self:dispatch(t[3])
	return a .. " " .. op .. " " .. b
end

-- TODO: utilize _separator:
function generator:iter(t)
	local ty = self:dispatch(t[1])
	local v = self:dispatch(t[2])
	--return "@" .. ty .. v
	local start, finish = "1", "#env"
	if ty == "rest" then start = "2" end
	return format("for i=%s, %s do\n\t%s\nend", start, finish, v)
end

function generator:iter_static(t)
	return self:static_rule(t)
end

function generator:iter_dynamic(t)
	return self:dynamic_rule(t)
end

function generator:iter_inline(t)
	return self:inline_rule(t)
end

function generator:quoted(t)
	return t[1]
end

function generator:literal(t)
	return format("%q", t[1])
end

function generator:anything(t)
	return format("write(%q)", t[1])
end

--------------------------------------------------------------------------------
-- Parser
--------------------------------------------------------------------------------

local parser = {}
parser.__index = parser

function parser.create()
	return setmetatable({
	
	}, parser)
end

function parser:parse(src)
	local tree = grammar:match(src, 1, self)
	--tree_dump(tree)
	--unparse:dispatch(tree)
	local code = generator:dispatch(tree)
	return tree, code
end

--------------------------------------------------------------------------------
-- Generator generator
--------------------------------------------------------------------------------

-- the broad structure of the generated code looks like this:
local generator_template = [[
-- this is code-generator generated code:
local tconcat = table.concat
local format = string.format
local function concat(t)
	if type(t) == "table" then
		for i = 1, #t do t[i] = concat(t[i]) end
		return tconcat(t, t._separator or "")
	end
	return tostring(t)
end
local function map(env, rule, sep)
	if type(env) == "table" then
		local res = { _separator = sep }
		for i = 1, #env do
			res[i] = rule(env[i])
		end
		return res
	else
		error(format("expected table, got %%s, for rule %%s", tostring(env), tostring(rule)))
	end
end

%s
return function(env)
	return concat{ 
		%s 
	}
end
]]

local rule_template = [[
local function rule_%s_name(write, env)
	%s
end
]]

local function gen(template)

	local p = parser.create()
	local tree, code = p:parse(template[1])

	print(code)

	-- turn it into a function:
	local f, err = loadstring(code)
	if not f then
		print("error loading", code)
		print(err)
	end	
	f = f()
	if not f then
		print("error loading", code)
		print(err)
	end	
	return f, code
end


return gen