#ifndef LIBRAMEN_H_
#define LIBRAMEN_H_

#include <iostream>
#include <ap_int.h>
#include <hls_stream.h>

#define VALUE_SIZE 64
#define TAG_SIZE 32
#define TUPLE_SIZE (VALUE_SIZE + TAG_SIZE)
#define DEST_SIZE 14
#define TLAST_MASK_SIZE 3
#define FULL_DATA_SIZE (TUPLE_SIZE + DEST_SIZE + TLAST_MASK_SIZE)

#define TLAST_FALSE 0x0
#define TLAST_TRUE 0x1
#define TLAST_MASK_SOFTEND          0x0
#define TLAST_MASK_SOFTEND_NO_DATA  0x1
#define TLAST_MASK_HARDEND_NO_DATA  0x3
#define TLAST_MASK_HARDEND_0INVALID 0x4
#define TLAST_MASK_HARDEND_1INVALID 0x5
#define TLAST_MASK_HARDEND_2INVALID 0x6
#define TLAST_MASK_HARDEND_3INVALID 0x7
#define TLAST_MASK_HARDEND_NINVALID(n) (0x4 + n)
#define TLAST_MASK_IS_HARDEND(x) (((x)%8) > 1)

struct tuple {
	ap_uint<VALUE_SIZE> value;
	ap_uint<TAG_SIZE> tag;
};

struct quadtuple {
	ap_uint<VALUE_SIZE> value[4];
	ap_uint<TAG_SIZE> tag[4];
};

inline std::ostream &operator<<(std::ostream &os, tuple const &m) {
    return os << "Tuple["<< std::hex << m.value << "; " << std::hex << m.tag << "];";
}

struct flit_single {
	tuple						data;
	ap_uint<TLAST_MASK_SIZE>	user;
	ap_uint<DEST_SIZE>		dest;
	ap_uint<1>						last;
};

inline std::ostream &operator<<(std::ostream &os, flit_single const &m) {
	os << "[";
    os << m.data;
    os << "Dest[" << std::hex << m.dest << "];";
	os << "Last[" << (m.last == 1 ? "NO" : ((m.user%8) < 4 ? "SOFT" : "HARD")) << "];";
	if (m.user > 3)
		os << "LastValid[" << 8 - (m.user%8) << "]";
	if ((m.user < 4) && (m.user != 0))
		os << "INVALID TUSER!!!";
	os << "]";
    return os;
}

struct flit_quad {
	quadtuple 					data;
	ap_uint<TLAST_MASK_SIZE>	user;
	ap_uint<DEST_SIZE>		dest;
	ap_uint<1>						last;
};

inline std::ostream &operator<<(std::ostream &os, flit_quad const &m) {
	for (int i = 0; i < 4; i++) {
		flit_single tmp;
		tmp.data.value = m.data.value[i];
		tmp.data.tag   = m.data.tag[i];
		tmp.dest = m.dest;
		tmp.last = m.last;
		tmp.user = m.user;
		os << i << "[" << tmp << "]";
	}

    return os;
}

struct flit_quad_ext_usr {
	quadtuple 					data;
	ap_uint<TLAST_MASK_SIZE + 4> user;
	ap_uint<DEST_SIZE>		dest;
	ap_uint<1>						last;
};

#endif //LIBRAMEN_H_
