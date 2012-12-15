#ifndef ALIVE_Q_H
#define ALIVE_Q_H

//////////////////////////////////////////////////////////////////////////////////

/*
	Since the audio thread clears the queue so much faster, 
	the main bottleneck is how many pending messages per frame,
	and how much the audiolag adds to this.
	
	To deal with clock drift, use the audio clock for the main thread time
	(audio time plus audiolag)
	but a backup is needed if the audio thread is inactive
		
	Another problem is how to cache messages if overflow occurs.
	A brief sleep is tried first, but then fall back to a heap queue?
		Check if audio is still active?
*/
template<typename T>
struct Q {
	T * q;
	int size, wrap;
	volatile int read, write;
	
	Q(int count = 16384) {
		size = count;
		wrap = size - 1;
		q = (T *)malloc(sizeof(T) * size);
		memset(q, 0, sizeof(q));
		read = write = 0;
	}
	
	~Q() {
		free(q);
	}
	
	// sender thread:
	T * head() const {
		if (read == ((write + 1) & wrap)) {
			// try sleeping a little bit first:
			al_sleep(0.01);
			if (read == ((write + 1) & wrap)) {
				printf("queue overflow, cannot send\n");
				return 0;
			}
		}
		return &q[write];
	}
	void send() { write = (write + 1) & wrap; }

	// receiver thread:
	T * peek() const {
		return read == write ? 0 : &q[read];
	}
	void next() {
		read = (read + 1) & wrap;
	}
	
	double used() const {
		printf("%d %d\n", read, write);
		return ((size + write - read) & wrap)/double(size);
	}
};


////////////////////////////////////////////////////////////////////////////////

#endif