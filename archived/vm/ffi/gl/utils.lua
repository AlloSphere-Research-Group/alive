local gl = require "ffi.gl"

local M_DEG2RAD = 0.017453292519943

local
function quad(x, y, w, h)
	gl.Begin(gl.QUADS)
		gl.TexCoord(0, 0)
		gl.Vertex(x-w, y-h, 0)
		gl.TexCoord(0, 1)
		gl.Vertex(x-w, y+h, 0)
		gl.TexCoord(1, 1)
		gl.Vertex(x+w, y+h, 0)
		gl.TexCoord(1, 0)
		gl.Vertex(x+w, y-h, 0)
	gl.End()
	assert(gl.GetError() == 0)
end

local
function ortho(l, b, r, t, near, far)
	local W = r-l
	local W2 = r+l
	local H = t-b
	local H2 = t+b
	local D = far - near
	local D2 = far + near
	return {	2/W,	0,		0,		0,
				0,		2/H,	0,		0,
				0,		0,		-2/D,	0,
				-W2/W,	-H2/H,	-D2/D,	1	}
end

local
function perspective(fovy, aspect, near, far)
		local f = 1/math.tan(fovy*M_DEG2RAD/2)
		local D = far-near	
		local D2 = far+near
		local fn2 = far*near*2
		return {	
			f/aspect,	0,	0,			0,
			0,			f,	0,			0,
			0,			0,	-D2/D,		-1,
			0,			0,	-fn2/D,		0
		}
end

local
function perspective2(l, r, t, b, near, far)
	local W = r-l
	local W2 = r+l
	local H = t-b
	local H2 = t+b
	local D = far - near
	local D2 = far + near
	local n2 = near * 2
	local fn2 = far * n2
	return {	n2/W,	0,		0,		0,
				0,		n2/H,	0,		0,
				W2/W,	H2/H,	-D2/D,	-1,
				0,		0,		-fn2/D,	0	}
end

local
function perspective1(l, r, t, b, n, f)
		local W = r-l;	local W2 = r+l;
		local H = t-b;	local H2 = t+b;
		local D = f-n;	local D2 = f+n;
		local n2 = n*2;
		local fn2 = f*n2;
		return {	n2/W,	0,		0,		0, 
					0,		n2/H,	0,		0, 
					W2/W,	H2/H,	-D2/D,	-1,
					0,		0,		-fn2/D,	0 
		}
end


local
function perspective_offaxis(nearBL, nearBR, nearTL, eye, near, far)
	-- compute orthonormal basis for the screen
	local vr = (nearBR - nearBL):normalize() --(nearBR-nearBL).normalize() -- right vector
	local vu = (nearTL - nearBL):normalize() --(nearTL-nearBL).normalize() -- upvector
	local vn = (vr:cross(vu)):normalize() -- cross(vn, vr, vu);	// normal(forward) vector (out from screen)
		--vn.normalize();
		
	-- compute vectors from eye to screen corners:
	local va = nearBL - eye	
	local vb = nearBR - eye
	local vc = nearTL - eye
	
	-- distance from eye to screen-plane
	-- = component of va along vector vn (normal to screen)
	local d = (-va):dot(vn)
	
	-- find extent of perpendicular projection
	local nbyd = near/d
	local l =  vr:dot(va) * nbyd
	local r =  vr:dot(vb) * nbyd
	local b =  vu:dot(va) * nbyd	-- not vd?
	local t =  vu:dot(vc) * nbyd
	return perspective1(l, r, t, b, near, far)
end

local
function lookat(eye, at, up)
	local uz = (eye-at):normalize()
	local up = up:normalize()
	local ux = uz:cross(up)
	local m = {	
		ux.x,			up.x,			uz.x,			0,
		ux.y,			up.y,			uz.y,			0,
		ux.z,			up.z,			uz.z,			0,
		-ux:dot(eye),	-up:dot(eye),	-uz:dot(eye),	1,	
	}
	return m
end

return {
	quad = quad,
	ortho = ortho,
	perspective = perspective,
	perspective1 = perspective1,
	perspective_offaxis = perspective_offaxis,
	lookat = lookat,
}
