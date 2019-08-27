#ifndef STORE_UNIT_H_
#define STORE_UNIT_H_

#include "libramen.h"

#define PORT_CNT (16)
#define PORT_ID_LEN (4)
#define BLOCK_SIZE_IN_BITS (512)
#define BLOCK_SIZE_IN_BYTE (BLOCK_SIZE_IN_BITS / 8)
#define BLOCK_SIZE_IN_TUPLE_VALS (BLOCK_SIZE_IN_BYTE / 8)
#define BUFFER_ADDR_LEN (12)
#define MEM_SIZE_IN_BYTE (1 << 34) //16 GB
#define MEM_SIZE_IN_BLOCKS (MEM_SIZE_IN_BYTE / BLOCK_SIZE_IN_BYTE) //Arrrgh this is 2^34/(512/8)=268435456

#define START_REG_ADDR 0x0
#define RETURN_CDEST_REG_ADDR 0x1
#define BUFFER_BASE_REG_ADDR 0x3
#define TUPLE_ITERATOR_REG_ADDR 0x4
#define TUPLE_BUFFER_HIGH_REG_ADDR 0x5

struct buffer_read_req {
	ap_uint<PORT_ID_LEN> port_id;
	ap_uint<BUFFER_ADDR_LEN> req_tuples;
};

void store_unit_hls(
		hls::stream<flit_quad> & input,
		hls::stream<flit_quad> & output,
		hls::stream<buffer_read_req> & stream_chan_req,
		ap_uint<BLOCK_SIZE_IN_BITS>* memory_if,
		ap_uint<PORT_CNT*BUFFER_ADDR_LEN> buffer_fill_levels
		);

#endif//STORE_UNIT_H_
