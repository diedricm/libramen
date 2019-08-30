#include "libramen.h"

#define CHAN_CNT_LOG2 4
#define CHAN_CNT (1 << CHAN_CNT_LOG2)
#define OUTPUT_STREAM_CNT 4

void select_processor(
		hls::stream<flit_quad> & input_stream,
		hls::stream<flit_single> & output_stream0,
		hls::stream<flit_single> & output_stream1,
		hls::stream<flit_single> & output_stream2,
		hls::stream<flit_single> & output_stream3
	) {



}

void row_align (
		hls::stream<flit_quad> & input_stream,
		hls::stream<flit_quad> & output_stream
	) {

#pragma HLS PIPELINE

	static bool chan_active[CHAN_CNT] = {};
	static ap_uint<16> tuple_index[CHAN_CNT];
	static ap_uint<16> tuple_index_last[CHAN_CNT];
	static tuple remainder_buffer[CHAN_CNT][3];
	static ap_uint<2> remainder_buffer_valid[CHAN_CNT];

	flit_quad input_buffer = input_stream.read();
	ap_uint<CHAN_CNT_LOG2> cdest = input_buffer.dest.range(CHAN_CNT_LOG2-1, 0);

	if (!chan_active[cdest]) {
		if (get_tag(input_buffer, 0) == 0) {
			//activate chan
			chan_active[cdest] = true;
			tuple_index[cdest] = 0;
			remainder_buffer_valid[cdest] = 0;
			output_stream.write_nb(input_buffer);
		} else if (get_tag(input_buffer, 0) == 3) {
			//set tuples_per_row reg
			tuple_index_last[cdest] = get_value(input_buffer, 0).range(15, 0);
		} else {
			//other reg writes are just forwarded
			output_stream.write_nb(input_buffer);
		}
	} else {
		flit_quad output_buffer;
		int new_read = 0;
		for (int i = 0; i < 4; i++) {
			if (remainder_buffer_valid[cdest] > 0) {
				output_buffer
				remainder_buffer_valid[cdest]--;
			} else {

			}

		}

		if (TLAST_MASK_IS_HARDEND(input_buffer))
			chan_active[cdest] = false;
	}
}

void digger_st_unit (
		hls::stream<flit_quad> & input_stream,
		hls::stream<flit_single> & output_stream0,
		hls::stream<flit_single> & output_stream1,
		hls::stream<flit_single> & output_stream2,
		hls::stream<flit_single> & output_stream3
	) {
#pragma HLS INTERFACE ap_ctrl_none port=return

#pragma HLS DATAFLOW

	hls::stream<flit_quad> forward_stream;
#pragma HLS STREAM variable=forward_stream depth=1 dim=1

	row_align(input_stream, forward_stream);

	select_processor(forward_stream, output_stream0, output_stream1, output_stream2, output_stream3);
}
