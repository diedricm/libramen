#ifndef AXIMM_VAXIS_LOADER_UNIT_H_
#define AXIMM_VAXIS_LOADER_UNIT_H_

#include "vaxis.h"

/*
AXI-MM to VAXIS Loader Unit
Description:
This is the bus interface part of the
axi-mm loader unit that feeds into the input
FIFO. Upon starting a channel the unit will load
[Buffer length (0x3)] Bytes from the bus
and store them in a FIFO. A circut is terminated
if [Tag index (0x4)] == [Tag index of last flit (0x5)].



Virtual transformer subnetmask:
XX_XXXX_XXXX_NNNN
1-16 virtual transformers

Configuration regmap:
0x00 - Transmission cookie		(tstart)(08b)
0x01 - Cookie return tdest		(scalar)(14b)
0x02 - Buffer pointer in BYTE	(buffer)(64b)
0x03 - Buffer length in BYTE	(scalar)(32b)
0x04 - Tag index				(scalar)(32b)
0x05 - Tag index of last flit	(scalar)(32b)
0x06 - Stream tdest				(scalar)(14b)
*/

#define VAXIS_SUBNET_SUFFIX_LENGTH 4
#define VAXIS_PORT_COUNT (1 << VAXIS_SUBNET_SUFFIX_LENGTH)
#define BURSTLENGTH_IN_BITS 8192
#define BURSTLENGTH_IN_BLOCK (BURSTLENGTH_IN_BITS/512)
#define BURSTLENGTH_IN_TUPLES (BURSTLENGTH_IN_BITS/VAXIS_VALUE_SIZE)
#define BLOCKLENGTH_IN_TUPLES (512/VAXIS_VALUE_SIZE)
#define MEMORYDEPTH_PER_PORT_LOG2 9

struct core_data_cell {
	ap_uint<8> return_cookie;
	ap_uint<14> return_dest;
	ap_uint<64> buffer_base_addr;		//of 512 bit buffer
	ap_uint<32> buffer_length;			//of 512 bit buffer
	ap_uint<32> tuple_tag_index;		//of tuple
	ap_uint<32> tuple_tag_last_index;	//of tuple
	ap_uint<14> stream_dest;
};

void aximm_vaxis_loader_unit(
		ap_uint<512> * aximem,
		hls::stream<vaxis_single> & config_in,
		hls::stream<vaxis_quad> & output
		);

#endif //AXIMM_VAXIS_LOADER_UNIT_H_
