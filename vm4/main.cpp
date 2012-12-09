#include "main.h"

#include "alloutil/al_OmniApp.hpp"
#include "alloutil/al_Lua.hpp"

#include <stdio.h>
#include <stdlib.h>

using namespace al;

class App : public OmniApp, public Shared {
public:

	App() {
		// initialize shared:
		reset();
		
		mOmni.resolution(256);
	}
	
	void reset() {
		for (int i=0; i<MAX_AGENTS; i++) {
			Agent& a = agents[i];
			a.translate.x = 10. * sin(i * 0.1) + 5.;
			a.translate.y = sin(i) + i * 0.01;
			a.translate.z = 10. * cos(i * 0.1) - 5.;
			
			a.scale.set(0.5, 0.2, 1);
			
			a.rotate.fromAxisY(cos(i));
		}
	}
	
	virtual std::string	vertexCode() {
		return AL_STRINGIFY(
			attribute vec4 rotate;
			attribute vec3 translate;
			attribute vec3 scale;
			varying vec4 color;
			varying vec3 normal, lightDir, eyeVec;
			varying vec4 La, Ld, Ls;
			
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
			
			void main(){
				vec3 P = translate + quat_rotate(rotate, gl_Vertex.xyz * scale);
				vec4 vertex = gl_ModelViewMatrix * vec4(P, gl_Vertex.w);
				gl_Position = omni_render(vertex); 
				
				normal = gl_NormalMatrix * gl_Normal;
				color = gl_Color;
				
				vec3 V = vertex.xyz;
				eyeVec = normalize(-V);
				lightDir = normalize(vec3(gl_LightSource[0].position.xyz - V));
				La = gl_LightSource[0].ambient;
				Ld = gl_LightSource[0].diffuse;
				Ls = gl_LightSource[0].specular;
			}
		);
	}

	virtual std::string fragmentCode() {
		return AL_STRINGIFY(
		uniform float lighting;
			varying vec4 color;
			varying vec3 normal, lightDir, eyeVec;
			varying vec4 La, Ld, Ls;
			void main() {
				vec4 final_color = color * La;
				vec3 N = normalize(normal);
				vec3 L = lightDir;
				float lambertTerm = max(dot(N, L), 0.0);
				final_color += Ld * color * lambertTerm;
				vec3 E = eyeVec;
				vec3 R = reflect(-L, N);
				float spec = pow(max(dot(R, E), 0.0), 1.);
				final_color += Ls * spec;
				gl_FragColor = mix(color, final_color, lighting);
			}
		);
	}
	
	virtual void onDraw(Graphics& gl) {
		// draw all active agents
		int translateAttr = shader().attribute("translate");
		int rotateAttr = shader().attribute("rotate");
		int scaleAttr = shader().attribute("scale");
		for (int i=0; i<MAX_AGENTS; i++) {
			Agent& a = agents[i];
			shader().attribute(rotateAttr, a.rotate.x, a.rotate.y, a.rotate.z, a.rotate.w);
			shader().attribute(translateAttr, a.translate.x, a.translate.y, a.translate.z);
			shader().attribute(scaleAttr, a.scale.x, a.scale.y, a.scale.z);
			gl.draw(cube);
		}
	}
	
	virtual void onAnimate(al_sec dt) {
		if (frame == 1) {
			// allocate GPU resources:
			cube.primitive(gl.QUADS);
			addCube(cube, true, 0.5);
		}
		// call back into Lua
	}
	
	virtual void onSound(AudioIOData& io) {
		// play all the agents, encoding
		// play the environment
		// decoding to speakers
	}
	
	virtual void onMessage(osc::Message& m) {
		OmniApp::onMessage(m);
		
	}
	
	Lua L;
	
	Graphics gl;
	Mesh cube;
};

App * app;

Shared * app_get() {
	return app;
}

int main(int argc, char * argv[]) {
	app = new App;

	// run main script:
	app->L.dofile("main.lua");
	
	app->start();
	printf("done\n");
	return 0;
}