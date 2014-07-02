#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>

#include "vec.h"
#include "audio_utils.h"
#include "gigaverb.h"

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

extern "C" {
	#include "world.h"
}

// audio globals:
double samplerate = 44100;
double invsamplerate = 1./samplerate;
double doppler_scale = (DOPPLER_SAMPLES - 512) / double(WORLD_DIM);

const uint32_t WAVEBITS = 10;
const uint32_t WAVESIZE = 1 << WAVEBITS;
const uint32_t FRACBITS = 32 - WAVEBITS;
const uint32_t FRACMASK = ( 1 << FRACBITS ) - 1;
const double FRACSCALE = 1.0 / ( 1 << FRACBITS );


// extra sample for linear interp:
double sine_wavetable [ WAVESIZE + 1 ];

void init_wavetables() {
	for (uint32_t i=0; i<=WAVESIZE+1; i++) {
		double p = double(i) / WAVESIZE;
		sine_wavetable[i] = sin(M_PI * 2. * p);
	}
}

void default_synthesize_func(struct Voice& self, int frames, float * out) {
	const uint32_t om = uint32_t(self.freq * invsamplerate * 4294967296.0); // 2^32
	uint32_t p = self.iphase;
	for (int i=0; i<frames; i++) {
		const uint32_t idx = p >> FRACBITS;
		const double s0 = sine_wavetable[idx];
		const double s1 = sine_wavetable[idx+1];
		const double a = (p & FRACMASK) * FRACSCALE;
		out[i] = s0 + a*(s1 - s0);
		p += om;
	}
	self.iphase = p;
}

class App : public Shared {
public:

	Gigaverb verb;
	
	double samplerate, invsamplerate;
	double audiotime;
	
	float W[BUFFER_SAMPLES];
	float X[BUFFER_SAMPLES];
	float Y[BUFFER_SAMPLES];
	float Z[BUFFER_SAMPLES];
	float R[BUFFER_SAMPLES];	// reverb
	
	App() {
		doppler_strength = 1.;
		audiogain = 0.5;
		reverbgain = 0.03;
		
		verb.reset();
	
		// default speaker config:
		// stereo mode:
		numActiveSpeakers = 2;
		for (int i=0; i<numActiveSpeakers; i++) {
			SpeakerConfig& s = speakers[i];
			double angle = M_PI * 0.5 * (i - 0.5);
			s.weights.w = M_SQRT1_2;
			s.weights.x = sin(angle);
			s.weights.y = 0.;
			s.weights.z = -cos(angle);
		}
		
		for (int i=0; i<MAX_AGENTS; i++) {
			agents[i].enable = 0;
			
			
			memset(voices[i].buffer, 0, DOPPLER_SAMPLES * sizeof(float));
		}
		
		av_audio_get()->onframes = &App::onframes;
	}
	
	void onSound(struct av_Audio& io, double sampletime, float * inputs, float * outputs, int frames) {
	
		samplerate = io.samplerate;
		invsamplerate = 1./samplerate;
		audiotime = io.time;
		
		double dt = frames * invsamplerate;
		
		if (audiotime == 0) {
			printf("audio started %d samples, %fHz, %dx%d\n", frames, samplerate, io.inchannels, io.outchannels);
			fflush(stdout);
		}
		
		memset(outputs, 0, frames * io.outchannels * sizeof(float));
		memset(W, 0, frames *  sizeof(float));
		memset(X, 0, frames *  sizeof(float));
		memset(Y, 0, frames *  sizeof(float));
		memset(Z, 0, frames *  sizeof(float));
		memset(R, 0, frames *  sizeof(float));
		
		// desktop stereo mode:
		float * out0 = outputs;
		float * out1 = outputs + 1;
		
		const vec4& w0 = speakers[0].weights;
		const vec4& w1 = speakers[1].weights;
		
		// process incoming messages:
		double nexttime = audiotime + frames / samplerate;
		
		// play all agents:
		for (int i=0; i<MAX_AGENTS; i++) {
			Agent& a = agents[i];
			if (a.enable) {
			
				// do movement here in audio thread:
				if (updating) {
					
					// accumulate velocity:
					vec3 vel = a.acceleration + a.uz * -a.velocity;
					a.position += vel * dt;
					
					// accumulate rotation:
					vec3 turn = a.twist + a.turn * dt;
					quat r = quat().fromEuler(turn.y, turn.x, turn.z);
					
					// apply rotation:
					a.rotate = a.rotate * r;
					a.rotate.normalize();
					
					// kill acceleration:
					a.twist.set(0);
					a.acceleration = 0;
				}
				
				// wrap location:
				for (int j=0; j<3; j++) {
					double p = a.position[j];
					p -= active_origin[j];
					p = wrap(p, (double)WORLD_DIM);
					p += active_origin[j];
					a.position[j] = p;
				}
				
				// now synthesize:
				
				// get position in 'view space':
				vec3 rel = quat_unrotate(view.rotate, a.position - view.position);
				// distance squared:
				double d2 = rel.dot(rel);
				// distance
				double d = sqrt(d2);
				// unit rel:
				vec3 direction = rel * (1./d);			
				// amplitude scale by distance:
				double atten = attenuate(d2, 0.2, 0.04);
				// omni mix is also distance-dependent. 
				// at near distances, the signal should be omnidirectional
				// the minimum really depends on the radii of the listener/emitter
				double spatial = 1. - attenuate(d2, 0.1, 0.9);
				// encode matrix:
				// first 3 harmonics are the same as the unit direction:
				vec4 encode(
					atten * spatial * direction.x,
					atten * spatial * direction.y,
					atten * spatial * direction.z,
					atten // * M_SQRT2
				);
				
				// render into doppler buffer:
				Voice& v = voices[i];
				(v.synthesize)(v, frames, v.buffer + v.buffer_index);
				
				// decode:
				double invframes = 1./frames;
				for (int j=0; j<frames; j++) { 
					
					// linear interpolate encoding matrix:
					double alpha = j * invframes;
					vec4 enc = linear_interp(alpha, v.encode, encode);
					double dist = linear_interp(alpha, v.distance, d);
					
					// doppler lookup
					// take current buffer index
					// shift backwards by distance-dependent doppler time
					double idx = (v.buffer_index + j) + (DOPPLER_SAMPLES - dist * doppler_scale * doppler_strength);
					int32_t idx1 = int32_t(idx);
					double idxf = idx - double(idx1); // will this work?
					
					float s0 = v.buffer[(idx1 - 1) & (DOPPLER_SAMPLES - 1)];
					float s1 = v.buffer[idx1 & (DOPPLER_SAMPLES - 1)];
					float s = linear_interp(idxf, s0, s1);
					
						
					if (j==0) {
						//printf("agent %d: d2 %f atten %f spatial %f w %f\n", i, d2, atten, spatial, w0.w);
						//printf("idx %f idx0 %d idx1 %d fract %f\n",  idx, idx0, idx1, idxf);
					}
					
					s *= v.amp * audiogain;
					
					R[j] += s * reverbgain;
					
					// local decode (stereo):
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
				v.direction = direction;
				v.distance = d;
				v.encode = encode;
				v.buffer_index = (v.buffer_index + frames) & (DOPPLER_SAMPLES - 1);
			}
		}
			
		verb.perform(R, out0, out1, frames);
	}
	
	static void onframes(struct av_Audio * io, double sampletime, float * inputs, float * outputs, int frames);

};

static App app;

Shared * app_get() {
	return &app;
}

void App::onframes(struct av_Audio * io, double sampletime, float * inputs, float * outputs, int frames) {
	app.onSound(*io, sampletime, inputs, outputs, frames);
}