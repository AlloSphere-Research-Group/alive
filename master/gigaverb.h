#ifndef ALIVE_GIGAVERB_H
#define ALIVE_GIGAVERB_H

#include "audio_utils.h"

struct Gigaverb {
	
	double damping;
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
	
	inline void perform(float * __in1, float * __out1, float * __out2, int __n){
		while ((__n--)){
			const double in1 = *__in1++;
			const double sub_270 = (1 - bandwidth);
			// pre filter:
			const double mul_284 = (in1 * 0.707);
			const double mix_292 = (mul_284+sub_270*((history_207)-(mul_284)));
			
			const double mul_305 = (revtime * 44100);
			const double div_306 = safediv(1, mul_305);
			const double pow_307 = safepow(0.001, div_306);
			const double mul_313 = (roomsize * 44100);
			const double div_315 = safediv(mul_313, 340);
			const double mul_320 = (div_315 * 1);
			const double read_324 = delay_219.read_linear(mul_320);
			const double pow_330 = safepow(pow_307, mul_320);
			const double neg_331 = (-(pow_330));
			const double mul_337 = (read_324 * neg_331);
			const double mix_345 = (mul_337+damping*((history_204)-(mul_337)));
			const double mul_350 = (div_315 * 0.81649);
			const double read_354 = delay_220.read_linear(mul_350);
			const double pow_360 = safepow(pow_307, mul_350);
			const double neg_361 = (-(pow_360));
			const double mul_367 = (read_354 * neg_361);
			const double mix_375 = (mul_367+damping*((history_71)-(mul_367)));
			const double mul_380 = (div_315 * 0.63245);
			const double read_384 = delay_221.read_linear(mul_380);
			const double pow_390 = safepow(pow_307, mul_380);
			const double neg_391 = (-(pow_390));
			const double mul_397 = (read_384 * neg_391);
			const double mix_405 = (mul_397+damping*((history_47)-(mul_397)));
			const double mul_410 = (div_315 * 0.7071);
			const double read_414 = delay_222.read_linear(mul_410);
			const double pow_420 = safepow(pow_307, mul_410);
			const double neg_421 = (-(pow_420));
			const double mul_427 = (read_414 * neg_421);
			const double mix_435 = (mul_427+damping*((history_59)-(mul_427)));
			const double mul_440 = (div_315 * 0.000527);
			const int int_444 = int(mul_440);
			const double mul_449 = (spread * 0.376623);
			const double add_454 = (mul_449 + 931);
			const double sub_459 = (1341 - add_454);
			const double mul_465 = (int_444 * sub_459);
			const double read_469 = delay_223.read_linear(mul_465);
			const double mul_474 = (spread * -0.380445);
			const double add_479 = (mul_474 + 931);
			const double sub_484 = (1341 - add_479);
			const double mul_490 = (int_444 * sub_484);
			const double read_494 = delay_224.read_linear(mul_490);
			const double mul_499 = (read_469 * 0.625);
			const double add_505 = (mix_345 + mix_375);
			const double add_511 = (mix_435 + mix_405);
			const double sub_517 = (add_505 - add_511);
			const double mul_522 = (sub_517 * 0.5);
			const double add_527 = (div_315 + 5);
			const double sub_533 = (mix_345 - mix_375);
			const double sub_539 = (mix_435 - mix_405);
			const double sub_545 = (sub_533 - sub_539);
			const double mul_550 = (sub_545 * 0.5);
			const double add_556 = (add_505 + add_511);
			const double mul_561 = (add_556 * 0.5);
			const double pow_567 = safepow(pow_307, add_527);
			const double mul_572 = (read_494 * 0.625);
			const double add_578 = (sub_533 + sub_539);
			const double sub_583 = (- add_578);
			const double mul_588 = (sub_583 * 0.5);
			const double mul_593 = (div_315 * 0.41);
			const double add_598 = (mul_593 + 5);
			const double mul_603 = (div_315 * 0.3);
			const double add_608 = (mul_603 + 5);
			const double mul_613 = (div_315 * 0.155);
			const double add_618 = (mul_613 + 5);
			const double read_622 = delay_225.read_linear(add_598);
			const double read_626 = delay_225.read_linear(add_608);
			const double read_630 = delay_225.read_linear(add_618);
			const double read_634 = delay_225.read_linear(add_527);
			const double pow_640 = safepow(pow_307, add_598);
			const double mul_646 = (read_622 * pow_640);
			const double add_652 = (mul_522 + mul_646);
			const double pow_658 = safepow(pow_307, add_608);
			const double mul_664 = (read_626 * pow_658);
			const double add_670 = (mul_550 + mul_664);
			const double mul_676 = (read_634 * pow_567);
			const double add_682 = (mul_561 + mul_676);
			const double pow_688 = safepow(pow_307, add_618);
			const double mul_694 = (read_630 * pow_688);
			const double add_700 = (mul_588 + mul_694);
			const double mul_705 = (spread * 0.125541);
			const double add_710 = (mul_705 + 369);
			const double sub_716 = (add_454 - add_710);
			const double mul_722 = (int_444 * sub_716);
			const double read_726 = delay_226.read_linear(mul_722);
			const double mul_731 = (div_315 * 0.110732);
			const double read_735 = delay_227.read_linear(mul_731);
			const double mul_740 = (spread * -0.568366);
			const double add_745 = (mul_740 + 369);
			const double sub_751 = (add_479 - add_745);
			const double mul_757 = (int_444 * sub_751);
			const double read_761 = delay_228.read_linear(mul_757);
			const double add_766 = (mul_705 + 159);
			const double mul_772 = (int_444 * add_766);
			const double read_776 = delay_229.read_linear(mul_772);
			const double mul_781 = (read_726 * 0.625);
			const double mul_786 = (read_735 * 0.75);
			const double sub_792 = (mix_292 - mul_786);
			const double mul_797 = (sub_792 * 0.75);
			const double add_803 = (mul_797 + read_735);
			const double add_808 = (mul_740 + 159);
			const double mul_814 = (int_444 * add_808);
			const double read_818 = delay_230.read_linear(mul_814);
			const double mul_823 = (read_761 * 0.625);
			const double mul_828 = (read_776 * 0.75);
			const double mul_833 = (read_818 * 0.75);
			const double mul_839 = (mul_522 * tail);
			const double mul_845 = (mul_588 * tail);
			const double add_851 = (mul_839 + mul_845);
			const double mul_857 = (mul_550 * tail);
			const double mul_863 = (mul_561 * tail);
			const double add_869 = (mul_857 + mul_863);
			const double sub_875 = (add_851 - add_869);
			const double mul_881 = (mul_646 * early);
			const double mul_887 = (mul_694 * early);
			const double add_893 = (mul_881 + mul_887);
			const double mul_899 = (mul_664 * early);
			const double mul_905 = (mul_676 * early);
			const double add_911 = (mul_899 + mul_905);
			const double sub_917 = (add_893 - add_911);
			const double add_923 = (sub_875 + sub_917);
			
			// final mixing:
			const double add_929 = (add_923 + in1);
			
			const double sub_935 = (add_929 - mul_828);
			const double mul_940 = (sub_935 * 0.75);
			const double add_946 = (mul_940 + read_776);
			const double sub_952 = (add_946 - mul_781);
			const double mul_957 = (sub_952 * 0.625);
			const double add_963 = (mul_957 + read_726);
			const double sub_969 = (add_963 - mul_499);
			const double mul_974 = (sub_969 * 0.625);
			const double out1 = (mul_974 + read_469);
			
			const double sub_999 = (add_929 - mul_833);
			const double mul_1004 = (sub_999 * 0.75);
			const double add_1010 = (mul_1004 + read_818);
			const double sub_1016 = (add_1010 - mul_823);
			const double mul_1021 = (sub_1016 * 0.625);
			const double add_1027 = (mul_1021 + read_761);
			const double sub_1033 = (add_1027 - mul_572);
			const double mul_1038 = (sub_1033 * 0.625);
			const double out2 = (mul_1038 + read_494);
			
			// delay updates:
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
			
			// history feedback:
			const double out_1056 = mix_292;
			const double out_1060 = mix_345;
			const double out_1064 = mix_375;
			const double out_1068 = mix_405;
			const double out_1072 = mix_435;
			history_207 = out_1056;
			history_204 = out_1060;
			history_71 = out_1064;
			history_47 = out_1068;
			history_59 = out_1072;
			
			// output:
			*(__out1++) += out1;
			*(__out2++) += out2;
			
		}
		
	}
	inline void set_damping(double __value){
		damping = ((__value <= 0) ? 0 : (__value >= 1) ? 1 : __value);
		
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

#endif // ALIVE_GIGAVERB_H