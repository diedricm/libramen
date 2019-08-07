#include "axi4lite_stream_conf.h"

int main (int argc,  char ** argv) {
	hls::stream<vaxis_single> in;
	hls::stream<vaxis_single> out;

	vaxis_single tmp;
	tmp.dest = 0;
	tmp.user = 3;

	axi4lite_stream_conf(CREATE_AXI4LSTREAM_INSTRUCTION(0, 0x100, 1), 0x101,  0, in, out);
	axi4lite_stream_conf(CREATE_AXI4LSTREAM_INSTRUCTION(0, 0x100, 2), 0x102,  0, in, out);
	axi4lite_stream_conf(CREATE_AXI4LSTREAM_INSTRUCTION(1, 0x100, 3), 0,  0xF0F0F0F00F0F0F0F, in, out);


	axi4lite_stream_conf(CREATE_AXI4LSTREAM_INSTRUCTION(2, 0x100, 0), 1, 0, in, out);
	axi4lite_stream_conf(CREATE_AXI4LSTREAM_INSTRUCTION(2, 0x200, 0), 1, 0, in, out);

	tmp.data.value = 0;
	tmp.data.tag = 0;
	in << tmp;

	tmp.data.value = 0x2;
	in << tmp;

	tmp.data.value = 0x1;
	in << tmp;

	tmp.data.value = 0x3;
	in << tmp;

	axi4lite_stream_conf(CREATE_AXI4LSTREAM_INSTRUCTION(3, 0x300, 0), 1, 0, in, out);

	while (!out.empty()) {
		out >> tmp;
		std::cout << tmp << std::endl;
	}
	std::cout << "Nothing should follow this line!" << std::endl;
	while (!in.empty()) {
		in >> tmp;
		std::cout << tmp << std::endl;
	}
}
