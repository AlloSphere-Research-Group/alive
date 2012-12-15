--[[

Given a template, generate a code generator.

Graham Wakefield 2012
grrrwaaa@gmail.com

MIT/BSD/whatever-you-like type license, i.e. use it but don't hold me liable... you could let me know if you have any good insights, I'd like that.

--]]

local concat = table.concat
local format = string.format

-- util:
local 
function tree_dump_helper(t, p)
	if type(t) == "table" then
		local terms = { "{" }
		local p1 = p .. "  "
		for k, v in pairs(t) do
			terms[#terms+1] = format("[%q] = %s,", k, tree_dump_helper(v, p1))
		end
		return format("%s\n%s}", concat(terms, "\n"..p1), p)
	else
		return format("%q", t)
	end
end

local 
function tree_dump(t, p)
	print(tree_dump_helper(t, ""))
end

local lpeg = require "lpeg"
local P = lpeg.P
local C = lpeg.C
local Carg = lpeg.Carg
local Cc = lpeg.Cc
local Ct = lpeg.Ct
local Cp = lpeg.Cp
local V = lpeg.V

local function delimited(patt)
	return patt * C((1-patt)^0) * patt
end

-- fwd declaration:
local gen_rule

---- PARSING THE TEMPLATES ----

-- basic patterns:

-- numerics:
local digit = lpeg.R("09")
local integer = digit^1

-- optional white space:
local _ = (lpeg.S" \t")^0

-- pure alphabetic words:
local alpha = lpeg.R"az" + lpeg.R"AZ"
local symbol = alpha * (alpha)^0

local literal = delimited(P"'") + delimited(P'"')

-- typical C-like variable names:
local name = (alpha + P"_") * (alpha + integer + P"_")^0

-- inline template syntax:
local function inlined(patt)
	return P"{{" * C((patt-P"}}")^0) * P"}}"
end

-- the patten to pick up the global state:
local g = Carg(1)

-- rule actions:

local list_action = function(...)
	return format("{ %s }", concat({...}, ", "))
end

-- $iterm: look up the corresponding array field in the env:
local iterm_action = function(id)
	return format("env[%d] or ''", id)
end

local kterm_n_action = function(s)
	return format("#env[%q]", s)
end

local 
function terms_to_string(arg)
	local ty = type(arg)
	if ty == "table" then
		local terms = {}
		for i, v in ipairs(arg) do
			terms[i] = terms_to_string(v)
		end
		return concat(terms)
	elseif ty == "number" then
		return format("[%d]", arg)
	elseif ty == "string" then
		return format("[%q]", arg)
	elseif ty == "nil" then
		return ""
	else
		error("unexpected term type " .. type(v))
	end
end

-- $sterm: look up the corresponding dictionary field in the env:
local kterm_action = function(args)
	local env = terms_to_string(args)
	return format("env%s or ''", env)
end

-- find a rule for a given name:
local function find_rule(s, g)
	print("find_rule", s, g)
	-- find the rule to be invoked:
	local rule
	-- is there a local template?
	local t = g.template[s]
	if t then
		print("found template")
		-- is there a local rule defined?
		rule = g.rules[s]
		if not rule then
			print("generate rule", s)
			-- a temporary rule to detect recursion:
			-- TODO: handle this error at gen-time rather than run-time?
			g.rules[s] = 'error("template would cause an infinite loop")'
			-- generate the local rule
			rule = gen_rule(s, t, g)
		end
	elseif g.parent then
		-- look for the rule recursively:
		rule = find_rule(s, g.parent)
	else
		error("could not locate rule @" .. s)
	end
	return rule
end

-- if sub is nil or ".", then just use the current env:
local function apply_action(start, env, rule, g, finish)
	print("apply_action", g.src:sub(start, finish))
	local env = terms_to_string(env)
	return format("%s(env%s)", find_rule(rule, g), env)
end

-- ?foo
local function exists_action(s)
	return format("env[%q] ~= nil", s)
end

-- @if(c)<t>else<f>
-- generates a tertiary conditional expression:
local function cond_action(c, t, f)
	-- TODO: should this be separated out as a proper if .. then block?
	if f then
		return format("(%s) and (%s) or (%s)", c, t, f)
	else
		return format("(%s) and (%s) or ''", c, t, f)
	end
end

-- @rule:subenv
-- @rule:{{inline pattern}}
-- @map
-- @if(cond)<rule>else<rule>
-- ?exists
-- !exists (assert non-empty)

-- any: just an inert string
local any_action = function(s)
	return format("%q", s)
end

-- rule patterns:

-- any non-rule match just returns the quoted string:
local any = ((P(1) - V"rule")^1) / any_action

local index_item = C(name) + (integer / tonumber)
local index_chain = Ct(index_item * (P"." * index_item)^0)

-- e.g. $<1>
-- e.g. $10
local sub_iterm = (
				     (P"$<" * C(integer) * P">")
				   + (P"$" * C(integer))
				  ) / iterm_action

-- e.g. $params.n
-- e.g. $<params.n>
local sub_kterm_n = (
				     (P"$<" * C(name) * P">")
				   + (P"$" * C(symbol))
				  ) * P".n" / kterm_n_action

-- e.g. $abcd (no numbers, underscores etc.)
-- e.g. $<abc_d1> (underscores, numbers etc. ok)
local sub_kterm = (
				     (P"$<" * index_chain * P">")
				   + (P"$" * index_chain)
				  ) / kterm_action
				  
-- e.g. $foo.bar.baz => env["foo"]["bar"]["baz"]
-- e.g. $foo.1.thing => env["foo"][1]["thing"]
-- e.g. $foo.1.n => #env["foo"][1]

--...

-- e.g. bar:foo
-- e.g. .:foo
-- e.g. foo   (implicit env == ".")
local invoke_apply = (Cp() * (
						(index_chain * P":" * C(symbol)) 
					  + (P".:" * Cc(nil) * C(symbol))
					  + (Cc(nil) * C(symbol))
					 ) * g * Cp()) / apply_action

-- e.g. @<foo:bar>
-- e.g. @foo
local at_invoke = (P"@<" * invoke_apply * P">")
				+ (P"@" * invoke_apply)

-- apart from raw Lua, what kinds of conditions can we put here?
local cond_exists = P"?" * C(symbol) / exists_action
				  + P"?(" * C(symbol) / exists_action * P")"
local cond = cond_exists + C(P"true" + P"false")

-- rule name or {{inline}} format:
local inline_element = V"rule" + ((1 - (P"}}" + V"rule"))^1) / any_action
local inline = P"{{" * (inline_element^1) / list_action * P"}}"

local cond_body = inline + invoke_apply

-- e.g. @if(true)<@foo>else<@bar>
local at_cond = P"@if(" * cond * P")<" * cond_body * P">"
			* (P"else<" * cond_body * P">")^-1 / cond_action

-- e.g. @map{ iterable }:rulename
-- _separator default is empty string
local map_separator = (_ * P"," * _ * P"_separator=" * literal) + Cc""
local iterable = _ * C(name)
local at_map = P"@map{" * iterable * map_separator * _ * P"}:" * C(symbol) * g / function(sub, sep, rule, g)
	local env = format("env[%q]", sub) 
	print("looking for rule", rule, env)
	return format("map(%s, %s, %q)", env, find_rule(rule, g), sep)
end

-- the final grammar:
local grammar = P{
	-- start symbol (grammar entry point):
	(V"rule" + any)^1,
	
	-- ordered set of rules to match for:
	-- generally anything starting with @ or $:
	rule = at_cond 
	     + at_map
		 + at_invoke 
		 + sub_iterm
		 + sub_kterm_n
		 + sub_kterm,
}

---- GENERATING THE GENERATOR ----

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

local subrule_template = [[
local function %s(env)
	return { 
		%s 
	}
end
]]

-- TODO: could this be inlined/merged with find_rule?
function gen_rule(name, t, g)
	-- debug: 
	print("generating rule for:", name, t)
	local str = t
	if type(t) == "table" then 
		-- the first item in the table is the template string:
		str = t[1] 
		print(str)
		-- override the template context
		g = {
			src = str,
			parent = g,					-- for inheritance chain
			functions = g.functions,	-- i.e. global
			name = format("%s_%s", g.name, name),
			template = t,
			rules = {},
		}
		print("changed g context")
	end
	-- parsing the template results in a list of actions:
	local terms = { grammar:match(str, 1, g) }
	-- generate the namespaced name for the subroutine
	local fullname = format("%s_%s", g.name, name)
	-- generate the subroutine for this rule:
	local fst = format(subrule_template, fullname, concat(terms, ",\n\t\t"))
	-- debug: print(fst)
	-- store function:
	g.functions[#g.functions+1] = fst
	-- store this as the new rule:			
	g.rules[name] = fullname		
	return fullname
end

--[[
template["a.b.c"] = "foo" =>

{
	a = {
		b = {
			c = {
				[1] = "foo"
			}
		}
	}
}



--]]

local 
function insert_template(def, k, v)
	print("def", def, k, v)
	if type(k) == "string" then
		-- is it a dotted rule?
		local parent_name, rest = k:match("(%a+)%.(.+)")
		if parent_name then
			print("parent_name, rest", parent_name, rest)
			-- create parent rule container lazily:
			local parent = def[parent_name]
			if not parent then
				print("creating sub-rule", parent_name)
				parent = {}
				def[parent_name] = parent
			end
			insert_template(parent, rest, v)
			return
		end
	end
	if k == 1 then
		def[k] = { v }
	else
		def[k] = v
	end
end

local 
function gen(t)
	local def = {}
	tree_dump(t)
	
	-- accept plain strings too:
	if type(t) == "string" then
		def = { t }
	else		
		-- pre-process the table to deal with 
		-- template["foo.bar"] = txt ->
		-- foo = { bar = txt } } etc.
		for k, v in pairs(t) do 
			if k == "main" or k == 1 then
				def[1] = v
			else
				insert_template(def, k, v)
			end
		end
	end
	
	-- debug:
	tree_dump(def)

	local main = assert(def[1], "template has no main rule")
	local g = {
		src = main,
		name = "main",
		-- functions store the fragments of code that implement subroutines
		functions = {},
		-- rules store the fragments of code to invoke a subroutine
		rules = {},
		template = def,
	}
	
	-- parsing the template results in a list of actions:
	local terms = { grammar:match(main, 1, g) }
	-- convert this into Lua code:
	local fst = format(
		generator_template, 
		concat(g.functions, "\n"), 
		concat(terms, ", \n\t\t")
	)
	
	-- debug:
	print(string.rep("-", 80)); print(fst); print(string.rep("-", 80))
	
	-- turn it into a function:
	local f, err = loadstring(fst)
	if not f then
		print("error loading", fst)
		print(err)
	end	
	return f()
end

return gen
