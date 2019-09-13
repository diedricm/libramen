#include "store_unit.h"

struct regslot {
	bool active;
	ap_uint<64> buffer_base;     // in blocks
	ap_uint<32> buffer_iterator; // in tuples
	ap_uint<32> buffer_length;   // in tuples
	ap_uint<14> return_addr;
	ap_uint<8>  return_value;
};


unsigned get_valid_tuple_cnt(flit_single sflit) {
	if (sflit.user == TLAST_MASK_SOFTEND)
		return 1;
	else
		return 0;
}

unsigned get_valid_tuple_cnt(flit_quad qflit) {
	if ((qflit.user == TLAST_MASK_SOFTEND_NO_DATA) || (qflit.user == TLAST_MASK_HARDEND_NO_DATA))
		return 0;

	if (qflit.user == TLAST_MASK_SOFTEND)
		return 4;

	return 4 - (qflit.user - 4);
}

bool is_tuple_valid(flit_quad qflit, unsigned index) {
	return get_valid_tuple_cnt(qflit) > index;
}

void store_loop(
		hls::stream<ap_uint<BLOCK_SIZE_IN_BITS> > & stream_data_buffer,
		ap_uint<BLOCK_SIZE_IN_BITS>* memory_if,
		regslot regentry,
		ap_uint<BUFFER_ADDR_LEN> block_write_count
		) {

	for (int i = 0; i < block_write_count; i++) {
#pragma HLS PIPELINE
		memory_if[regentry.buffer_base + (regentry.buffer_iterator/BLOCK_SIZE_IN_TUPLE_VALS) + i] = stream_data_buffer.read();
	}

	if (!stream_data_buffer.empty()) {
		memory_if[regentry.buffer_base + (regentry.buffer_length / BLOCK_SIZE_IN_TUPLE_VALS)] = stream_data_buffer.read();
	}
}

ap_int<32> store_stream_convert(
		hls::stream<flit_quad> & stream_in,
		hls::stream<flit_quad> & output,
		hls::stream<ap_uint<BLOCK_SIZE_IN_BITS/2> > & stream_data_buffer,
		ap_uint<BUFFER_ADDR_LEN> block_write_count,
		regslot regentry,
		bool fills_buffer
		) {
//#pragma HLS DATA_PACK variable=stream_in

	bool circuit_terminated = false;
	ap_int<32> new_buffer_index = regentry.buffer_iterator;

	blockloop: for (int i = 0; i < block_write_count; i++) {

		qupleloop: for (int j = 0; j < BLOCK_SIZE_IN_TUPLE_VALS/4; j++) {
#pragma HLS PIPELINE
//#pragma HLS LATENCY max=0

			ap_uint<64> internal_trn_block[4];
	#pragma HLS ARRAY_RESHAPE variable=internal_trn_block complete dim=1

			if ((fills_buffer && (i == (block_write_count - 1))) || circuit_terminated) {
				tupleloop0: for (int h = 0; h < 4; h++) {
#pragma HLS LOOP_UNROLL
					internal_trn_block[h] = block_write_count;
				}
			} else {
				flit_quad tmp = stream_in.read();

				new_buffer_index += get_valid_tuple_cnt(tmp);
				if (!is_tuple_valid(tmp, 3)) {
					circuit_terminated = true;
				}

				tupleloop1: for (int h = 0; h < 4; h++) {
#pragma HLS LOOP_UNROLL
					internal_trn_block[h] = get_value(tmp, h);
				}
			}

			stream_data_buffer.write((internal_trn_block[0], internal_trn_block[1], internal_trn_block[2], internal_trn_block[3]));
		}
	}

	if (circuit_terminated) {
		stream_data_buffer.write(new_buffer_index);
		stream_data_buffer.write(new_buffer_index);

		flit_quad result;
		result.dest = regentry.return_addr;
		result.last = 1;
		result.user = TLAST_MASK_HARDEND_3INVALID;
		set_value(result, regentry.return_value, 0);
		set_tag(result, 0, 0);
		output.write(result);
	}

	std::cout << "new_buffer_index0 " << new_buffer_index << std::endl;

	return new_buffer_index;
}

void upsize(
		hls::stream<ap_uint<BLOCK_SIZE_IN_BITS/2> > & stream_data_buffer_half,
		hls::stream<ap_uint<BLOCK_SIZE_IN_BITS> > & stream_data_buffer,
		ap_uint<BUFFER_ADDR_LEN> block_write_count
		) {

	for (int i = 0; i < block_write_count; i++) {
		ap_uint<BLOCK_SIZE_IN_BITS/2> A = stream_data_buffer_half.read();
		ap_uint<BLOCK_SIZE_IN_BITS/2> B = stream_data_buffer_half.read();
		stream_data_buffer.write((A, B));
	}
}

void compute_write_length(
		regslot regentry,
		ap_uint<BUFFER_ADDR_LEN> free_credits_in_buffer,
		ap_uint<BUFFER_ADDR_LEN> & block_write_count,
		bool & fills_buffer
		) {

	ap_uint<BUFFER_ADDR_LEN> full_credits_in_buffer = (1 << BUFFER_ADDR_LEN) - 1 - free_credits_in_buffer;
	ap_uint<BUFFER_ADDR_LEN> present_block_count = ((full_credits_in_buffer * 4) + BLOCK_SIZE_IN_TUPLE_VALS - 1) / BLOCK_SIZE_IN_TUPLE_VALS;

	if (regentry.buffer_iterator + present_block_count * BLOCK_SIZE_IN_TUPLE_VALS >= regentry.buffer_length) {
		present_block_count = (regentry.buffer_length - regentry.buffer_iterator + BLOCK_SIZE_IN_TUPLE_VALS - 1) / BLOCK_SIZE_IN_TUPLE_VALS;
		fills_buffer = true;
	} else {
		fills_buffer = false;
	}
	block_write_count = present_block_count;
}

ap_int<32> store_unit_hls (
		hls::stream<flit_quad> & stream_in,
		hls::stream<flit_quad> & output,
		ap_uint<BLOCK_SIZE_IN_BITS>* memory_if,
		ap_uint<BUFFER_ADDR_LEN> free_credits_in_buffer,
		regslot regentry
		) {
#pragma HLS INTERFACE axis register both port=stream_in
#pragma HLS INTERFACE axis register both port=output
#pragma HLS INTERFACE m_axi depth=268435456 port=memory_if offset=off num_read_outstanding=0 max_write_burst_length=64 max_read_burst_length=2

#pragma HLS DATAFLOW

	ap_uint<BUFFER_ADDR_LEN> block_write_count;
	bool fills_buffer;

	hls::stream<ap_uint<BLOCK_SIZE_IN_BITS/2> > stream_data_buffer_half;
#pragma HLS RESOURCE variable=stream_data_buffer_half core=FIFO_LUTRAM
#pragma HLS STREAM variable=stream_data_buffer depth=4 dim=1

	hls::stream<ap_uint<BLOCK_SIZE_IN_BITS> > stream_data_buffer;
#pragma HLS RESOURCE variable=stream_data_buffer core=FIFO_LUTRAM
#pragma HLS STREAM variable=stream_data_buffer depth=4 dim=1

	compute_write_length(regentry, free_credits_in_buffer, block_write_count, fills_buffer);

	ap_int<32> tmp = store_stream_convert(stream_in, output, stream_data_buffer_half, block_write_count, regentry, fills_buffer);

	upsize(stream_data_buffer_half, stream_data_buffer, block_write_count);

	store_loop(stream_data_buffer, memory_if, regentry, block_write_count);

	return tmp;
}
