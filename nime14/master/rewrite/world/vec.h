#include <cfloat>
#include <cmath>

#ifndef M_E
#define M_E			2.71828182845904523536028747135266250
#endif
#ifndef M_LOG2E
#define M_LOG2E		1.44269504088896340735992468100189214
#endif
#ifndef M_LOG10E
#define M_LOG10E	0.434294481903251827651128918916605082
#endif
#ifndef M_LN2
#define M_LN2		0.693147180559945309417232121458176568
#endif
#ifndef M_LN10
#define M_LN10		2.30258509299404568401799145468436421
#endif
#ifndef M_PI
#define M_PI		3.14159265358979323846264338327950288
#endif
#ifndef M_PI_2
#define M_PI_2		1.57079632679489661923132169163975144
#endif
#ifndef M_PI_4
#define M_PI_4		0.785398163397448309615660845819875721
#endif
#ifndef M_1_PI
#define M_1_PI		0.318309886183790671537767526745028724
#endif
#ifndef M_2_PI
#define M_2_PI		0.636619772367581343075535053490057448
#endif
#ifndef M_2_SQRTPI
#define M_2_SQRTPI	1.12837916709551257389615890312154517
#endif
#ifndef M_SQRT2
#define M_SQRT2		1.41421356237309504880168872420969808
#endif
#ifndef M_SQRT1_2
#define M_SQRT1_2	0.707106781186547524400844362104849039
#endif
#ifndef M_DEG2RAD
#define M_DEG2RAD	0.017453292519943
#endif
#ifndef M_RAD2DEG
#define M_RAD2DEG	57.295779513082
#endif

// Some other useful constants
#ifndef M_2PI
#define M_2PI		6.283185307179586231941716828464095101		// 2pi
#endif
#ifndef M_4PI
#define M_4PI		12.566370614359172463937643765552465425		// 4pi
#endif
#ifndef M_1_2PI
#define M_1_2PI		0.159154943091895345554011992339482617		// 1/(2pi)
#endif
#ifndef M_3PI_2
#define M_3PI_2		4.712388980384689673996945202816277742		// 3pi/2
#endif
#ifndef M_3PI_4
#define M_3PI_4		2.356194490192343282632028017564707056		// 3pi/4
#endif
#ifndef M_LN001		
#define M_LN001		-6.90775527898								// ln(0.001)
#endif
#ifndef M_SQRT_1_3	
#define	M_SQRT_1_3	0.577350269189626							// sqrt(1./3);
#endif

template<class T> inline T nextAfter(const T& x, const T& y){ return x<y ? x+1 : x-1; }
//template<> inline float nextAfter(const float& x, const float& y){ return nextafterf(x,y); }
template<> inline float nextAfter(const float& x, const float& y){ return x > y ? x - FLT_EPSILON : x + FLT_EPSILON; }
template<> inline double nextAfter(const double& x, const double& y){ return nextafter(x,y); }
template<> inline long double nextAfter(const long double& x, const long double& y){ return nextafterl(x,y); }

template<class T> T wrap(const T& v, const T& hi=T(1), const T& lo=T(0)) {
	if(lo == hi) return lo;
	T R = v;
	T diff = hi - lo;
	if(R >= hi){		
		R -= diff;
		if(R >= hi) R -= diff * uint32_t((R - lo)/diff);
	}
	else if(R < lo){
		R += diff;
		// If value is very slightly less than 'lo', then less significant 
		// digits might get truncated by adding a larger number.
		if(R==diff) return nextAfter(R, lo);
		if(R < lo) R += diff * uint32_t(((lo - R)/diff) + 1);
		if(R==diff) return lo;
	}
	return R;
}

template<typename T=double>
struct Vec3 {
	union {
		T x, y, z;
		T data[3];
	};
	
	Vec3(const T& v=T()){ set(v); }
	Vec3(const T& v1, const T& v2, const T& v3){ set(v1, v2, v3); }
	
	Vec3& set(const T& v1) { x=v1; y=v1; z=v1; return *this; }
	Vec3& set(const T& v1, const T& v2, const T& v3){ x=v1; y=v2; z=v3; return *this; }
	
	#define IT for(int i=0; i<3; ++i)
	template <class T2>
	Vec3& set(const Vec3<T2> &v){ IT { (*this)[i] = T(v[i]); } return *this; }
	
	// array indexing:
	T& operator[](int i){ return data[i];}
	const T& operator[](int i) const { return data[i]; }
	
