#include "gigaverb.h"

/*

struct Delay {
	double * memory;
	long size, wrap, maxdelay;
	long reader, writer;
	
	t_genlib_data * dataRef;
	
	Delay() : memory(0) {
		size = wrap = maxdelay = 0;
		reader = writer = 0;
		dataRef = 0;
	}
	~Delay() {
		if (dataRef != 0) {
			// store write position for persistence:
			genlib_data_setcursor(dataRef, writer);
			// decrement reference count:
			genlib_data_release(dataRef);
		}
	}
	
	inline void reset(const char * name, long d) {
		// if needed, acquire the Data's global reference: 
		if (dataRef == 0) {
		
			void * ref = genlib_obtain_reference_from_string(name);
			dataRef = genlib_obtain_data_from_reference(ref);
			if (dataRef == 0) {	
				genlib_report_error("failed to acquire data");
				return; 
			}
			
			// scale maxdelay to next highest power of 2:
			maxdelay = d;
			size = maximum(maxdelay,2);
			size = next_power_of_two(size);
			
			// first reset should resize the memory:
			genlib_data_resize(dataRef, size, 1);
			
			t_genlib_data_info info;
			if (genlib_data_getinfo(dataRef, &info) == GENLIB_ERR_NONE) {
				if (info.dim != size) {
					// at this point, could resolve by reducing to 
					// maxdelay = size = next_power_of_two(info.dim+1)/2;
					// but really, if this happens, it means more than one
					// object is referring to the same t_gen_dsp_data.
					// which is probably bad news.
					genlib_report_error("delay memory size error");
					memory = 0;
					return;
				}
				memory = info.data;
				writer = genlib_data_getcursor(dataRef);
			} else {
				genlib_report_error("failed to acquire data info");
			}
		
		} else {
		
			// subsequent reset should zero the memory & heads:
			set_zero64(memory, size);
			writer = 0;
		}
		
		reader = writer;
		wrap = size-1;
		
		//genlib_report_message("delay %d %d %d", maxdelay, size, wrap);
	}
	
	// called at bufferloop end, updates read pointer time
	inline void step() {	
		reader++; 
		if (reader >= size) reader = 0;
	}
	
	inline void write(double x) {
		writer = reader;	// update write ptr
		memory[writer] = x;
	}	
	
	inline double read_step(double d) {
		//const double r = double(size + writer) - (d-0.5);	
		// extra half for nice rounding:
		// min 1 sample delay for read before write (r != w)
		const double r = double(size + reader) - clamp(d-0.5, (reader != writer), maxdelay);	
		long r1 = long(r);
		return memory[r1 & wrap];
	}
	
	inline double read_linear(double d) {
		//const double r = double(size + writer) - d;
		// min 1 sample delay for read before write (r != w)
		double c = clamp(d, (reader != writer), maxdelay);
		const double r = double(size + reader) - c;	
		long r1 = long(r);
		long r2 = r1+1;
		double a = r - (double)r1;
		double x = memory[r1 & wrap];
		double y = memory[r2 & wrap];
		return linear_interp(a, x, y);
	}
	
	inline double read_cosine(double d) {
		//const double r = double(size + writer) - d;
		// min 1 sample delay for read before write (r != w)
		const double r = double(size + reader) - clamp(d, (reader != writer), maxdelay);	
		long r1 = long(r);
		long r2 = r1+1;
		double a = r - (double)r1;
		double x = memory[r1 & wrap];
		double y = memory[r2 & wrap];
		return cosine_interp(a, x, y);
	}
	
	// cubic requires extra sample of compensation:
	inline double read_cubic(double d) {
		//const double r = double(size + writer) - (d+1.);
		// min 1 sample delay for read before write (r != w)
		// plus extra 1 sample compensation for 4-point interpolation
		const double r = double(size + reader) - clamp(d, 1.+(reader != writer), maxdelay);	
		long r1 = long(r);
		long r2 = r1+1;
		long r3 = r1+2;
		long r4 = r1+3;
		double a = r - (double)r1;
		double w = memory[r1 & wrap];
		double x = memory[r2 & wrap];
		double y = memory[r3 & wrap];
		double z = memory[r4 & wrap];
		return cubic_interp(a, w, x, y, z);
	}
	
	// spline requires extra sample of compensation:
	inline double read_spline(double d) {
		//const double r = double(size + writer) - (d+1.);
		// min 1 sample delay for read before write (r != w)
		// plus extra 1 sample compensation for 4-point interpolation
		const double r = double(size + reader) - clamp(d, 1.+(reader != writer), maxdelay);	
		long r1 = long(r);
		long r2 = r1+1;
		long r3 = r1+2;
		long r4 = r1+3;
		double a = r - (double)r1;
		double w = memory[r1 & wrap];
		double x = memory[r2 & wrap];
		double y = memory[r3 & wrap];
		double z = memory[r4 & wrap];
		return spline_interp(a, w, x, y, z);
	}
};


#pragma mark Gigaverb
double samplerate = 44100;
int vectorsize = 128;
struct Gigaverb {
	
	double damping;
	double dry;
	double tail;
	double bandwidth;
	double revtime;
	double early;
	double roomsize;
	double spread;
	
	double history_47;
	double history_204;
	double history_59;
	double history_207;
	double history_71;
	
	Delay delay_227;
	Delay delay_225;
	Delay delay_219;
	Delay delay_230;
	Delay delay_226;
	Delay delay_222;
	Delay delay_224;
	Delay delay_223;
	Delay delay_221;
	Delay delay_228;
	Delay delay_229;
	Delay delay_220;
	
	Gigaverb() { reset(); } 
	inline void reset(){
		damping = 0.7;
		dry = 1;
		tail = 0.25;
		bandwidth = 0.5;
		revtime = 11;
		early = 0.25;
		roomsize = 75;
		spread = 23;
		
		history_47 = 0;
		history_204 = 0;
		history_59 = 0;
		history_207 = 0;
		history_71 = 0;
		
		delay_225.reset(48000);
		delay_219.reset(48000);
		delay_222.reset(48000);
		delay_221.reset(48000);
		delay_220.reset(48000);	
		
		// diffusers:
		delay_227.reset(6000);
		delay_230.reset(7000);
		delay_226.reset(15000);
		delay_224.reset(12000);
		delay_223.reset(10000);
		delay_228.reset(16000);
		delay_229.reset(5000);	
	}
	
	inline void perform(double * * __ins, double * * __outs, int __n){
		const double * __in1 = __ins[0];
		const double * __in2 = __ins[1];
		double * __out1 = __outs[0];
		double * __out2 = __outs[1];
		if ( ((__in1 == 0) || (__in2 == 0) || (__out1 == 0) || (__out2 == 0)) ){
			return;
			
		}
		while ((__n--)){
			const double in1 = *(__in1++);
			const double in2 = *(__in2++);
			double mul_265 = (in1 * dry);
			double sub_270 = (1 - bandwidth);
			double mul_276 = (in2 * dry);
			double add_282 = (in1 + in2);
			double mul_284 = (add_282 * 0.707);
			double mix_292 = (mul_284+sub_270*((history_207)-(mul_284)));
			double mul_305 = (revtime * 44100);
			double div_306 = safediv(1, mul_305);
			double pow_307 = safepow(0.001, div_306);
			double mul_313 = (roomsize * 44100);
			double div_315 = safediv(mul_313, 340);
			double mul_320 = (div_315 * 1);
			double read_324 = delay_219.read_linear(mul_320);
			double pow_330 = safepow(pow_307, mul_320);
			double neg_331 = (-(pow_330));
			double mul_337 = (read_324 * neg_331);
			double mix_345 = (mul_337+damping*((history_204)-(mul_337)));
			double mul_350 = (div_315 * 0.81649);
			double read_354 = delay_220.read_linear(mul_350);
			double pow_360 = safepow(pow_307, mul_350);
			double neg_361 = (-(pow_360));
			double mul_367 = (read_354 * neg_361);
			double mix_375 = (mul_367+damping*((history_71)-(mul_367)));
			double mul_380 = (div_315 * 0.63245);
			double read_384 = delay_221.read_linear(mul_380);
			double pow_390 = safepow(pow_307, mul_380);
			double neg_391 = (-(pow_390));
			double mul_397 = (read_384 * neg_391);
			double mix_405 = (mul_397+damping*((history_47)-(mul_397)));
			double mul_410 = (div_315 * 0.7071);
			double read_414 = delay_222.read_linear(mul_410);
			double pow_420 = safepow(pow_307, mul_410);
			double neg_421 = (-(pow_420));
			double mul_427 = (read_414 * neg_421);
			double mix_435 = (mul_427+damping*((history_59)-(mul_427)));
			double mul_440 = (div_315 * 0.000527);
			int int_444 = int(mul_440);
			double mul_449 = (spread * 0.376623);
			double add_454 = (mul_449 + 931);
			double sub_459 = (1341 - add_454);
			double mul_465 = (int_444 * sub_459);
			double read_469 = delay_223.read_linear(mul_465);
			double mul_474 = (spread * -0.380445);
			double add_479 = (mul_474 + 931);
			double sub_484 = (1341 - add_479);
			double mul_490 = (int_444 * sub_484);
			double read_494 = delay_224.read_linear(mul_490);
			double mul_499 = (read_469 * 0.625);
			double add_505 = (mix_345 + mix_375);
			double add_511 = (mix_435 + mix_405);
			double sub_517 = (add_505 - add_511);
			double mul_522 = (sub_517 * 0.5);
			double add_527 = (div_315 + 5);
			double sub_533 = (mix_345 - mix_375);
			double sub_539 = (mix_435 - mix_405);
			double sub_545 = (sub_533 - sub_539);
			double mul_550 = (sub_545 * 0.5);
			double add_556 = (add_505 + add_511);
			double mul_561 = (add_556 * 0.5);
			double pow_567 = safepow(pow_307, add_527);
			double mul_572 = (read_494 * 0.625);
			double add_578 = (sub_533 + sub_539);
			double sub_583 = (0 - add_578);
			double mul_588 = (sub_583 * 0.5);
			double mul_593 = (div_315 * 0.41);
			double add_598 = (mul_593 + 5);
			double mul_603 = (div_315 * 0.3);
			double add_608 = (mul_603 + 5);
			double mul_613 = (div_315 * 0.155);
			double add_618 = (mul_613 + 5);
			double read_622 = delay_225.read_linear(add_598);
			double read_626 = delay_225.read_linear(add_608);
			double read_630 = delay_225.read_linear(add_618);
			double read_634 = delay_225.read_linear(add_527);
			double pow_640 = safepow(pow_307, add_598);
			double mul_646 = (read_622 * pow_640);
			double add_652 = (mul_522 + mul_646);
			double pow_658 = safepow(pow_307, add_608);
			double mul_664 = (read_626 * pow_658);
			double add_670 = (mul_550 + mul_664);
			double mul_676 = (read_634 * pow_567);
			double add_682 = (mul_561 + mul_676);
			double pow_688 = safepow(pow_307, add_618);
			double mul_694 = (read_630 * pow_688);
			double add_700 = (mul_588 + mul_694);
			double mul_705 = (spread * 0.125541);
			double add_710 = (mul_705 + 369);
			double sub_716 = (add_454 - add_710);
			double mul_722 = (int_444 * sub_716);
			double read_726 = delay_226.read_linear(mul_722);
			double mul_731 = (div_315 * 0.110732);
			double read_735 = delay_227.read_linear(mul_731);
			double mul_740 = (spread * -0.568366);
			double add_745 = (mul_740 + 369);
			double sub_751 = (add_479 - add_745);
			double mul_757 = (int_444 * sub_751);
			double read_761 = delay_228.read_linear(mul_757);
			double add_766 = (mul_705 + 159);
			double mul_772 = (int_444 * add_766);
			double read_776 = delay_229.read_linear(mul_772);
			double mul_781 = (read_726 * 0.625);
			double mul_786 = (read_735 * 0.75);
			double sub_792 = (mix_292 - mul_786);
			double mul_797 = (sub_792 * 0.75);
			double add_803 = (mul_797 + read_735);
			double add_808 = (mul_740 + 159);
			double mul_814 = (int_444 * add_808);
			double read_818 = delay_230.read_linear(mul_814);
			double mul_823 = (read_761 * 0.625);
			double mul_828 = (read_776 * 0.75);
			double mul_833 = (read_818 * 0.75);
			double mul_839 = (mul_522 * tail);
			double mul_845 = (mul_588 * tail);
			double add_851 = (mul_839 + mul_845);
			double mul_857 = (mul_550 * tail);
			double mul_863 = (mul_561 * tail);
			double add_869 = (mul_857 + mul_863);
			double sub_875 = (add_851 - add_869);
			double mul_881 = (mul_646 * early);
			double mul_887 = (mul_694 * early);
			double add_893 = (mul_881 + mul_887);
			double mul_899 = (mul_664 * early);
			double mul_905 = (mul_676 * early);
			double add_911 = (mul_899 + mul_905);
			double sub_917 = (add_893 - add_911);
			double add_923 = (sub_875 + sub_917);
			double add_929 = (add_923 + in1);
			double sub_935 = (add_929 - mul_828);
			double mul_940 = (sub_935 * 0.75);
			double add_946 = (mul_940 + read_776);
			double sub_952 = (add_946 - mul_781);
			double mul_957 = (sub_952 * 0.625);
			double add_963 = (mul_957 + read_726);
			double sub_969 = (add_963 - mul_499);
			double mul_974 = (sub_969 * 0.625);
			double add_980 = (mul_974 + read_469);
			double add_986 = (mul_265 + add_980);
			double out1 = add_986;
			double add_993 = (add_923 + in2);
			double sub_999 = (add_993 - mul_833);
			double mul_1004 = (sub_999 * 0.75);
			double add_1010 = (mul_1004 + read_818);
			double sub_1016 = (add_1010 - mul_823);
			double mul_1021 = (sub_1016 * 0.625);
			double add_1027 = (mul_1021 + read_761);
			double sub_1033 = (add_1027 - mul_572);
			double mul_1038 = (sub_1033 * 0.625);
			double add_1044 = (mul_1038 + read_494);
			double add_1050 = (mul_276 + add_1044);
			double out2 = add_1050;
			double out_1056 = mix_292;
			double out_1060 = mix_345;
			double out_1064 = mix_375;
			double out_1068 = mix_405;
			double out_1072 = mix_435;
			delay_219.write(add_652);
			delay_220.write(add_670);
			delay_221.write(add_682);
			delay_222.write(add_700);
			delay_223.write(sub_969);
			delay_224.write(sub_1033);
			delay_225.write(add_803);
			delay_226.write(sub_952);
			delay_227.write(sub_792);
			delay_228.write(sub_1016);
			delay_229.write(sub_935);
			delay_230.write(sub_999);
			history_207 = out_1056;
			history_204 = out_1060;
			history_71 = out_1064;
			history_47 = out_1068;
			history_59 = out_1072;
			delay_227.step();
			delay_225.step();
			delay_219.step();
			delay_230.step();
			delay_226.step();
			delay_222.step();
			delay_224.step();
			delay_223.step();
			delay_221.step();
			delay_228.step();
			delay_229.step();
			delay_220.step();
			*(__out1++) = out1;
			*(__out2++) = out2;
			
		}
		
	}
	inline void set_damping(double __value){
		damping = ((__value <= 0) ? 0 : (__value >= 1) ? 1 : __value);
		
	}
	inline void set_dry(double __value){
		dry = ((__value <= 0) ? 0 : (__value >= 1) ? 1 : __value);
		
	}
	inline void set_history_47(double __value){
		history_47 = __value;
		
	}
	inline void set_tail(double __value){
		tail = ((__value <= 0) ? 0 : (__value >= 1) ? 1 : __value);
		
	}
	inline void set_history_204(double __value){
		history_204 = __value;
		
	}
	inline void set_bandwidth(double __value){
		bandwidth = ((__value <= 0) ? 0 : (__value >= 1) ? 1 : __value);
		
	}
	inline void set_revtime(double __value){
		revtime = ((__value < 0.1) ? 0.1 : __value);
		
	}
	inline void set_early(double __value){
		early = ((__value <= 0) ? 0 : (__value >= 1) ? 1 : __value);
		
	}
	inline void set_roomsize(double __value){
		roomsize = ((__value <= 0.1) ? 0.1 : (__value >= 300) ? 300 : __value);
		
	}
	inline void set_history_59(double __value){
		history_59 = __value;
		
	}
	inline void set_history_207(double __value){
		history_207 = __value;
		
	}
	inline void set_history_71(double __value){
		history_71 = __value;
		
	}
	inline void set_spread(double __value){
		spread = ((__value <= 0) ? 0 : (__value >= 100) ? 100 : __value);
		
	}
	
};
*/