for i=1, 20 do
	Agent(['beeps', 'beeps2'])
end

tags.beep.on("collide", ...)
tags["beep.foo"].on(...)

_("beep, fo").pick(0.5).freq = _("beep, foo").pick().freq

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

Tag{
	"beep2",
	inherits = ['beeps', ],
	osc = {
	
	}
	fx = {
	
	},
}

for i=1, 20 do
	Agent(["beeps2"])
end

$"beeps2".die()

a = $("beep")[0]
a = $"beep".pick()
a = pick("beep")

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


