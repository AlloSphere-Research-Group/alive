local Shader = require "gl.Shader"

local vs = [[
#version 110

//attribute vec3 position;
//attribute vec3 normal;
//attribute vec4 color;
attribute vec4 rotate;
attribute vec3 translate;
attribute vec3 scale;

uniform float far;

varying vec4 C;
varying vec3 N;
varying float F;

//	q must be a normalized quaternion
vec3 quat_rotate(vec4 q, vec3 v) {
	// qv = vec4(v, 0) // 'pure quaternion' derived from vector
	// return ((q * qv) * q^-1).xyz
	// reduced to 24 multiplies and 17 additions:
	vec4 p = vec4(
		q.w*v.x + q.y*v.z - q.z*v.y,	// x
		q.w*v.y + q.z*v.x - q.x*v.z,	// y
		q.w*v.z + q.x*v.y - q.y*v.x,	// z
		-q.x*v.x - q.y*v.y - q.z*v.z	// w
	);
	return vec3(
		p.x*q.w - p.w*q.x + p.z*q.y - p.y*q.z,	// x
		p.y*q.w - p.w*q.y + p.x*q.z - p.z*q.x,	// y
		p.z*q.w - p.w*q.z + p.y*q.x - p.x*q.y	// z
	);
}

void main() {
	vec3 position = gl_Vertex.xyz;
	vec3 P = translate + quat_rotate(rotate, position * scale);

	gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * vec4(P, 1.);
	
	// fog effect
	float dist = gl_Position.z / far;
	F = 1.-pow(dist, 4.);
	
	N = quat_rotate(rotate, gl_Normal);	// normal
	C = gl_Color;	// color
}
]]

local fs = [[
#version 110

uniform vec3 ambient;

varying vec4 C;
varying vec3 N;
varying float F;

void main() {
	
	vec3 L = vec3(1, 1, -1);
	float l = max(0., dot(N, L));
	
	vec3 color = ambient + C.rgb*l;
	
	gl_FragColor = vec4(color, C.a*F);
}
]]

return Shader(vs, fs)
