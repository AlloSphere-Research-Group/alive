-- tags are a bit like classes, but associative rather than strict trees
-- agents can associate and disassociate with one or more tags at a time
-- tag behaviors can be updated, which propagates to all agents using them
-- tags can also be used to select agents and modify their properties
-- (akin to JQuery DOM selection & CSS modification)

-- world DOM (WOM) is mostly flat, more like many divs with multiple css classes

-- heavily event-driven

for i=1, 20 do
	Agent(['beeps', 'beeps2'])
end

tags.beep.on("collide", ...)
tags["beep.foo"].on(...)

-- pick chooses one agent at random from the set
-- pick(0.5) chooses 50% of the agents at random
-- so this line makes 50% of the agent frequencies equal to one of the agent freqs
_("beep, foo").pick(0.5).freq = _("beep, foo").pick().freq

-- instantaneous
_("beep").near("foo", {.1,.1,.1}).die()
-- for ever more
law1 = _("beep").on(near("foo", {.1,.1,.1}), die)
_("beep").on("law1", near("foo", {.1,.1,.1}), die)

beeps = Tag{
	osc = {
		freq = 220,
		f2 = 20,
		SinOsc(freq) + SinOsc(f2)
	}
}

for i=1, 20 do
	Agent(["beeps"])
end

-- create a new tag:
Tag{
	"beep2",
	inherits = ['beeps', ],		-- copy or reference?
	osc = {
	
	}
	fx = {
	
	},
}

for i=1, 20 do
	Agent(["beeps2"])
end

-- JQuery inspired:
-- all agents tagged with 'beeps2' die immediately:
$"beeps2".die()

-- get first beep:
a = $("beep")[0]
-- get a random beep:
a = $"beep".pick()
a = pick("beep")

-- set a property on the picked agent:
a.beep.osc.freq = 440
a.freq = 440

--a = $"beep"."osc"[0].$"freq"

{
	tags = {
		beep = {
			osc = {
			
			}
		}
	}
	inherits = {
		beep2 = {
			osc = {
				
			}
		}
	}
}


