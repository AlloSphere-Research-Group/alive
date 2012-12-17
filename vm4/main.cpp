#include "main.h"
#include "Q.hpp"

#include "alloutil/al_OmniApp.hpp"
#include "alloutil/al_Lua.hpp"

#include <stdio.h>
#include <stdlib.h>

using namespace al;

void default_synthesize_func(struct Agent& self, int frames, double samplerate, float * out) {
	double pincr = self.freq / samplerate;
	for (int i=0; i<frames; i++) {
		out[i] = sin(M_PI * 2. * self.phase);
		self.phase += pincr;
	}
}

inline vec3 quat_unrotate(const quat& q, const vec3& v) {
    // reduced:
	double px = q.w*v.x - q.y*v.z + q.z*v.y;
    double py = q.w*v.y - q.z*v.x + q.x*v.z;
    double pz = q.w*v.z - q.x*v.y + q.y*v.x;
	double pw = q.x*v.x + q.y*v.y + q.z*v.z;
    return vec3(
        pw*q.x + px*q.w + py*q.z - pz*q.y,  // x
        pw*q.y + py*q.w + pz*q.x - px*q.z,  // y
        pw*q.z + pz*q.w + px*q.y - py*q.x   // z
    );
}

// scale is like inverse far, so 1/32 creates a bigger world than 1/4
// amplitude drops to 50% at distance == (1/scale + near)
inline double attenuate(double d, double near, double scale) {
	double x = (d - near) * scale;
	if (x > 0.) {
		double xc = x + 4;
		double x1 = xc / (x*x + x + xc);
		return x1 * x1;
	}
	return 1.;
}

Q<audiomsg_packet> audioq;
double audiotime = 0;	// seconds
double maintime = 0;	// seconds
double audiolag = 0.04; // seconds

audiomsg * audioq_head() {
	return (audiomsg *)audioq.head();
}
void audioq_send() {
	audioq.q[audioq.write].t = audiotime + audiolag;
	audioq.send();
}

audiomsg * audioq_peek(double maxtime) {
	audiomsg_packet * p = audioq.peek();
	return (p && p->t < maxtime) ? (audiomsg *)p : 0;
}
audiomsg * audioq_next(double maxtime) {
	audioq.next();
	return audioq_peek(maxtime);
}

#pragma mark App

class App : public OmniApp, public Shared {
public:

	App() {
		// one-time only:
		if (mOmni.activeStereo()) {
			mOmni.resolution(2048);
		} else {
			mOmni.resolution(256);
		}
		
		
		initAudio(44100, 1024);
		audiotime = 0;
		
		update = 0;
		
		audioIO().channelsBus(2);
		
		numActiveSpeakers = 2;
		for (int i=0; i<numActiveSpeakers; i++) {
			SpeakerConfig& s = speakers[i];
			double angle = M_PI * 0.5 * (i - 0.5);
			s.weights.w = M_SQRT1_2;
			s.weights.x = sin(angle);
			s.weights.y = 0.;
			s.weights.z = -cos(angle);
		}
		
		audiogain = 0.05;
		
		// initialize shared:
		reset();	
	}
	
	void reset() {
		for (int i=0; i<MAX_AGENTS; i++) {
			Agent& a = agents[i];
			
			a.position.x = 10. * rnd::global().uniform();
			a.position.y = 10. * rnd::global().uniform();
			a.position.z = 10. * rnd::global().uniform();
			
			a.scale.set(1, 1, 1);
			a.color.set(0.5);
			
			// init unit vectors:
			a.rotate.toVectorX(a.ux);
			a.rotate.toVectorY(a.uy);
			a.rotate.toVectorZ(a.uz);
			
			a.synthesize = default_synthesize_func;
			a.encode.set(0, 0, 0, 0);
			a.phase = 0;
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
				float spec = max(dot(R, E), 0.0);
				//spec = pow(spec, 1.);
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
			shader().attribute(translateAttr, a.position.x, a.position.y, a.position.z);
			shader().attribute(scaleAttr, a.scale.x, a.scale.y, a.scale.z);
			gl.color(a.color.r, a.color.g, a.color.b, a.color.a);
			gl.draw(cube);
		}
	}
	
