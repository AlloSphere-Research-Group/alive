local gen = require "codegen1"

--[[ 

template[1] = patt =>
local function rule_<parentname_>1(write, env)
	<results of parsing patt>
end

template[name] = patt =>
local function rule_<parentname_>name(write, env)
	<results of parsing patt>
end

(note that a template can invoke itself recursively)

(what if patt is a function?)



$.	=> write(env) ??
$i0	=> zero-based index while iterating
$i1	=> one-based index while iterating

$1 
$<1> => write(env[1])
$foo 
$<foo> => write(env["foo"])
	(if foo is not found in current env, look in parent env?)
	(the unanswered question: what if env[1] or env.foo are tables?)
$foo.bar
$<foo.bar> => write(env["foo"]["bar"])
	(with checks for existence in dict?)
$foo.1.bar
$<foo.1.bar> => write(env["foo"][1]["bar"])

$#foo
$<#foo>		=> write(#env["foo"])	-- CHANGED FROM LUST $foo.n
$#.
$<#.>		=> write(#env)

-- static rule lookup:
@sub 
@<sub> 
@.:sub 
@<.:sub> => write(rule_sub(env))
	(if rule is not found in current template, look in parent template)
	(rules need to be generated in order so that they can be found)
	(singly recursive rules should be ok, but mutually recursive rules will cause problems...)

@a.sub
@<a.sub> => write(rule_sub(env["a"])
@a.b.c:sub 
@<a.b.c:sub> => write(rule_sub(env["a"]["b"]["c"])

-- dynamic rule lookup:
@(x)
@<(x)>		=>	-- eval env["x"], then lookup function rule_<value of x>... 
				-- tricky, because we made rules local for speed...
				-- I guess we could also cache all rules in a rule-list?
-- should this also recurse to parent templates to search for rules?
-- it would be expensive, and possibly dangerous
-- a common idiom was @if(?(rule))<{{@(rule)}}>, which simply means
-- call the rule (only if it exists).
-- perhaps we could simplify by issuing a run-time warning or error
-- if the rule is not found?
etc.:
@a.b.c:(x)

-- dynamic environments:
@{args=.}:op	=> creates a new env dynamically, in which 'args' maps to the parent				
				env1 = { args=env }
				<rule_op>(env1)

-- multi-dict; not even really sure what this means
-- appears to be creating an iterable duplicate of current env array,
-- which is 'augmented' with new fields
@{ ., op=op:expr }:op	

-- conditionals:
@if(true)<resultrule>
@if(true)<resultrule>else<altrule>

@if(true)<{{ inline result }}>
@if(true)<{{ inline result }}>else<{{ inline alt }}>

-- what kinds of conditions?
@if(x)		-- evaluates to true if env["x"] exists

@if(#. > 0)				-- CHANGED FROM LUST @if(length{.} > "0")

@if(?(r))	-- lookup $r in the env, index template; does rule $r exist?

-- this is a common pattern for defaults,
-- perhaps we can add a syntax to make it simpler?
@if(min)<{{$min}}>else<{{0}}>


-- iterators:
@map{ . }:rule			=> for i, v in ipairs(env) do <rule(v)> end
@map{ . }:{{inline}}	=> for i, v in ipairs(env) do <inline(v)> end
@map{ foo }:rule		=> for i, v in ipairs(env["foo"]) do <rule(v)> end
@map{ foo, _separator=", " }:rule	
						=> for i, v in ipairs(env["foo"]) do 
							<rule(v)>
							write(", ")
						end
						
-- creating new dicts:
@map{ x=foo, _separator=", " }:{{ $x }} 
						=> for i, v in ipairs(env["foo"]) do 
							<rule{ x=v }>
							write(", ")
						end
-- this idiom was also common: @map{ v=. }:{{$v}}
-- but perhaps it could simply be @map{.}:{{$.}}



-- this has to be the weirdest of all.
-- it constructs a new env to pass to the <more> rule
-- the new env has input, len, and cond fields
	(which presumably should inherit...)
-- input is presumably an array
	-- but because of @rest the first item is not included
-- len is generated as the length of the array (no idea what :. is for)
-- cond grabs the first item
@rest{ input=args, len=length{args}:., cond=args.1:expr }:more


--]]

local template = {[[

-- current env:	
		$.
		$<.>

-- sub-env:		
		$foo
		$<foo>
		$1
		$<1>
		
-- sub-sub-env:	
		$a.b.c
		$a.1.b.2.c
		$<a.1.b.2.c>

-- current index:	
		$i0
		$i1
		
-- length:			
		$#.
		$#1
		$#foo
		$#a.1.b.2.c
		$<#a.1.b.2.c>

-- static rule:	
		@foo
		@<foo>
		@a:foo
		@a.1.b.2.c:foo
		@.:foo
		@<.:foo>
		@1:foo

-- inline rule:	
		@{{ some $1 inline $2 text }}
		@a.b.c:{{ some $1 inline $2 text }}
		@<a.b.c:{{ some $1 inline $2 text }}>
		
-- dynamic rule:		
		@(a)	
		@(a.1.b.2.c)
		@<(.)>
		@<a.b.c:(x.y)>
		
-- dynamic environments:
		@{ . }:foo
		@{ args }:foo
		@{ y=name }:foo
		@{ args, y=name }:foo
		@{ ., y=name }:foo
		@{ a.b.c, y=name }:foo	
		
-- notice here how a dynamic env can be generated
-- using a rule substitution:
		@{ ., a:foo }:foo
		@<{ args=., {a}:(y) }:(x.1.c)>

-- conditionals:	
		@if(x)<foo>
		@if(?x)<foo>
		@if(x)<foo>else<bar>
		@if(x)<{{ some $1 inline $2 text }}>
		@if(x)<{{ some $1 inline $2 text }}>else<{{ alternative }}>
		@if(#x > "0")<foo>
		@if(?(r))<foo>
		
-- iterators:		
		@map{ . }:foo
		@map{ . }:(x)
		@map{ . }:{{ inlined }}
		@map{ x }:foo
		@map{ x, y="foo" }:foo
		@map{ x, _separator=", " }:foo
		@rest{ input=args, len=#args, cond=args.1:expr }:more
]]}

local g, code = gen(template)
print(code)
