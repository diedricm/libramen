#ifndef AXI4LITE_STREAM_CONF_H_
#define AXI4LITE_STREAM_CONF_H_

#include "vaxis.h"
#include <hls_stream.h>

/*
AXI4-Interface message types:
+---------------------+---------------------+-----------------+------------+--------+--------------------------------------+
|     MODE [31:30]    | STREAM ADDR [29:16] | REG ADDR [15:0] |   SCALAR   | MEMPTR | DESCRIPTION                          |
+---------------------+---------------------+-----------------+------------+--------+--------------------------------------+
|  Write scalar (00b) | Addr of destination |   Register to   |    used    | unused | Transmits a scalar value             |
|                     |  stream transformer |     write in    |            |        |                                      |
+---------------------+---------------------+-----------------+------------+--------+--------------------------------------+
| Write pointer (01b) | Addr of destination |   Register to   |   unused   |  used  | Transmits a memory pointer           |
|                     |  stream transformer |     write in    |            |        |                                      |
+---------------------+---------------------+-----------------+------------+--------+--------------------------------------+
|        Start        | Addr of destination |   Register to   | only bit 0 | unused | Sends a transformer start signal.    |
| (nonblocking) (10b) |  stream transformer |     write in    |    used    |        | Async if SCALAR == 0. Non blocking.  |
+---------------------+---------------------+-----------------+------------+--------+--------------------------------------+
|        Start        | Addr of destination |   Register to   | only bit 0 | unused | Sends a transformer start signal.    |
|   (blocking) (11b)  |  stream transformer |     write in    |    used    |        | Blocks until all previous sync start |
|                     |                     |                 |            |        | signals have terminated.             |
+---------------------+---------------------+-----------------+------------+--------+--------------------------------------+
Notes:
Nonblocking start commands can also block if the number of running synced tasks exceeds 255!
Unused bits can be of any value.
*/

/*
Confstream format:
+---------------+--------------+---------------------+
| CONFPACK TYPE |  VALUE (64b) |      TAG (32b)      |
+---------------+--------------+---------------------+
|  Scalar write | scalar (32b) | register addr (32b) |
+---------------+--------------+---------------------+
|  Memptr write | memptr (64b) | register addr (32b) |
+---------------+--------------+---------------------+
|     Start     |  cookie (8b) | register addr (32b) |
+---------------+--------------+---------------------+
|    Finished   |  cookie (8b) |  status code (32b)  |
+---------------+--------------+---------------------+

Notes:
Unassigned bits must be zero!
Status codes are signed 32bit integers.
Positive status codes indicate succesfull termination.
Negative status codes indicate abnormal termination.
A status code with value 0 is succesfull but silent.
*/


#define CREATE_AXI4LSTREAM_INSTRUCTION(MODE, STREAM_ADDR, REG_ADDR) ((MODE << 30) | ((STREAM_ADDR) << 16) | (REG_ADDR & 0xFFFF))

void axi4lite_stream_conf(
		unsigned instruction,
		unsigned scalar,
		unsigned long memptr,
		hls::stream<vaxis_single> &in_stream,
		hls::stream<vaxis_single> &out_stream
		);

#endif //AXI4LITE_STREAM_CONF_H_
