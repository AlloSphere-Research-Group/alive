local Shader = require "gl.Shader"

local vs = [[
#version 120

uniform float pointSize;
uniform float viewportWidth;

void main(){
	gl_FrontColor = gl_Color;
	
	vec4 Pe = gl_ModelViewMatrix * gl_Vertex;	//flux_modelview(gl_Vertex);
	gl_Position = gl_ProjectionMatrix * Pe;		//flux_projection(Pe);
	
	gl_PointSize = pointSize * viewportWidth / length(gl_Position.xyz);
}
]]

local fs = [[
#version 120

uniform sampler2D tex0;

void main(){
	//gl_FragColor = gl_Color * texture2D(tex0, gl_PointCoord);
	gl_FragColor = gl_Color * texture2D(tex0, gl_TexCoord[0].xy);
}
]]

return Shader(vs, fs)
