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
local Cc = lpeg.Cc
local Ct = lpeg.Ct
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

local envname = P"." + name

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
local kterm_action = function(s)
	return format("env[%q] or ''", s)
end

-- find a rule for a given name:
local function find_rule(s, g)
	-- find the rule to be invoked:
	local rule
	-- is there a local template?
	local t = g.template[s]
	if t then
		-- is there a local rule defined?
		rule = g.rules[s]
		if not rule then
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
local function apply_action(sub, rule, g)
	local env 
	if sub == "." or sub == nil then
		env = "env"
	elseif type(sub) == "string" then
		env = format("env[%q]", sub) 
	else
		error("unexpected env")
	end
	return format("%s(%s)", find_rule(rule, g), env)
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

-- e.g. $<1>
-- e.g. $10
local sub_iterm = (
				     (P"$<" * C(integer) * P">")
				   + (P"$" * C(integer))
				  ) / iterm_action

-- e.g. $abcd (no numbers, underscores etc.)
-- e.g. $<abc_d1> (underscores, numbers etc. ok)
local sub_kterm = (
				     (P"$<" * C(name) * P">")
				   + (P"$" * C(symbol))
				  ) / kterm_action

-- e.g. bar:foo
-- e.g. .:foo
-- e.g. foo   (implicit env == ".")
local invoke_apply = (
						(C(envname) * P":" * C(symbol)) 
					  + (Cc"." * C(symbol))
					 ) * g / apply_action

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
	print("TODO: use separator", sep)
	local env = format("env[%q]", sub) 
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
	-- debug: print("generating rule for:", name, t)
	local str = t
	if type(t) == "table" then 
		-- the first item in the table is the template string:
		str = t[1] 
		-- override the template context
		g = {
			parent = g,					-- for inheritance chain
			functions = g.functions,	-- i.e. global
			name = format("%s_%s", g.name, name),
			template = t,
			rules = {},
		}
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

local 
function gen(t)
	-- accept plain strings too:
	if type(t) == "string" then
		local t = { t }
	else
		-- TODO: pre-process the table to deal with 
		-- template["foo.bar"] = txt ->
		-- foo = { bar = txt } } etc.
	end

	local str = t[1]
	local g = {
		name = "main",
		-- functions store the fragments of code that implement subroutines
		functions = {},
		-- rules store the fragments of code to invoke a subroutine
		rules = {},
		template = t,
	}
	
	-- parsing the template results in a list of actions:
	local terms = { grammar:match(str, 1, g) }
	-- convert this into Lua code:
	local fst = format(
		generator_template, 
		concat(g.functions, "\n"), 
		concat(terms, ", \n\t\t")
	)
	-- debug:
	--print(string.rep("-", 80)); print(fst); print(string.rep("-", 80))
	-- turn it into a function:
	local f, err = loadstring(fst)
	if not f then
		print("error loading", fst)
		print(err)
	end	
	return f()
end

--[[

local function map(env, rule)
	local res = {}
	for i = 1, #env do
		res[i] = rule(env[i])
	end
	return res
end






Scoped template rules
	Define as template["foo.bar"]  = "bar..."
		or as template = { foo = { "foo...", bar = "bar...", } } 
			(requires being able to assume a template defined as { '...' }
		or both? could normalize either to the other in a pre-process stage.

TODO:
	$params.n  -- a better syntax? 
	@args.1:expr
	@(paramtype)
	@if(length{.} > "0")<sub>
	@if(?(rule))<{{@(rule)}}>
	@map{.}:stat
	@map{., _separator=" else "}:{{@block}}
	@map{ name=ins, _separator="," }:{{"$name"}}
	@map{v=., _separator=" "}:{{$v}}
	@rest{ input=args, len=length{args}:., cond=args.1:expr }:more
	Nice indenting.
		Capture the indent at the @rule invocation?
		Capture/replace newlines in the 'any' sections?
	I realize we probably don't need to do nested concat stuff, we can 
		probably just directly write into global table
		not sure if it helps any
		
	Env inheritance: env["foo"] should be able to pick up env's parent's foo
		Tricky... env needs to become some kind of proxy object
	
	What does it mean to say $params when env.params is a table?
		(currently an assert())
	What does it mean to say @map{ params } when params' elements are strings?

KNOWN ISSUES:
	Do not have child rules with the same name as their immediate parent. 
	It will think it is a recursive definition and trigger an error.
--]]

---- EXAMPLES ----



local template = {
	[["@<subject>" says a @.:hello goodbye
		@if(?(quality))<hello>
		@if(true)<hello>else<subject>
		@if(false)<hello>else<{{@subject foo}}>
		@friend:subject says it too
		@sub
		@map{ params }:parameter
		@ map{ params, _separator=" * " }:{{ thingy $1 }}
	]],
	parameter = [[$id... ]],
	basic = {"$1"},
	hello = [[$quality]],
	subject = [[@hello $1-$<1>]],
		sub = {
		[[$quality becomes @hello for @subject
		even more: @more]],
		-- this should override the parent 'hello' rule:
		hello = "very $quality",
		more = {
			"some @hello @<basic>'s @sub",
			-- this should override the parent 'hello' rule:
			hello = "remarkable $quality",
			sub = "... have no fear",
		}
	},
}
local generator = gen(template)

-- an example env to work from:
local dict = { 
	"tom",
	quality = "peeping",
	friend = {
		"jack",
		quality = "nimble",
	},	
	params = { 
		{ id="one", },
		{ id="two", },
		{ id="three", },
	},
}

print(generator(dict))

print(map_separator:match(', _separator="foo"'))



-- TEST --
function test(s)
	local g = gen(s)
	return function(dict)
		print(g(dict))
	end
end

-- basic substitutions:

test{ "numeric $1 $2 $<3>" } 
	{ "one", "two", "three" }
	
test{ "symbolic $a $b $c $<strange_symbol>" } 
	{ a="one", b="two", c="three", strange_symbol="nice" }

-- TODO: $params.n

-- rule invocations:

-- apply rule with current context
test{ "use @foo", foo = { "sub-rule $1" }, } 
	{ "red" } 
test{ "use @<foo>", foo = { "sub-rule $1" }, } 
	{ "red" } 
test{ "use @.:foo", foo = { "sub-rule $1" }, } 
	{ "red" } 

-- apply rule with sub-context:
test{ "use @bar:foo", foo = { "sub-rule $1" }, }
	{ "red", bar = { "blue" }, }

-- special rules

-- conditional

-- iteration


