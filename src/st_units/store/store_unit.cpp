#include "libramen.h"

#define PORT_CNT (16)
#define PORT_ID_LEN (4)
#define BLOCK_SIZE_IN_BITS (512)
#define BLOCK_SIZE_IN_BYTE (BLOCK_SIZE_IN_BITS / 8)
#define BLOCK_SIZE_IN_QTUPLE_VALS (BLOCK_SIZE_IN_BYTE / 8 / 4)
#define BUFFER_ADDR_LEN (12)
#define MEM_SIZE_IN_BYTE (1 << 34) //16 GB
#define MEM_SIZE_IN_BLOCKS (MEM_SIZE_IN_BYTE / BLOCK_SIZE_IN_BYTE) //Arrrgh this is 2^34/(512/8)=268435456

struct regslot {
	bool active;
	ap_uint<64> buffer_base;
	ap_uint<32> buffer_iterator_in_tuples;
	ap_uint<32> buffer_length_in_blocks;
	ap_uint<14> return_addr;
	ap_uint<8>  return_value;
};

struct buffer_read_req {
	ap_uint<PORT_ID_LEN> port_id;
	ap_uint<BUFFER_ADDR_LEN> req_tuples;
};

void store_loop(
		hls::stream<ap_uint<BLOCK_SIZE_IN_BITS> > & stream_data_buffer,
		ap_uint<BLOCK_SIZE_IN_BITS>* memory_if,
		ap_uint<64> buffer_base,
		ap_uint<32> buffer_index,
		ap_uint<BUFFER_ADDR_LEN> block_write_count
		) {

	for (int i = 0; i < block_write_count; i++) {
#pragma HLS PIPELINE
		memory_if[buffer_base + i] = stream_data_buffer.read();
	}

}

bool store_stream_convert(
		hls::stream<flit_quad> & stream_in,
		hls::stream<ap_uint<BLOCK_SIZE_IN_BITS> > & stream_data_buffer,
		ap_uint<BUFFER_ADDR_LEN> block_write_count,
		ap_uint<BUFFER_ADDR_LEN> quadtuple_write_count,
		ap_uint<32> buffer_index,
		bool fills_buffer
		) {

	for (int i = 0; i < block_write_count; i++) {
		ap_uint<64> merge_buffer[BLOCK_SIZE_IN_QTUPLE_VALS][4];

		for (int j = 0; j < BLOCK_SIZE_IN_QTUPLE_VALS; j++) {
			flit_quad tmp;
			if ((fills_buffer && block_write_count == 1) || (quadtuple_write_count == 0)) {
				for (int h = 0; h < 4; h++)
					tmp.data.value[h] = buffer_index;
			} else {
				tmp = stream_in.read();
			}


		}
	}

}

bool store_dataflow_region(
		hls::stream<flit_quad> & stream_in,
		ap_uint<BLOCK_SIZE_IN_BITS>* memory_if,
		ap_uint<64> buffer_base,
		ap_uint<32> buffer_index,
		ap_uint<BUFFER_ADDR_LEN> block_write_count,
		ap_uint<BUFFER_ADDR_LEN> quadtuple_write_count,
		bool fills_buffer
		) {

#pragma HLS DATAFLOW

	hls::stream<ap_uint<BLOCK_SIZE_IN_BITS> > stream_data_buffer;
#pragma HLS STREAM variable=stream_data_buffer depth=1 dim=1

	bool tmp = store_stream_convert(stream_in, stream_data_buffer, block_write_count, quadtuple_write_count, buffer_index, fills_buffer);

	store_loop(stream_data_buffer, memory_if, buffer_base, buffer_index, block_write_count);

	return tmp;
}

