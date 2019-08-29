#include "libramen.h"

#define PORT_CNT (16)
#define PORT_ID_LEN (4)
#define BLOCK_SIZE_IN_BITS (512)
#define BLOCK_SIZE_IN_BYTE (BLOCK_SIZE_IN_BITS / 8)
#define BLOCK_SIZE_IN_TUPLE_VALS (BLOCK_SIZE_IN_BYTE / 8)
#define BUFFER_ADDR_LEN (7)
#define MEM_SIZE_IN_BYTE (1 << 34) //16 GB
#define MEM_SIZE_IN_BLOCKS (MEM_SIZE_IN_BYTE / BLOCK_SIZE_IN_BYTE) //Arrrgh this is 2^34/(512/8)=268435456

void block_load(
		ap_uint<BLOCK_SIZE_IN_BITS>* memory_if,
		ap_uint<64> read_start,
		ap_uint<32> read_count,
		hls::stream<ap_uint<BLOCK_SIZE_IN_BITS> > & to_next
		) {
	for (int i = 0; i < read_count; i++) {
#pragma HLS PIPELINE

		to_next.write(memory_if[read_start + i]);
	}
}

void stream_format(
		hls::stream<ap_uint<BLOCK_SIZE_IN_BITS> > & input,
		ap_uint<32> read_count,
		ap_uint<32> tuple_base,
		ap_uint<32> tuple_high,
		hls::stream<flit_quad> & output
		) {

	for (int i = 0; i < read_count; i++) {
#pragma HLS LOOP_TRIPCOUNT min=1 max=64
#pragma HLS PIPELINE II=2

		ap_uint<BLOCK_SIZE_IN_BITS> tmp_buffer = input.read();
		ap_uint<64> buffer[2][4];
#pragma HLS ARRAY_RESHAPE variable=buffer complete

		for (int x = 0; x < 8; x++) {
#pragma HLS UNROLL
			buffer[x/4][x%4] = tmp_buffer.range((x+1)*64-1, x*64);
		}

		for (int j = 0; j < 2; j++) {
#pragma HLS PIPELINE

			int valid_tuples = 0;

			flit_quad result;
			result.last = 0;
			result.dest = 0;

			for (int x = 0; x < 4; x++) {
				result.data.tag[(x)] = tuple_base;
				result.data.value[(x)] = buffer[j][x];
				if (tuple_base <= tuple_high)
					valid_tuples++;
				tuple_base++;
			}

			if (valid_tuples == 4) {
				if (tuple_base == tuple_high)
					result.user = TLAST_MASK_HARDEND_0INVALID;
				else
					result.user = TLAST_MASK_SOFTEND;
			} else if (valid_tuples == 0) {
				result.user = TLAST_MASK_SOFTEND_NO_DATA;
			} else {
				result.user = TLAST_MASK_HARDEND_NINVALID(4-valid_tuples);
			}

			output.write(result);
		}
	}
}

void dataflow_container(
		ap_uint<BLOCK_SIZE_IN_BITS>* memory_if,
		ap_uint<64> read_start,
		ap_uint<32> read_count,
		ap_uint<32> tuple_base,
		ap_uint<32> tuple_high,
		hls::stream<flit_quad> & output
		) {

#pragma HLS DATAFLOW

	hls::stream<ap_uint<BLOCK_SIZE_IN_BITS> > trn;
#pragma HLS RESOURCE variable=trn core=FIFO_LUTRAM
#pragma HLS STREAM variable=trn depth=32 dim=1

	block_load(memory_if, read_start, read_count, trn);

	stream_format(trn, read_count, tuple_base, tuple_high, output);
}

ap_uint<32> my_min ( ap_uint<32> A, ap_uint<32> B) {
	if (A < B)
		return A;
	else
		return B;
}

void load_unit_hls(
		hls::stream<flit_quad> & output,
		ap_uint<BLOCK_SIZE_IN_BITS>* memory_if,
		ap_uint<64> buffer_base,
		ap_uint<32> tuple_base,
		ap_uint<32> tuple_high,
		ap_uint<32> tuple_free,
		ap_uint<32>* new_tuple_base
		) {
#pragma HLS INTERFACE ap_none port=buffer_base
#pragma HLS INTERFACE ap_none port=tuple_base
#pragma HLS INTERFACE ap_none port=tuple_high
#pragma HLS INTERFACE ap_none port=tuple_free
#pragma HLS INTERFACE ap_vld  port=new_tuple_base
#pragma HLS INTERFACE axis register both port=output
#pragma HLS INTERFACE m_axi depth=268435456 port=memory_if offset=off num_write_outstanding=0 max_read_burst_length=64 max_write_burst_length=2

	//convert from byte to block array index and add to block converted tbase
	ap_uint<64> new_base = (buffer_base / 64) + (tuple_base / 8);

	ap_uint<32> readable_tuples = my_min(tuple_free, tuple_high - tuple_base);
	//round up
	ap_uint<32> readable_blocks = (readable_tuples + 7) / 8;

	dataflow_container(memory_if, new_base, readable_blocks, tuple_base, tuple_high, output);

	*new_tuple_base =  readable_blocks * 8;
}