	void simulate(al_sec dt) {
		for (int i=0; i<MAX_AGENTS; i++) {
			Agent& a = agents[i];
			
			// accumulate velocity:
			vec3 vel = a.uz * -a.move.z;
			a.position += vel * dt;
			
			// accumulate rotation:
			vec3 turn = a.turn * dt;
			quat r = quat().fromEuler(turn.y, turn.x, turn.z);
			// apply:
			a.rotate = a.rotate * r;
			a.rotate.normalize();
			
			// update unit vectors:
			a.rotate.toVectorX(a.ux);
			a.rotate.toVectorY(a.uy);
			a.rotate.toVectorZ(a.uz);
		}
		
		if (update) update(*this, dt);
	}
	
	virtual void onAnimate(al_sec dt) {
		simulate(dt);
		
		if (frame == 1) {
			// allocate GPU resources:
			cube.primitive(gl.QUADS);
			addCube(cube, true, 0.5);
			
			shader().begin();
			shader().uniform("lighting", 0.8);
			shader().end();
		}
		// call back into Lua
	}
	
	virtual void onSound(AudioIOData& io) {
		int frames = io.framesPerBuffer();
		double samplerate = io.framesPerSecond();
		
		if (audiotime == 0) {
			printf("audio started %d samples, %f Hz, %dx%d + %d\n", frames, samplerate, io.channelsIn(), io.channelsOut(), io.channelsBus());
		}
		io.zeroOut();
		io.zeroBus();
		
		float * bus = io.busBuffer(0);
		float * out0 = io.outBuffer(0);
		float * out1 = io.outBuffer(1);
		vec4 w0 = speakers[0].weights;
		vec4 w1 = speakers[1].weights;
		Pose& view = nav();
		
		// process incoming messages:
		double nexttime = audiotime + frames / samplerate;
		
		// play all agents:
		for (int i=0; i<MAX_AGENTS; i++) {
			Agent& a = agents[i];
			
			// get position in 'view space':
			vec3 rel = quat_unrotate(view.quat(), a.position - view.pos());
			// distance squared:
			double d2 = rel.dot(rel);
			// distance
			double d = sqrt(d2);
			// unit rel:
			vec3 direction = rel * (1./d);			
			// amplitude scale by distance:
			double atten = attenuate(d2, 0.2, 1/10.);
			// omni mix is also distance-dependent. 
			// at near distances, the signal should be omnidirectional
			// the minimum really depends on the radii of the listener/emitter
			double spatial = 1. - attenuate(d2, 0.2, 1/2.);
			// encode matrix:
			// first 3 harmonics are the same as the unit direction:
			vec4 encode(
				atten * spatial * direction.x,
				atten * spatial * direction.y,
				atten * spatial * direction.z,
				atten // * M_SQRT2
			);
			
			// render:
			(a.synthesize)(a, frames, samplerate, bus);
			
			// decode:
			double invframes = 1./frames;
			for (int j=0; j<frames; j++) { 
				float s = bus[j] * audiogain;
				
				if (j==0) {
					//printf("agent %d: d2 %f atten %f spatial %f w %f\n", i, d2, atten, spatial, w0.w);
				}
				
				// linear interpolated encoding matrix:
				double alpha = j * invframes;
				vec4 enc = ipl::linear(alpha, a.encode, encode);
								
				// decode:
				out0[j] = out0[j] + s * (
					+ w0.x * enc.x
					+ w0.y * enc.y 
					+ w0.z * enc.z
					+		 enc.w	//  * w0.w
				);
				
				out1[j] = out1[j] + s * (
					+ w1.x * enc.x
					+ w1.y * enc.y 
					+ w1.z * enc.z
					+		 enc.w	//  * w1.w
				);
			}
			
			// update cached:
			a.direction = direction;
			a.distance = d;
			a.encode = encode;
		}
		
		audiotime = nexttime;	
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