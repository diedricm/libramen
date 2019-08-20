#include "stream_debug_output_unit.h"

int main (int argc, char ** argv) {
	ap_uint<512> memory[1024];
	for (int i = 0; i < 1024; i++) {
		memory[i] = 0;
	}

	hls::stream<vaxis_single> in;
	hls::stream<vaxis_single> out;

	vaxis_single tmp;
	tmp.user = 3;
	tmp.dest = 0;
	tmp.data.tag = 0x01;
	tmp.data.value = 0x33;
	in << tmp;

	tmp.data.tag = 0x02;
	tmp.data.value = 0xFF << 6;
	in << tmp;

	tmp.data.tag = 0x03;
	tmp.data.value = 0xFF;
	in << tmp;

	tmp.data.tag = 0x00;
	tmp.data.value = 0x01;
	in << tmp;

	for (int i = 0; i < 0xFF; i++) {
		tmp.data.tag = i;
		tmp.data.value = i;
		in << tmp;
	}

	stream_debug_output_unit(memory, in, out);

	while (!out.empty()) {
		std::cout << out.read() << std::endl;
	}

	for (int i = 0; i < 1024; i++) {
		std::cout << memory[i] << std::endl;
	}
}
