return [[static const int MAX_SPEAKERS = 16;
static const int MAX_AGENTS = 150;
static const int WORLD_DIM = 32;	// power of 2
static const int DOPPLER_SAMPLES = 4096;
static const int BUFFER_SAMPLES = 512;
static const int TRAIL_LENGTH = 8;

typedef struct Color { float r, g, b, a; } Color;
typedef struct Pose { vec3 position; quat rotate; } Pose;

typedef struct av_Audio {
	unsigned int blocksize;
	unsigned int frames;	
	unsigned int indevice, outdevice;
	unsigned int inchannels, outchannels;		
	
	double time;		// in seconds
	double samplerate;
	double lag;			// in seconds
	
	//av_msgbuffer msgbuffer;
	
	// a big buffer for main-thread audio generation
	float * buffer;
	// the buffer alternates between channels at blocksize periods:
	int blocks, blockread, blockwrite, blockstep;
	
	// only access from audio thread:
	float * input;
	float * output;	
	void (*onframes)(struct av_Audio * self, double sampletime, float * inputs, float * outputs, int frames);
	
} av_Audio;

typedef struct Agent {

	// used in rendering:
	Color color;
	quat rotate;
	vec3 position;
	vec3 scale;

	// controls:
	int32_t enable, visible;
	double velocity, acceleration; 
	vec3 turn, twist;
	
	int32_t id, nearest;
	double nearest_distance;
	 
	// cached for simulation:
	vec3 ux, uy, uz;
	
	// trails:
	//Trail trails[TRAIL_LENGTH];
	//int32_t trail_start, trail_size;

} Agent;

typedef struct Voice {
		
	// audio:
	float buffer[DOPPLER_SAMPLES];
	
	vec4 encode; // the previous frame's encoding matrix
	vec3 direction;	// from camera
	double distance;	
	
	uint32_t buffer_index;
	uint32_t iphase;
	double amp, freq, phase;
	
	int32_t id;
	
	// pointer: valid for master only!!
	void (*synthesize)(struct Voice&, int frames, float * out);

} Voice;

typedef struct SpeakerConfig {
	vec4 weights;
} SpeakerConfig;

typedef struct Shared {
	
	Agent agents[MAX_AGENTS];
	Pose view;
	vec3 active_origin;
	
	Color bgcolor;
	
	uint32_t framecount;
	uint32_t mode;
	uint32_t show_collisions;
	float eyesep;
	
	float audiogain, reverbgain;
	
	double doppler_strength;
	int32_t numActiveSpeakers, updating;
	
	SpeakerConfig speakers[MAX_SPEAKERS];
	Voice voices[MAX_AGENTS];
	
} Shared;

Shared * app_get();

av_Audio * av_audio_get();
void av_audio_start(); ]]