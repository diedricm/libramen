#include <ap_int.h>
#include <ap_axi_sdata.h>
#include <hls_stream.h>
#include "vaxis.h"

void axi4lite_stream_conf(
		unsigned instruction,
		unsigned scalar,
		unsigned long memptr,
		hls::stream<vaxis_single> &in_stream,
		hls::stream<vaxis_single> &out_stream
		) {
#pragma HLS INTERFACE s_axilite port=return
#pragma HLS INTERFACE axis register both port=out_stream
#pragma HLS INTERFACE axis register both port=in_stream
#pragma HLS INTERFACE s_axilite port=memptr offset=0x20
#pragma HLS INTERFACE s_axilite port=scalar offset=0x18
#pragma HLS INTERFACE s_axilite port=instruction offset=0x10

	ap_uint<32> instruction_base = instruction;

	static ap_uint<8> wait_counter = 0;
	static ap_uint<1> read_reqs[256] = {};

	//WRITE COMMAND
	vaxis_single result;
	result.user = 3;
	result.dest = instruction_base.range(29, 16);
	result.data.tag  = instruction_base.range(15, 0);

	switch (instruction_base.range(31, 30)) {
	case 0:
		//SCALAR ARG
		result.data.value = scalar;
		break;

	case 1:
		//MEMORY ARG
		result.data.value = memptr;
		break;

	default:
		ap_uint<8> trans_cookie;
		if ((scalar % 2) == 1)
			trans_cookie = ++wait_counter;
		else
			trans_cookie = 0;
		result.data.value = trans_cookie;
		read_reqs[trans_cookie] = 1;
	}
	out_stream << result;


	if ((instruction_base.range(31, 30) == 3) || (wait_counter == 255)) {
		while (wait_counter > 0) {
			for (int i = 0; i < 256; i++) {
				std::cout << read_reqs[i] << " ";
			}
			std::cout << std::endl;
			std::cout << wait_counter << std::endl << std::endl;
			vaxis_single buffer;
			in_stream >> buffer;
			ap_uint<8> return_cookie =  buffer.data.value.range(7, 0);

			if  (read_reqs[return_cookie] == 1) {
				wait_counter--;
				read_reqs[return_cookie] = 0;
			}
		}
	}

}
