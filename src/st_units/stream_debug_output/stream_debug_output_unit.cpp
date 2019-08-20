#include "stream_debug_output_unit.h"

void stream_debug_output_unit(
		ap_uint<512> *memory,
		hls::stream<vaxis_single> & in,
		hls::stream<vaxis_single> & out
		) {
#pragma HLS INTERFACE ap_ctrl_none port=return
#pragma HLS INTERFACE axis register both port=out
#pragma HLS INTERFACE axis register both port=in
#pragma HLS INTERFACE m_axi depth=100 port=memory max_write_burst_length=64
	
#ifdef __SYNTHESIS__
	while (true) {
#endif
	
		ap_uint<64> memptr_offset = 0;
		ap_uint<32> sample_count = 0;
		vaxis_single return_cookie;
		return_cookie.user = 3;
		return_cookie.data.tag = 0;
		return_cookie.data.value = 0;
		
		bool init_finished = false;
		while (!init_finished) {
			vaxis_single tmp;
			in >> tmp;

			switch ((tmp.data.tag % 4)) {
			case 0:
				return_cookie.data.value.range(7, 0) = tmp.data.value.range(7, 0);
				init_finished = true;
				break;
			case 1:
				return_cookie.dest = tmp.data.value.range(13, 0);
				break;
			case 2:
				memptr_offset = (tmp.data.value >> 6);
				break;
			case 3:
				sample_count = tmp.data.value.range(31, 0);
				break;
			}
		}

		ap_uint<128> buffer_slots[4] = {};
		ap_uint<64> iter = 0;
		for (unsigned i = 0; i < sample_count; i++) {
#pragma HLS PIPELINE

			vaxis_single tmp;
			in >> tmp;
			ap_uint<64+32+16> result;
			result.range(13, 0) = tmp.dest;
			result.range(15, 14) = tmp.user;
			result.range(47, 16) = tmp.data.tag;
			result.range(111, 48) = tmp.data.value;


			buffer_slots[i%4].range(111, 0) = result;
	
			if ((i%4) == 3) {
				ap_uint<512> out_buffer = ((buffer_slots[0], buffer_slots[1]), (buffer_slots[2], buffer_slots[3]));
				memory[memptr_offset + iter] = out_buffer;
				iter++;
			}
		}
	
		out << return_cookie;
#ifdef __SYNTHESIS__
	}
#endif
}