	Vec3& operator  =(const Vec3& v){ return set(v); }
	Vec3& operator  =(const    T& v){ return set(v); }
	Vec3& operator +=(const Vec3& v){ IT (*this)[i] += v[i]; return *this; }
	Vec3& operator +=(const    T& v){ IT (*this)[i] += v;    return *this; }
	Vec3& operator -=(const Vec3& v){ IT (*this)[i] -= v[i]; return *this; }
	Vec3& operator -=(const    T& v){ IT (*this)[i] -= v;    return *this; }
	Vec3& operator *=(const Vec3& v){ IT (*this)[i] *= v[i]; return *this; }
	Vec3& operator *=(const    T& v){ IT (*this)[i] *= v;    return *this; }
	Vec3& operator /=(const Vec3& v){ IT (*this)[i] /= v[i]; return *this; }
	Vec3& operator /=(const    T& v){ IT (*this)[i] /= v;    return *this; }
	Vec3 operator + (const Vec3& v) const { return Vec3(*this) += v; }
	Vec3 operator + (const    T& v) const { return Vec3(*this) += v; }
	Vec3 operator - (const Vec3& v) const { return Vec3(*this) -= v; }
	Vec3 operator - (const    T& v) const { return Vec3(*this) -= v; }
	Vec3 operator * (const Vec3& v) const { return Vec3(*this) *= v; }
	Vec3 operator * (const    T& v) const { return Vec3(*this) *= v; }
	Vec3 operator / (const Vec3& v) const { return Vec3(*this) /= v; }
	Vec3 operator / (const    T& v) const { return Vec3(*this) /= v; }
	Vec3 operator - () const { return Vec3(*this).negate(); }
	
	T dot(const Vec3& v) const {
		T r = T(0);
		IT r += (*this)[i] * v[i]; 
		return r;
	}
	
	T mag() const { return std::sqrt(magSqr()); }
	T magSqr() const { return dot(*this); }

	
	#undef IT
};

// Non-member binary arithmetic operations
template<class T>
inline Vec3<T> operator + (const T& s, const Vec3<T>& v){ return  v+s; }
template<class T>
inline Vec3<T> operator - (const T& s, const Vec3<T>& v){ return -v+s; }
template<class T>
inline Vec3<T> operator * (const T& s, const Vec3<T>& v){ return  v*s; }
template<class T>
inline Vec3<T> operator / (const T& s, const Vec3<T>& v){ return  v/s; }

template<typename T=double>
struct Vec4 {
	union {
		T x, y, z, w;
		T data[4];
	};
	
	Vec4(const T& v=T()){ set(v); }
	Vec4(const T& v1, const T& v2, const T& v3, const T& v4){ set(v1, v2, v3, v4); }
	
	Vec4& set(const T& v1) { x=v1; y=v1; z=v1; w=v1; return (*this); }
	Vec4& set(const T& v1, const T& v2, const T& v3, const T& v4){ x=v1; y=v2; z=v3; w=v4; return (*this); }
	#define IT for(int i=0; i<4; ++i)
	template <class T2>
	Vec4& set(const Vec4<T2> &v){ IT { (*this)[i] = T(v[i]); } return *this; }
	
	// array indexing:
	T& operator[](int i){ return data[i];}
	const T& operator[](int i) const { return data[i]; }
	
	Vec4& operator  =(const Vec4& v){ return set(v); }
	Vec4& operator  =(const    T& v){ return set(v); }
	Vec4& operator +=(const Vec4& v){ IT (*this)[i] += v[i]; return *this; }
	Vec4& operator +=(const    T& v){ IT (*this)[i] += v;    return *this; }
	Vec4& operator -=(const Vec4& v){ IT (*this)[i] -= v[i]; return *this; }
	Vec4& operator -=(const    T& v){ IT (*this)[i] -= v;    return *this; }
	Vec4& operator *=(const Vec4& v){ IT (*this)[i] *= v[i]; return *this; }
	Vec4& operator *=(const    T& v){ IT (*this)[i] *= v;    return *this; }
	Vec4& operator /=(const Vec4& v){ IT (*this)[i] /= v[i]; return *this; }
	Vec4& operator /=(const    T& v){ IT (*this)[i] /= v;    return *this; }
	Vec4 operator + (const Vec4& v) const { return Vec4(*this) += v; }
	Vec4 operator + (const    T& v) const { return Vec4(*this) += v; }
	Vec4 operator - (const Vec4& v) const { return Vec4(*this) -= v; }
	Vec4 operator - (const    T& v) const { return Vec4(*this) -= v; }
	Vec4 operator * (const Vec4& v) const { return Vec4(*this) *= v; }
	Vec4 operator * (const    T& v) const { return Vec4(*this) *= v; }
	Vec4 operator / (const Vec4& v) const { return Vec4(*this) /= v; }
	Vec4 operator / (const    T& v) const { return Vec4(*this) /= v; }
	Vec4 operator - () const { return Vec4(*this).negate(); }
	
