#ifndef STREAM_DEBUG_OUTPUT_UNIT_H_
#define STREAM_DEBUG_OUTPUT_UNIT_H_

#include "vaxis.h"

/*
Stream Debug Output Unit
Description:
After configuration this unit will record the
values on its in channel and store
them in the assigned global memory buffer.
Vaxis transactions are stored with 16 Byte
alignment.


Virtual transformer subnetmask:
XX_XXXX_XXXX_XXXX
1 virtual transformer

Configuration regmap:
0x00 - transmission cookie (8b)
0x01 - cookie return addr (14b)
0x02 - buffer offset (64b)
0x03 - sample count (32b)
*/

void stream_debug_output_unit(
		ap_uint<512> *memory,
		hls::stream<vaxis_single> & in,
		hls::stream<vaxis_single> & out
		);

#endif //STREAM_DEBUG_OUTPUT_UNIT_H_
