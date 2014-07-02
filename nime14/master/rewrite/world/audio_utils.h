#ifndef AUDIO_UTILS_H
#define AUDIO_UTILS_H

#include "stdlib.h"
#include "string.h"
#include "math.h"

#define IS_NAN_DOUBLE(v)			(((((unsigned long *)&(v))[1])&0x7fe00000)==0x7fe00000) 
#define FIX_NAN_DOUBLE(v)			((v)=IS_NAN_DOUBLE(v)?0.:(v))

inline double fixnan(double v) { return FIX_NAN_DOUBLE(v); }

inline unsigned long next_power_of_two(unsigned long v) {
    v--;
    v |= v >> 1;
    v |= v >> 2;
    v |= v >> 4;
    v |= v >> 8;
    v |= v >> 16;
    v |= v >> 32;
    v++;
    return v;
}

// 4.5%
inline double phasewrap(double val) {
	static const double pi = 3.14159265358979323846264338327950288;
	static const double twopi = 6.28318530717958647692;
	static const double oneovertwopi = 0.159154943091895;
	if (val>= twopi || val <= twopi) {
		double d = val * oneovertwopi;	//multiply faster
		d = d - (long)d;
		val = d * twopi;
	}	
	if (val > pi) val -= twopi;
	if (val < -pi) val += twopi;
	return val;
}

/// 8th order Taylor series approximation to a cosine.
/// r must be in [-pi, pi].
// 6%
inline double cosT8(double r) {
	static const double t84 = 56.;
	static const double t83 = 1680.;
	static const double t82 = 20160.;
	static const double t81 = 2.4801587302e-05;
	static const double t73 = 42.;
	static const double t72 = 840.;
	static const double t71 = 1.9841269841e-04;
	static const double pi_over_4 = 0.785398163397448309615660845819875721;
	static const double pi_over_2 = 1.57079632679489661923132169163975144;
	if(r < pi_over_4 && r > -pi_over_4){
		double rr = r*r;
		return 1. - rr * t81 * (t82 - rr * (t83 - rr * (t84 - rr)));
	}
	else if(r > 0.){
		r -= pi_over_2;
		double rr = r*r;
		return -r * (1. - t71 * rr * (t72 - rr * (t73 - rr)));
	}
	else{
		r += pi_over_2;
		double rr = r*r;
		return r * (1. - t71 * rr * (t72 - rr * (t73 - rr)));
	}
}

// 10%
inline double cosT8_safe(double r) { return cosT8(phasewrap(r)); }

// linear interpolation (similar as mix)
template<typename T>
inline T linear_interp(double a, const T& x, const T& y) {
	return x+a*(y-x); 
}

// cosine interpolation
inline double cosine_interp(double a, double x, double y) {
	const double a2 = (1.-cosT8_safe(a*3.14159265358979323846264338327950288))/2.;
	return(x*(1.-a2)+y*a2);
}

// cubic interpolation
inline double cubic_interp(double a, double w, double x, double y, double z) {
	const double a2 = a*a;
	const double f0 = z - y - w + x;
	const double f1 = w - x - f0;
	const double f2 = y - w;
	const double f3 = x;
	return(f0*a*a2 + f1*a2 + f2*a + f3);
}

// 60%
// Breeuwsma catmull-rom spline interpolation
// slightly faster than three alternatives tried
inline double spline_interp(double a, double w, double x, double y, double z) {
	const double a2 = a*a;
	const double f0 = -0.5*w + 1.5*x - 1.5*y + 0.5*z;
	const double f1 = w - 2.5*x + 2*y - 0.5*z;
	const double f2 = -0.5*w + 0.5*y;
	return(f0*a*a2 + f1*a2 + f2*a + x);
}

// min(x,y) returns y if y < x, otherwise it returns x
inline double minimum(double x, double y) { return (y<x?y:x); }

// max(x,y) returns y if y > x, otherwise it returns x
inline double maximum(double x, double y) { return (x<y?y:x); }

// clamp(x,minVal, maxVal) min (max (x, minVal), maxVal)
inline double clamp(double x, double minVal, double maxVal) { return minimum(maximum(x,minVal),maxVal); }

// taken from modulo~.c
// with if(m) replaced by epsilon check
inline double safemod(double f, double m) {
	//if (m) {
	if (m > __DBL_EPSILON__ || m < -__DBL_EPSILON__) {
		if (m<0) 
			m = -m; // modulus needs to be absolute value		
		if (f>=m) {
			if (f>=(m*2.)) {
				double d = f / m;
				d = d - (long) d;
				f = d * m;
			} 
			else {
				f -= m;
			}
		} 
		else if (f<=(-m)) {
			if (f<=(-m*2.)) {
				double d = f / m;
				d = d - (long) d;
				f = d * m;
			}
			 else {
				f += m;
			}
		}
	} else {
		f = 0.0; //don't divide by zero
	}
	return f;
}

inline double safediv(double num, double denom) {
	return denom == 0. ? 0. : num/denom;
}

// fixnan for case of negative base and non-integer exponent:
inline double safepow(double base, double exponent) {
	return fixnan(pow(base, exponent));
}


struct Delay {
	double * memory;
	long size, wrap, maxdelay;
	long reader, writer;
	
	Delay() : memory(0) {
		size = wrap = maxdelay = 0;
		reader = writer = 0;
		memory = 0;
	}
	~Delay() {
		free(memory);
	}
	
	inline void reset(long d) {
		// if needed, acquire the Data's global reference: 
		if (memory == 0) {
		
			// scale maxdelay to next highest power of 2:
			maxdelay = d;
			size = maximum(maxdelay,2);
			size = next_power_of_two(size);
			
			memory = (double *)malloc(size * sizeof(double));
		
		} else {
		
			// subsequent reset should zero the memory & heads:
			memset(memory, 0, size * sizeof(double));
			writer = 0;
		}
		
		reader = writer;
		wrap = size-1;
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

// scale is like inverse far, so 1/32 creates a bigger world than 1/4
// amplitude drops to 50% at distance == (1/scale + near)
inline double attenuate(double d, double near, double scale) {
	double x = (d - near) * scale;
	if (x > 0.) {
		double xc = x + 4;
		double x1 = xc / (x*x + xc);
		return x1 * x1;
	}
	return 1.;
}

#endif