	T dot(const Vec4& v) const {
		T r = T(0);
		IT r += (*this)[i] * v[i]; 
		return r;
	}
	
	T mag() const { return std::sqrt(magSqr()); }
	T magSqr() const { return dot(*this); }

	
	#undef IT
};

// Non-member binary arithmetic operations
template<class T>
inline Vec4<T> operator + (const T& s, const Vec4<T>& v){ return  v+s; }
template<class T>
inline Vec4<T> operator - (const T& s, const Vec4<T>& v){ return -v+s; }
template<class T>
inline Vec4<T> operator * (const T& s, const Vec4<T>& v){ return  v*s; }
template<class T>
inline Vec4<T> operator / (const T& s, const Vec4<T>& v){ return  v/s; }


template<typename T=double>
struct Quat {
	union {
		T x, y, z, w;
		T data[3];
	};
	
	Quat(){ set(0, 0, 0, 1); }
	Quat(const T& v1, const T& v2, const T& v3, const T& v4){ set(v1, v2, v3, v4); }
	
	Quat& set(const T& v1) { x=v1; y=v1; z=v1; w=v1; return (*this); }
	Quat& set(const T& v1, const T& v2, const T& v3, const T& v4){ x=v1; y=v2; z=v3; w=v4; return (*this); }
	
	template <class U>
	Quat& set(const Quat<U>& q){ return set(q.w, q.x, q.y, q.z); }
	Quat& setIdentity(){ return (*this) = Quat::identity(); }
	
	#define IT for(int i=0; i<4; ++i)
	
	Quat operator * (const Quat& v) const { return Quat(*this)*=v; }
	Quat operator * (const    T& v) const { return Quat(*this)*=v; }
	Quat& operator *=(const Quat& v){ return set(multiply(v)); }
	Quat& operator *=(const    T& v){ w*=  v; x*=  v; y*=  v; z*=  v; return *this; }
	
	Quat conj() const { return Quat(w, -x, -y, -z); }
	Quat recip() const { return conj()/magSqr(); }
	Quat inverse() const { return sgn().conj(); }
	Quat sgn() const { return Quat(*this).normalize(); }
	
	T dot(const Quat& v) const { return w*v.w + x*v.x + y*v.y + z*v.z; }
	T mag() const { return (T)sqrt(magSqr()); }
	T magSqr() const { return dot(*this); }
	
	Quat& normalize() {
		T unit = magSqr();
		if(unit*unit < eps()){
			// unit too close to epsilon, set to default transform
			setIdentity();
		}
		else if(unit > accuracyMax() || unit < accuracyMin()){
			(*this) *= 1./sqrt(unit);
		}
		return *this;
	}
	
	Quat multiply(const Quat& q) const {
		return Quat(
			w*q.w - x*q.x - y*q.y - z*q.z,
			w*q.x + x*q.w + y*q.z - z*q.y,
			w*q.y + y*q.w + z*q.x - x*q.z,
			w*q.z + z*q.w + x*q.y - y*q.x
		);
	}
	Quat reverseMultiply(const Quat& q) const { return q * (*this); };
	
	
	Quat& fromEuler(const Vec3<T>& aed) { return fromEuler(aed[0], aed[1], aed[2]); }
	Quat& fromEuler(const T& az, const T& el, const T& ba) {
		T c1 = cos(az * T(0.5));
		T c2 = cos(el * T(0.5));
		T c3 = cos(ba * T(0.5));
		T s1 = sin(az * T(0.5));
		T s2 = sin(el * T(0.5));
		T s3 = sin(ba * T(0.5));
		// equiv Q1 = Qy * Qx; // since many terms are zero
		T tw = c1*c2;
		T tx = c1*s2;
		T ty = s1*c2;
		T tz =-s1*s2;
		// equiv Q2 = Q1 * Qz; // since many terms are zero
		w = tw*c3 - tz*s3;
		x = tx*c3 + ty*s3;
		y = ty*c3 - tx*s3;
		z = tw*s3 + tz*c3;
		return *this;
	}
	
	// array indexing:
	T& operator[](int i){ return data[i];}
	const T& operator[](int i) const { return data[i]; }
	
	template <class U>
	Quat& operator  =(const Quat<U>& v){ return set(v); }
	Quat& operator  =(const    T& v){ return set(v); }
	
	static T accuracyMax(){ return 1.000001; }
	static T accuracyMin(){ return 0.999999; }
	static T eps(){ return 0.0000001; }
	static Quat identity(){ return Quat(0,0,0,1); }
	
	#undef IT
};

typedef Vec3<double> vec3;
typedef Vec3<float> vec3f;
typedef Vec4<double> vec4;
typedef Vec4<float> vec4f;
typedef Quat<double> quat;
typedef Quat<float> quatf;
