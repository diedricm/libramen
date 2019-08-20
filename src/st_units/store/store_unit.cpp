#include "libramen.h"

#define PORT_CNT (16)
#define PORT_ID_LEN (4)
#define BLOCK_SIZE_IN_BITS (512)
#define BLOCK_SIZE_IN_BYTE (BLOCK_SIZE_IN_BITS / 8)
#define BLOCK_SIZE_IN_TUPLE_VALS (BLOCK_SIZE_IN_BYTE / 8)
#define BUFFER_ADDR_LEN (7)
#define MEM_SIZE_IN_BYTE (1 << 34) //16 GB
#define MEM_SIZE_IN_BLOCKS (MEM_SIZE_IN_BYTE / BLOCK_SIZE_IN_BYTE) //Arrrgh this is 2^34/(512/8)=268435456

void store_unit_hls(
		hls::stream<ap_uint<BLOCK_SIZE_IN_BITS> > input,
		ap_uint<BLOCK_SIZE_IN_BITS>* memory_if,
		ap_uint<64> buffer_base,
		ap_uint<16> block_req_count
		) {
#pragma HLS INTERFACE ap_vld port=block_req_count
#pragma HLS INTERFACE ap_vld port=buffer_base
#pragma HLS INTERFACE axis register both port=input
#pragma HLS INTERFACE m_axi depth=268435456 port=memory_if offset=off num_read_outstanding=0 max_write_burst_length=64 max_read_burst_length=2

	for (int i = 0; i < block_req_count; i++) {
#pragma HLS PIPELINE

		memory_if[buffer_base + i] = input.read();
	}
}
