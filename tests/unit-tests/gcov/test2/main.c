#include <stdio.h>
#include "bsp.h"

const int buf_size = 100;

void funB(int *buf, int b) {
	for (int i = 0; i < buf_size; i++) {
		buf[i] -= b;
	}
}

void funA(int *buf, int b) {
	for (int i = 0; i < buf_size; i++) {
		buf[i] += b;
	}
}

void buf_increment_all(int *buf) {
	for (int i = 0; i < buf_size; i++) {
		buf[i] += 1;
	}
}

int main() {
	int buf[buf_size];
	for (int i = 0; i < buf_size; i++) {
		buf[i] = i;
	}

	buf_increment_all(buf);

	for (int i = 0; i < buf_size; i++) {
		if (buf[i] % 3 == 0) {
			funA(buf, i);
		}
		if (buf[i] % 5 == 0) {
			funB(buf, i);
		}
	}

	buf_increment_all(buf);

	return 0;
}
