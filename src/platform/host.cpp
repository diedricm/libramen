#include <iostream>
#include "xcl2.hpp"
#include <vector>

#include "axi4lite_stream_conf.h"

void stream_transform_core_send_msg(
		cl::CommandQueue & cqueue,
		cl::Kernel & stc_kernel,
		unsigned msg_type,
		unsigned scalar,
		unsigned dest_addr,
		unsigned reg_addr,
		cl::Buffer & membuffer
		) {

	if (msg_type > 3) {
		std::cerr << "stream_transform_core_send_msg(): Argument msg_type must be between 0 and 3, but is " << msg_type << std::endl;
	}
	if (dest_addr > (1 << 14)) {
		std::cerr << "stream_transform_core_send_msg(): Argument dest_addr must be between 0 and (2^14)-1, but is " << dest_addr << std::endl;
	}


	unsigned instruction = CREATE_AXI4LSTREAM_INSTRUCTION(msg_type, dest_addr, reg_addr);

	cl_int err;
	OCL_CHECK(err, err = stc_kernel.setArg(0, instruction));
	OCL_CHECK(err, err = stc_kernel.setArg(1, scalar));
	OCL_CHECK(err, err = stc_kernel.setArg(2, membuffer));

	OCL_CHECK(err, err = cqueue.enqueueTask(stc_kernel));
}

void stream_transform_core_send_scalar(
		cl::CommandQueue & cqueue,
		cl::Kernel & stc_kernel,
		unsigned dest_addr,
		unsigned reg_addr,
		unsigned scalar,
		cl::Buffer & membuffer
		) {

	stream_transform_core_send_msg(cqueue, stc_kernel, 0, scalar, dest_addr, reg_addr, membuffer);
}

void stream_transform_core_send_buffer(
		cl::CommandQueue & cqueue,
		cl::Kernel & stc_kernel,
		unsigned dest_addr,
		unsigned reg_addr,
		cl::Buffer & membuffer
		) {

	stream_transform_core_send_msg(cqueue, stc_kernel, 1, 0, dest_addr, reg_addr, membuffer);
}

void stream_transform_core_send_start(
		cl::CommandQueue & cqueue,
		cl::Kernel & stc_kernel,
		unsigned dest_addr,
		unsigned reg_addr,
		bool async,
		bool blocking,
		cl::Buffer & membuffer
		) {

	stream_transform_core_send_msg(cqueue, stc_kernel, 2 + (blocking ? 1 : 0), async ? 0 : 1, dest_addr, reg_addr, membuffer);
}

#define INT_CNT 128
#define VAXIS_TRANSACTION_CNT (INT_CNT/4)

int main(int argc, char** argv)
{
    if (argc != 2) {
        std::cout << "Usage: " << argv[0] << " <XCLBIN File>" << std::endl;
		return EXIT_FAILURE;
	}


    std::string binaryFile = argv[1];
    unsigned fileBufSize;

    cl_int err;

    std::vector<int,aligned_allocator<int>> source_in(INT_CNT);
    std::vector<int,aligned_allocator<int>> source_hw_results(INT_CNT);

    for (int i = 0; i < source_in.size(); i++)
    	source_in[i] = i;

// OPENCL HOST CODE AREA START
    // get_xil_devices() is a utility API which will find the xilinx
    // platforms and will return list of devices connected to Xilinx platform
    std::vector<cl::Device> devices = xcl::get_xil_devices();
    cl::Device device = devices[0];

    OCL_CHECK(err, cl::Context context(device, NULL, NULL, NULL, &err));
    OCL_CHECK(err, cl::CommandQueue q(context, device, CL_QUEUE_PROFILING_ENABLE, &err));

    // read_binary_file() is a utility API which will load the binaryFile
    // and will return the pointer to file buffer.
    char* fileBuf = xcl::read_binary_file(binaryFile, fileBufSize);
    cl::Program::Binaries bins{{fileBuf, fileBufSize}};

    devices.resize(1);
    OCL_CHECK(err, cl::Program program(context, devices, bins, NULL, &err));
    OCL_CHECK(err, cl::Kernel krnl_stream_transform_core(program,"stream_transform_core", &err));

    // Allocate Buffer in Global Memory
    // Buffers are allocated using CL_MEM_USE_HOST_PTR for efficient memory and
    // Device-to-host communication
    int vector_size_bytes = INT_CNT * 4;
    OCL_CHECK(err, cl::Buffer buffer_in    (context,CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY,  (cl::size_type) vector_size_bytes, source_in.data(), &err));
    OCL_CHECK(err, cl::Buffer buffer_output(context,CL_MEM_USE_HOST_PTR | CL_MEM_WRITE_ONLY, (cl::size_type) vector_size_bytes, source_hw_results.data(), &err));

    // Copy input data to device global memory
    OCL_CHECK(err, err = q.enqueueMigrateMemObjects({buffer_in},0/* 0 means from host*/));

    //setup debug output unit
    stream_transform_core_send_scalar(q, krnl_stream_transform_core, 0x10, 0x3, VAXIS_TRANSACTION_CNT, buffer_output);
    stream_transform_core_send_buffer(q, krnl_stream_transform_core, 0x10, 0x2, buffer_output);
    stream_transform_core_send_scalar(q, krnl_stream_transform_core, 0x10, 0x1, 0x0, buffer_output);
    stream_transform_core_send_start(q, krnl_stream_transform_core, 0x10, 0x0, false, false, buffer_output);

    //setup axi4mm loader
    stream_transform_core_send_scalar(q, krnl_stream_transform_core, 0x20, 0x5, 0x1, buffer_output);
    stream_transform_core_send_scalar(q, krnl_stream_transform_core, 0x20, 0x4, 0x0, buffer_output);
    stream_transform_core_send_scalar(q, krnl_stream_transform_core, 0x20, 0x3, INT_CNT, buffer_output);
    stream_transform_core_send_buffer(q, krnl_stream_transform_core, 0x20, 0x2, buffer_in);
    stream_transform_core_send_scalar(q, krnl_stream_transform_core, 0x20, 0x1, 0x0, buffer_output);
    stream_transform_core_send_start (q, krnl_stream_transform_core, 0x20, 0x0, false, true, buffer_output);

    // Copy Result from Device Global Memory to Host Local Memory
    OCL_CHECK(err, err = q.enqueueMigrateMemObjects({buffer_output},CL_MIGRATE_MEM_OBJECT_HOST));

    q.finish();
// OPENCL HOST CODE AREA END

    bool passed = true;

    // Compare the results of the Device to the simulation
    for (int i = 0 ; i < VAXIS_TRANSACTION_CNT ; i++){
    	for (int j = 0; j < 4; j++) {
    		std::cout << std::hex << source_hw_results[i*4+j] << "\t";
    	}
    	std::cout << std::endl;
    }

    delete[] fileBuf;

    std::cout << "TEST " << (passed ? "PASSED" : "FAILED") << std::endl;
    return (passed ? EXIT_SUCCESS : EXIT_FAILURE);
}