void store_unit_hls(
		hls::stream<flit_quad> & input,
		hls::stream<flit_quad> & output,
		hls::stream<buffer_read_req> & stream_chan_req,
		ap_uint<BLOCK_SIZE_IN_BITS>* memory_if,
		ap_uint<PORT_CNT*BUFFER_ADDR_LEN> buffer_fill_levels
		) {
#pragma HLS INTERFACE ap_vld port=block_req_count
#pragma HLS INTERFACE ap_vld port=buffer_base
#pragma HLS INTERFACE axis register both port=input
#pragma HLS INTERFACE m_axi depth=268435456 port=memory_if offset=off num_read_outstanding=0 max_write_burst_length=64 max_read_burst_length=2

	static regslot regfile[PORT_CNT] = {
			.active = false,
			.buffer_pointer = 0,
			.buffer_length_in_blocks = 0,
			.return_addr = 0,
			.return_value = 0
	};

	bool any_port_full = false;
	ap_uint<PORT_CNT> most_full_port;
	ap_uint<BUFFER_ADDR_LEN> most_full_fill_level = 0;
	bool port_is_conf;
	for (int i = 0; i < PORT_CNT; i++) {
		ap_uint<BUFFER_ADDR_LEN> inport_fill_level = buffer_fill_levels.range((i+1)*BUFFER_ADDR_LEN-1, i*BUFFER_ADDR_LEN);

		//register read
		if (!regfile[i].active) {
			if (inport_fill_level > 0) {
				any_port_full = true;
				most_full_port = i;
				most_full_fill_level = inport_fill_level;
				port_is_conf = true;
			}
		} else if (regfile[i].buffer_iterator < regfile[i].buffer_length_in_blocks && !port_is_conf) {
			any_port_full = true;
			most_full_port = i;
			most_full_fill_level = inport_fill_level;
		}
	}

	if (any_port_full) {
		if (port_is_conf) {
			//PORT CONF
			buffer_read_req tmp;
			tmp.port_id = most_full_port;
			tmp.req_tuples = 1;
			stream_chan_req.write(tmp);

			flit_quad reg_pack = input.read();
			ap_uint<PORT_CNT> regconf_dest = reg_pack.data.tag[0].range(31, 16);
			ap_uint<3> regconf_regaddr = reg_pack.data.tag[0].range(15, 0);

			switch (regconf_regaddr) {
			case 0:
				regfile[most_full_port].return_value = reg_pack.data.value[0].range(7, 0);
				regfile[most_full_port].active = true;
				break;

			case 1:
				regfile[most_full_port].return_addr = reg_pack.data.value[0].range(13, 0);
				break;

			case 3:
				regfile[most_full_port].buffer_base = reg_pack.data.value[0] >> 6;
				break;

			case 4:
				regfile[most_full_port].buffer_iterator = reg_pack.data.value[0].range(31, 0);
				break;

			case 5:
				regfile[most_full_port].buffer_length_in_blocks = reg_pack.data.value[0].range(31, 0);
				break;
			}

		} else {

			//BUFFER WRITE
			bool fills_buffer = false;
			ap_uint<BUFFER_ADDR_LEN> present_block_count = (most_full_fill_level + BLOCK_SIZE_IN_QTUPLE_VALS - 1) / BLOCK_SIZE_IN_QTUPLE_VALS;
			if (regfile[most_full_port].buffer_iterator + present_block_count >= regfile[most_full_port].buffer_length_in_blocks) {
				present_block_count = regfile[most_full_port].buffer_length_in_blocks - regfile[most_full_port].buffer_iterator;
				fills_buffer = true;
			}

			buffer_read_req tmp;
			tmp.port_id = most_full_port;
			tmp.req_tuples = present_block_count * BLOCK_SIZE_IN_QTUPLE_VALS;
			stream_chan_req.write(tmp);

			bool circuit_terminated = store_dataflow_region(input, memory_if, regfile[most_full_port].buffer_base, regfile[most_full_port].buffer_iterator, present_block_count, fills_buffer, most_full_fill_level);

			regfile[most_full_port].buffer_iterator += present_block_count;

			if (fills_buffer || circuit_terminated) {
				flit_quad result;
				result.dest = regfile[most_full_port].return_addr;
				result.last = 1;
				result.user = TLAST_MASK_HARDEND_3INVALID;
				result.data.value[0] = regfile[most_full_port].return_value;
				result.data.tag[0] = 0;
				output.write(result);

				regfile[most_full_port].active = false;
			}
		}
	}

	return;
}
