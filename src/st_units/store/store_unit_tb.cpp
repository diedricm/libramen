#include "store_unit.h"

int main (int argc, char** argv) {

	hls::stream<flit_quad> data_input;
	hls::stream<flit_quad> conf_input;
	flit_quad new_flit;
	new_flit.user = TLAST_MASK_HARDEND_3INVALID;
	new_flit.dest = 0;
	new_flit.last = 1;

	//set buffer high tuple
	set_tag(new_flit, TUPLE_BUFFER_HIGH_REG_ADDR, 0);
	set_value(new_flit, 512-1, 0);
	conf_input.write(new_flit);

	//set iterator
	set_tag(new_flit, TUPLE_ITERATOR_REG_ADDR, 0);
	set_value(new_flit, 0, 0);
	conf_input.write(new_flit);

	//set buffer base
	set_tag(new_flit, BUFFER_BASE_REG_ADDR, 0);
	set_value(new_flit, 64 << 6, 0);
	conf_input.write(new_flit);

	//set return cdest
	set_tag(new_flit, RETURN_CDEST_REG_ADDR, 0);
	set_value(new_flit, 42, 0);
	conf_input.write(new_flit);

	//set return value
	set_tag(new_flit, START_REG_ADDR, 0);
	set_value(new_flit, 3, 0);
	conf_input.write(new_flit);

	for (int i = 0; i < 128; i++) {
		flit_quad new_flit;
		new_flit.dest = 0;
		new_flit.last = 0;
		for (int j = 0; j < 4; j++) {
			set_tag(new_flit, i * 4 + j, j);
			set_value(new_flit, i * 4 + j, j);
		}

		if (i != 127) {
			new_flit.user = TLAST_MASK_SOFTEND;
		} else {
			new_flit.user = TLAST_MASK_HARDEND_2INVALID;
		}
		data_input.write(new_flit);
	}

	hls::stream<flit_quad> output;

	hls::stream<buffer_read_req> stream_chan_req;

	ap_uint<BLOCK_SIZE_IN_BITS> memory[256];
	for (int i = 0; i < 256; i++)
		memory[i] = 0;

	for (int i = 0; i < 5; i++)
		store_unit_hls(conf_input, output, stream_chan_req, memory, conf_input.size() + data_input.size());
	store_unit_hls(data_input, output, stream_chan_req, memory, conf_input.size() + data_input.size());

	//set buffer high tuple
	set_tag(new_flit, TUPLE_BUFFER_HIGH_REG_ADDR, 0);
	set_value(new_flit, 32-1, 0);
	conf_input.write(new_flit);

	//set iterator
	set_tag(new_flit, TUPLE_ITERATOR_REG_ADDR, 0);
	set_value(new_flit, 0, 0);
	conf_input.write(new_flit);

	//set buffer base
	set_tag(new_flit, BUFFER_BASE_REG_ADDR, 0);
	set_value(new_flit, 130 << 6, 0);
	conf_input.write(new_flit);

	//set return value
	set_tag(new_flit, START_REG_ADDR, 0);
	set_value(new_flit, 7, 0);
	conf_input.write(new_flit);

	for (int i = 0; i < 4; i++)
		store_unit_hls(conf_input, output, stream_chan_req, memory, conf_input.size() + data_input.size());
	store_unit_hls(data_input, output, stream_chan_req, memory, conf_input.size() + data_input.size());

	std::cout << "Memory:" << std::endl;
	for (int i = 0; i < 256; i++) {
		std::cout << i << ":\t";
		for (int j = 0; j < 8; j++) {
			std::cout << memory[i].range((j+1)*64-1, j*64) << "\t";
		}
		std::cout << std::endl;
	}
	std::cout << std::endl;

	std::cout << "Req chan:" << std::endl;
	while (!stream_chan_req.empty()) {
		buffer_read_req tmp = stream_chan_req.read();
		std::cout << "Port: " << tmp.port_id << "\tLength:" << tmp.req_tuples << std::endl;
	}
	std::cout << std::endl;

	std::cout << "Out chan:" << std::endl;
	while (!output.empty())
		std::cout << output.read() << std::endl;
}
