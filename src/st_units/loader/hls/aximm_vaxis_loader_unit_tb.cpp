#include "aximm_vaxis_loader_unit.h"

#define BASE_ADDR 0xFF

int main (int argc, char ** argv) {

	ap_uint<512> aximem[1024];
	for (int i = 0; i < 32; i++) {
		ap_uint<512> tmp;
		for (int j = 0; j < 8; j++) {
			tmp.range(64*(j+1)-1, 64*j) = i*8 + j;
		}
		aximem[BASE_ADDR + i] = tmp;
	}

	hls::stream<vaxis_single> config_in;
	vaxis_single tmp = {};
	tmp.data.tag = 0x1;
	tmp.data.value = 0x333;
	config_in << tmp;

	tmp.data.tag = 0x2;
	tmp.data.value = BASE_ADDR << 6;
	config_in << tmp;

	tmp.data.tag = 0x3;
	tmp.data.value = 0xFF;
	config_in << tmp;

	tmp.data.tag = 0x4;
	tmp.data.value = 0x0;
	config_in << tmp;

	tmp.data.tag = 0x6;
	tmp.data.value = 0xCA;
	config_in << tmp;

	tmp.data.tag = 0x0;
	tmp.data.value = 0xAA;
	tmp.last = 0x1;
	config_in << tmp;

	tmp.data.tag = 0x5;
	tmp.data.value = 0x100;
	tmp.last = 0x1;
	config_in << tmp;

	hls::stream<vaxis_quad> output;

	aximm_vaxis_loader_unit(aximem, config_in, output);

	vaxis_quad result;
	while (!output.empty())
		std::cout << output.read() << std::endl;

	return 0;
}
