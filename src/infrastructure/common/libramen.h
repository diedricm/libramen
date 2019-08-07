#ifndef VAXIS_H_
#define VAXIS_H_

#include <iostream>
#include <ap_int.h>
#include <hls_stream.h>

//#ifdef __SYNTHESIS__
//#define SIMULATION_MODE false
//#else
//#define SIMULATION_MODE true
//#endif
//
//#define ENDLESS_LOOP_COND(condition) while ((!SIMULATION_MODE) || (condition))
//#define ENDLESS_LOOP(stream) while ((!SIMULATION_MODE) || (!stream.empty()))
//#define ENDLESS_LOOP2(stream0, stream1) while ((!SIMULATION_MODE) || (!stream0.empty()) || (!stream1.empty()))

#define VAXIS_VALUE_SIZE 64
#define VAXIS_TAG_SIZE 32
#define VAXIS_TUPLE_SIZE (VAXIS_VALUE_SIZE + VAXIS_TAG_SIZE)
#define VAXIS_DEST_SIZE 14
#define VAXIS_TLAST_MASK_SIZE 3
#define VAXIS_FULL_DATA_SIZE (VAXIS_TUPLE_SIZE + VAXIS_DEST_SIZE + VAXIS_TLAST_MASK_SIZE)

#define VAXIS_TLAST_FALSE 0x0
#define VAXIS_TLAST_TRUE 0x1
#define VAXIS_TLAST_MASK_SOFTEND          0x0
#define VAXIS_TLAST_MASK_SOFTEND_NO_DATA  0x1
#define VAXIS_TLAST_MASK_HARDEND_NO_DATA  0x3
#define VAXIS_TLAST_MASK_HARDEND_0INVALID 0x4
#define VAXIS_TLAST_MASK_HARDEND_1INVALID 0x5
#define VAXIS_TLAST_MASK_HARDEND_2INVALID 0x6
#define VAXIS_TLAST_MASK_HARDEND_3INVALID 0x7
#define VAXIS_TLAST_MASK_HARDEND_NINVALID(n) (0x4 + n)
#define VAXIS_TLAST_MASK_IS_HARDEND(x) (((x)%8) > 1)

struct vaxis_tuple {
	ap_uint<VAXIS_VALUE_SIZE> value;
	ap_uint<VAXIS_TAG_SIZE> tag;
};

struct vaxis_quadtuple {
	ap_uint<VAXIS_VALUE_SIZE> value[4];
	ap_uint<VAXIS_TAG_SIZE> tag[4];
};

inline std::ostream &operator<<(std::ostream &os, vaxis_tuple const &m) {
    return os << "Tuple["<< std::hex << m.value << "; " << std::hex << m.tag << "];";
}

struct vaxis_single {
	vaxis_tuple						data;
	ap_uint<VAXIS_TLAST_MASK_SIZE>	user;
	ap_uint<VAXIS_DEST_SIZE>		dest;
	ap_uint<1>						last;
};

inline std::ostream &operator<<(std::ostream &os, vaxis_single const &m) {
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

struct vaxis_quad {
	vaxis_quadtuple 				data;
	ap_uint<VAXIS_TLAST_MASK_SIZE>	user;
	ap_uint<VAXIS_DEST_SIZE>		dest;
	ap_uint<1>						last;
};

inline std::ostream &operator<<(std::ostream &os, vaxis_quad const &m) {
	for (int i = 0; i < 4; i++) {
		vaxis_single tmp;
		tmp.data.value = m.data.value[i];
		tmp.data.tag   = m.data.tag[i];
		tmp.dest = m.dest;
		tmp.last = m.last;
		tmp.user = m.user;
		os << i << "[" << tmp << "]";
	}

    return os;
}

struct vaxis_quad_ext_usr {
	vaxis_quadtuple 				data;
	ap_uint<VAXIS_TLAST_MASK_SIZE + 4> user;
	ap_uint<VAXIS_DEST_SIZE>		dest;
	ap_uint<1>						last;
};

#endif //VAXIS_H_
