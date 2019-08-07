#include <cstring>
#include "aximm_vaxis_loader_unit.h"

void core_config (core_data_cell * confdata, bool * active, vaxis_single conf_command) {
	ap_uint<VAXIS_SUBNET_SUFFIX_LENGTH> vaxis_port = conf_command.dest.range(VAXIS_SUBNET_SUFFIX_LENGTH-1, 0);

	switch (conf_command.data.tag) {
	case 0:
		confdata[vaxis_port].return_cookie = conf_command.data.value.range(8-1, 0);
		active[vaxis_port] = true;
		break;

	case 1:
		confdata[vaxis_port].return_dest = conf_command.data.value.range(14-1, 0);
		break;

	case 2:
		confdata[vaxis_port].buffer_base_addr = conf_command.data.value >> 6;
		break;

	case 3:
		confdata[vaxis_port].buffer_length = conf_command.data.value.range(32-1, 0) >> 6;
		break;

	case 4:
		confdata[vaxis_port].tuple_tag_index = conf_command.data.value.range(32-1, 0);
		break;

	case 5:
		confdata[vaxis_port].tuple_tag_last_index = conf_command.data.value.range(32-1, 0);
		break;

	case 6:
		confdata[vaxis_port].stream_dest = conf_command.data.value.range(14-1, 0);
		break;

	default:
		std::cerr << "aximm_vaxis_loader_unit(): core(): Invalid conf register " << conf_command.data.tag << std::endl;
		break;
	}
}

void fifo_send(
		hls::stream< ap_uint<512> > & input,
		core_data_cell vaxis_port_data,
		ap_uint<32> readable_blocks,
		unsigned port_id,
		hls::stream<vaxis_quad_ext_usr> & output
		) {

	bool disable_channel = false;
	vaxis_quad_ext_usr result;
	result.user.range(6 , 3) = port_id;

	output_to_stream: for (int i = 0; i < readable_blocks; i++) {
#pragma HLS LOOP_TRIPCOUNT min=0 max=64 avg=64
#pragma HLS pipeline II=2
		ap_uint<512> tmpmem = input.read();

		ap_uint<256> tmp_split[2];
		tmp_split[0] = tmpmem.range(255, 0);
		tmp_split[1] = tmpmem.range(511, 256);
		for (int j = 0; j < 2; j++) {
			result.dest = vaxis_port_data.stream_dest;
			result.data.value[0] = tmp_split[j].range(63, 0);
			result.data.value[1] = tmp_split[j].range(127, 64);
			result.data.value[2] = tmp_split[j].range(195, 128);
			result.data.value[3] = tmp_split[j].range(255, 196);
			result.data.tag[0]	 = vaxis_port_data.tuple_tag_index++;
			result.data.tag[1]	 = vaxis_port_data.tuple_tag_index++;
			result.data.tag[2]	 = vaxis_port_data.tuple_tag_index++;
			result.data.tag[3]	 = vaxis_port_data.tuple_tag_index++;

			if (!disable_channel) {
				if (vaxis_port_data.tuple_tag_index >= vaxis_port_data.tuple_tag_last_index) {
					result.last = VAXIS_TLAST_TRUE;
					result.user |= VAXIS_TLAST_MASK_HARDEND_NINVALID((unsigned) vaxis_port_data.tuple_tag_last_index % 4);
					disable_channel = true;
				} else {
					result.last = VAXIS_TLAST_FALSE;
					result.user |= VAXIS_TLAST_MASK_SOFTEND;
				}
				output.write(result);
			}
		}
	}
	if (disable_channel) {
		result.dest = vaxis_port_data.return_dest;
		result.data.value[0].range(8-1, 0);
		result.data.tag[0] = 0;
		result.last = VAXIS_TLAST_TRUE;
		result.user |= VAXIS_TLAST_MASK_HARDEND_3INVALID;
		output.write(result);
	}
	return;
}

void stream_read (
		ap_uint<512> * aximem,
		ap_uint<32> readable_blocks,
		hls::stream< ap_uint<512> > & output_buffer
		) {

	for (unsigned i = 0; i < readable_blocks; i++) {
#pragma HLS LOOP_TRIPCOUNT min=1 max=64 avg=64
#pragma HLS PIPELINE
		output_buffer.write(aximem[i]);
	}
}

void input_df_proc(
		ap_uint<512> * aximem,
		core_data_cell vaxis_port_data,
		ap_uint<32> readable_blocks,
		unsigned port_id,
		hls::stream<vaxis_quad_ext_usr> & output
		) {

#pragma HLS DATAFLOW

	hls::stream< ap_uint<512> > input_buffer;
#pragma HLS STREAM variable=input_buffer depth=1 dim=1

	stream_read(aximem, readable_blocks, input_buffer);

	fifo_send(input_buffer, vaxis_port_data, readable_blocks, port_id, output);

}

void aximm_vaxis_loader_unit(
		ap_uint<512> * aximem,
		hls::stream<vaxis_single> & config_in,
		ap_uint<VAXIS_PORT_COUNT * MEMORYDEPTH_PER_PORT_LOG2> credit_counters,
		hls::stream<vaxis_quad_ext_usr> & output
		) {
#pragma HLS INTERFACE axis register both port=config_in
#pragma HLS INTERFACE axis register both port=output
#pragma HLS INTERFACE m_axi depth=268435456 port=aximem offset=off num_write_outstanding=0 max_read_burst_length=64 max_write_burst_length=2

	static core_data_cell vaxis_port_data[VAXIS_PORT_COUNT];
#pragma HLS DATA_PACK variable=vaxis_port_data
#pragma HLS RESOURCE variable=vaxis_port_data core=RAM_1P_LUTRAM

	static bool active[VAXIS_PORT_COUNT] = {false};
#pragma HLS ARRAY_RESHAPE complete variable=active

	if (!config_in.empty()) {
		core_config(vaxis_port_data, active, config_in.read());
	} else {

		int portid;
		unsigned block_reads;
		bool deactivate;
		bool any_chan_active = false;
		for (int i = 0; i < VAXIS_PORT_COUNT; i++) {
#pragma HLS PIPELINE
#pragma HLS LOOP_TRIPCOUNT min=1 avg=8 max=16
			ap_uint<MEMORYDEPTH_PER_PORT_LOG2> avail_credit_blocks =  credit_counters.range((i+1)*MEMORYDEPTH_PER_PORT_LOG2-1, i*MEMORYDEPTH_PER_PORT_LOG2) >> 1;

			if ((vaxis_port_data[i].buffer_length != 0)
					&& (active[i])
					&& (avail_credit_blocks >= BURSTLENGTH_IN_BLOCK)) {

				any_chan_active = true;
				portid = i;
				if (vaxis_port_data[i].buffer_length < avail_credit_blocks) {
					block_reads = vaxis_port_data[i].buffer_length;
					deactivate = true;
				} else {
					block_reads = avail_credit_blocks;
					deactivate = false;
				}
			}
		}

		if (any_chan_active) {
			if (deactivate)
				active[portid] = false;

			core_data_cell tmp = vaxis_port_data[portid];

			input_df_proc(aximem, tmp, block_reads, portid, output);
			tmp.buffer_length -= block_reads;
			tmp.buffer_base_addr += block_reads;

			vaxis_port_data[portid] = tmp;
		}
	}
}
