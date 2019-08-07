#include "vaxis.h"

void output_func(
		hls::stream<vaxis_single> & output,
		vaxis_quad tmp,
		ap_uint<4> index,
		ap_uint<4> valid_tuples
		) {
#pragma HLS LATENCY max=0

	if (index <= valid_tuples) {
		vaxis_single output_tmp;
		output_tmp.data.value = tmp.data.value[index];
		output_tmp.data.tag = tmp.data.tag[index];
		output_tmp.dest = tmp.dest;
		if (index != valid_tuples) {
			output_tmp.last = 0;
			output_tmp.user = VAXIS_TLAST_MASK_SOFTEND;
		} else {
			output_tmp.last = tmp.last;
			if (index == 3) {
				output_tmp.user = VAXIS_TLAST_MASK_SOFTEND;
			} else {
				output_tmp.user = VAXIS_TLAST_MASK_HARDEND_0INVALID;
			}
		}
		output.write(output_tmp);
	}
}

void vaxis_quad_to_single(
		hls::stream<vaxis_quad> & input,
		hls::stream<vaxis_single> & output
		) {
#pragma HLS INTERFACE ap_ctrl_none port=return
#pragma HLS INTERFACE axis register both port=output
#pragma HLS INTERFACE axis register both port=input

#pragma HLS PIPELINE II=1

	vaxis_quad tmp = input.read();
	ap_uint<5> valid_tuples = 8-(tmp.user%8);

#pragma HLS INLINE region

	output_func(output, tmp, 0, valid_tuples);
	output_func(output, tmp, 1, valid_tuples);
	output_func(output, tmp, 2, valid_tuples);
	output_func(output, tmp, 3, valid_tuples);

}
