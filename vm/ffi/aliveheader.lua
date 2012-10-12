local header = [[
// generated from alive.h on Fri Oct 12 16:09:37 2012
 typedef struct al_Window al_Window;
 typedef int (*idle_callback)(int status);
 typedef int (*buffer_callback)(char * buffer, int size);
 typedef int (*filewatcher_callback)(const char * filename);
 void idle(idle_callback cb);
 void openfile(const char * path, buffer_callback cb);
 void openfd(int fd, buffer_callback cb);
 void watchfile(const char * filename, filewatcher_callback cb);
 al_Window * alive_window();
 void alive_tick();
 void al_sleep(double);
 typedef void (*audio_callback)(double sampletime);
 float * audio_outbuffer(int chan);
 const float * audio_inbuffer(int chan);
 float * audio_busbuffer(int chan);
 float audio_samplerate();
 int audio_buffersize();
 int audio_channelsin();
 int audio_channelsout();
 int audio_channelsbus();
 double audio_time();
 void audio_zeroout();
 double audio_cpu();
 void audio_set_callback(audio_callback cb);
 typedef enum {
  AUDIO_OTHER = 0,
  AUDIO_CLEAR,
  AUDIO_POS,
  AUDIO_QUAT,
  AUDIO_VOICE_NEW,
  AUDIO_VOICE_FREE,
  AUDIO_VOICE_POS,
  AUDIO_VOICE_PARAM,
 } audiocmd;
 typedef union audiomsg {
  struct {
   uint32_t cmd;
   uint32_t id;
   union {
    struct { float x, y, z, w; };
    char data[16];
   };
  };
  char str[24];
 } audiomsg;
 typedef struct audiomsg_packet {
  audiomsg body;
  double t;
 } audiomsg_packet;
 audiomsg * audioq_head();
 void audioq_send();
 audiomsg * audioq_peek(double maxtime);
 audiomsg * audioq_next(double maxtime);
 al_Window * al_window_get();
]]
local ffi = require 'ffi'
ffi.cdef(header)
return header