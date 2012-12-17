local vec = require "vec"
local vec3, quat = vec.vec3, vec.quat

local nav = {}
nav.__index = nav

function nav:step()
	-- standard pipeline:
	self.pos:add(			
		self.quat:ux():mul(self.move.x)
			:add( self.quat:uy():mul(self.move.y) )
			-- negative for OpenGL:
			:sub( self.quat:uz():mul(self.move.z) )
	)
	self.quat:mul( quat():fromEuler(self.turn.y, self.turn.x, self.turn.z) )
		:normalize()
end

setmetatable(nav, {
	__call = function(_)
		return setmetatable({
			move = vec3(),
			turn = vec3(),
			pos = vec3(),
			scale = vec3(),
			quat = quat(),
			color = vec3(),
			
		}, nav)
	end
})

return nav