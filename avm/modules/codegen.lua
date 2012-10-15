--[[

Given a template, generate a code generator.

Graham Wakefield 2012
grrrwaaa@gmail.com

MIT/BSD/whatever-you-like type license, i.e. use it but don't hold me liable... you could let me know if you have any good insights, I'd like that.

--]]

local lpeg = require "lpeg"
local concat = table.concat
local format = string.format

local P = lpeg.P
local C = lpeg.C
local Carg = lpeg.Carg
local Ct = lpeg.Ct
local V = lpeg.V

-- fwd declaration:
local gen_rule

---- PARSING THE TEMPLATES ----

-- basic patterns:

-- numerics:
local digit = lpeg.R("09")
local integer = digit^1

-- pure alphabetic words:
local alpha = lpeg.R"az" + lpeg.R"AZ"
local symbol = alpha * (alpha)^0

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

-- $sterm: look up the corresponding dictionary field in the env:
local sterm_action = function(s)
	return format("env[%q] or ''", s)
end

-- @invoke: look up another template rule:
local invoke_action = function(s, g)
	-- find the rule to be invoked:
	local rule = g.rules[s]
	-- generate rules lazily.
	-- only the used rules are generated
	if not rule then
		-- a temporary rule to detect recursion:
		g.rules[s] = 'error("template would cause an infinite loop")'
		local t = g.template[s]
		if t then
			-- create rule
			rule = gen_rule(s, t, g)
			-- store the rule:
			g.rules[s] = rule
		else
			g.rules[s] = nil -- (remove the recursion trap)
			error("could not resolve rule @" .. s)
		end
	end
	-- now use rule:
	return rule
end

-- ?foo
local function exists_action(s)
	return format("env[%q] ~= nil", s)
end

-- @if(c)<t>else<f>
-- generates a tertiary conditional expression:
local function cond_action(c, t, f)
	if f then
		return format("(%s) and (%s) or (%s)", c, t, f)
	else
		return format("(%s) and (%s) or ''", c, t, f)
	end
end

local function apply_action(sub, rule, g)
	local env = format("env[%q]", sub)
	return format("%s(%s)", rule, env)
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

-- e.g. $1
local sub_iterm = P"$" * C(integer) / iterm_action
-- e.g. $<1>
local sub_itermq = P"$<" * C(integer) * P">" / iterm_action

-- e.g. $abcd (no numbers, underscores etc.)
local sub_sterm = P"$" * C(symbol) / sterm_action
-- e.g. $<abc_d1> (underscores, numbers etc. ok)
local sub_stermq = P"$<" * C(name) * P">" / sterm_action

-- e.g. @bar:foo
local at_apply = P"@" * C(symbol) * P":" * C(symbol) * g / apply_action

-- e.g. @foo
local invoke_name = (C(symbol) * g / invoke_action)
local at_invoke = P"@" * invoke_name
local at_invokeq = P"@<" * invoke_name * P">"

-- apart from raw Lua, what kinds of conditions can we put here?
local cond_exists = P"?" * C(symbol) / exists_action
				  + P"?(" * C(symbol) / exists_action * P")"
local cond = cond_exists + C(P"true" + P"false")

-- rule name or {{inline}} format:
local inline_element = V"rule" + ((1 - (P"}}" + V"rule"))^1) / any_action
local inline = P"{{" * (inline_element^1) / list_action * P"}}"

local cond_body = inline + invoke_name

-- e.g. @if(true)<@foo>else<@bar>
local at_cond = P"@if(" * cond * P")<" * cond_body * P">"
			* (P"else<" * cond_body * P">")^-1 / cond_action

-- the final grammar:
local grammar = P{
	-- start symbol (grammar entry point):
	(V"rule" + any)^1,
	
	-- ordered set of rules to match for:
	-- generally anything starting with @ or $:
	rule = at_apply
		 + at_cond 
		 + at_invokeq + at_invoke 
		 + sub_itermq + sub_stermq 
		 + sub_iterm + sub_sterm,
}

---- GENERATING THE GENERATOR ----

-- the broad structure of the generated code looks like this:
local generator_template = [[
-- this is code-generator generated code:
local function concat(t)
	if type(t) == "table" then
		for i = 1, #t do t[i] = concat(t[i]) end
		return table.concat(t)
	end
	return tostring(t)
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

function gen_rule(name, t, g)
	-- debug: print("generating rule for:", name)
	local str = t
	-- parsing the template results in a list of actions:
	local terms = { grammar:match(str, 1, g) }
	-- convert this into Lua code:
	local fst = format(subrule_template, name, concat(terms, ",\n\t\t"))
	-- debug: print(fst)
	-- store in rules:
	g.rules[name] = fst			-- for easy lookup
	g.rules[#g.rules+1] = fst	-- for ordered-ness
	-- rule becomes a simple invocation of the generated function:
	return format("%s(env)", name)
end

local 
function gen(t)
	-- accept plain strings too:
	if type(t) == "string" then
		local t = { t }
	end

	local str = t[1]
	local g = {
		rules = {},
		template = t,
	}
	-- parsing the template results in a list of actions:
	local terms = { grammar:match(str, 1, g) }
	-- convert this into Lua code:
	local fst = format(generator_template, concat(g.rules, "\n"), concat(terms, ", \n\t\t"))
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

---- EXAMPLES ----

local template = {
	hello = [[$quality]],
	subject = [[@hello $1]],
	[["@subject" says a @hello goodbye
		@if(?(quality))<hello>
		@if(true)<hello>else<subject>
		@if(false)<hello>else<{{@subject foo}}>
		@friend:subject says it too
	]],
}

-- an example env to work from:
local dict = { 
	"tom",
	quality = "peeping",
	friend = {
		"jack",
		quality = "nimble",
	}	
}

print(gen(template)(dict))
