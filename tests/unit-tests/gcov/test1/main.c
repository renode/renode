#include <stdio.h>
#include "bsp.h"

const int buf_size = 100;
const int max = 10;

void buf_increment_all(int *buf) {
	for (int i = 0; i < buf_size; i++) {
		buf[i] += 1;
	}
}

int main() {
	int buf[buf_size];
	int a = 0;
	int found_something = -1;
	for (int i = 0; i < max && i < buf_size; i++) {
		a += i;
		buf[i] = a;
	}

	buf_increment_all(buf);

	for (int i = 0; i < max && i < buf_size; i++) {
		if (buf[i] == a) {
			found_something = i;
		}
	}

	while(1) {}
}

