#include <zlib.h>
#include <string.h>

#ifndef MOONBIT_FFI_EXPORT
#define MOONBIT_FFI_EXPORT __attribute__((visibility("default")))
#endif

typedef unsigned char *moonbit_bytes_t;

/* Return actual output length on success, -1 on error, -2 on buffer too small */

MOONBIT_FFI_EXPORT int mizchi_zlib_native_compress(moonbit_bytes_t input,
                                                   int input_len,
                                                   moonbit_bytes_t output,
                                                   int max_output_len) {
  uLongf dest_len = (uLongf)max_output_len;
  int ret = compress(output, &dest_len, input, (uLong)input_len);
  if (ret == Z_BUF_ERROR)
    return -2;
  if (ret != Z_OK)
    return -1;
  return (int)dest_len;
}

MOONBIT_FFI_EXPORT int mizchi_zlib_native_decompress(moonbit_bytes_t input,
                                                     int input_len,
                                                     moonbit_bytes_t output,
                                                     int max_output_len) {
  uLongf dest_len = (uLongf)max_output_len;
  int ret = uncompress(output, &dest_len, input, (uLong)input_len);
  if (ret == Z_BUF_ERROR)
    return -2;
  if (ret != Z_OK)
    return -1;
  return (int)dest_len;
}

MOONBIT_FFI_EXPORT int mizchi_zlib_native_deflate_compress(
    moonbit_bytes_t input, int input_len, moonbit_bytes_t output,
    int max_output_len) {
  z_stream strm;
  memset(&strm, 0, sizeof(strm));
  /* windowBits = -15 for raw deflate (no zlib/gzip header) */
  int ret = deflateInit2(&strm, Z_DEFAULT_COMPRESSION, Z_DEFLATED, -15, 8,
                         Z_DEFAULT_STRATEGY);
  if (ret != Z_OK)
    return -1;
  strm.next_in = input;
  strm.avail_in = (uInt)input_len;
  strm.next_out = output;
  strm.avail_out = (uInt)max_output_len;
  ret = deflate(&strm, Z_FINISH);
  int out_len = (int)strm.total_out;
  deflateEnd(&strm);
  if (ret == Z_STREAM_END)
    return out_len;
  if (ret == Z_OK || ret == Z_BUF_ERROR)
    return -2;
  return -1;
}

MOONBIT_FFI_EXPORT int mizchi_zlib_native_deflate_decompress(
    moonbit_bytes_t input, int input_len, moonbit_bytes_t output,
    int max_output_len) {
  z_stream strm;
  memset(&strm, 0, sizeof(strm));
  /* windowBits = -15 for raw deflate */
  int ret = inflateInit2(&strm, -15);
  if (ret != Z_OK)
    return -1;
  strm.next_in = input;
  strm.avail_in = (uInt)input_len;
  strm.next_out = output;
  strm.avail_out = (uInt)max_output_len;
  ret = inflate(&strm, Z_FINISH);
  int out_len = (int)strm.total_out;
  inflateEnd(&strm);
  if (ret == Z_STREAM_END)
    return out_len;
  if (ret == Z_OK || ret == Z_BUF_ERROR)
    return -2;
  return -1;
}

MOONBIT_FFI_EXPORT int mizchi_zlib_native_gzip_compress(moonbit_bytes_t input,
                                                        int input_len,
                                                        moonbit_bytes_t output,
                                                        int max_output_len) {
  z_stream strm;
  memset(&strm, 0, sizeof(strm));
  /* windowBits = 15 + 16 for gzip encoding */
  int ret = deflateInit2(&strm, Z_DEFAULT_COMPRESSION, Z_DEFLATED, 15 + 16, 8,
                         Z_DEFAULT_STRATEGY);
  if (ret != Z_OK)
    return -1;
  strm.next_in = input;
  strm.avail_in = (uInt)input_len;
  strm.next_out = output;
  strm.avail_out = (uInt)max_output_len;
  ret = deflate(&strm, Z_FINISH);
  int out_len = (int)strm.total_out;
  deflateEnd(&strm);
  if (ret == Z_STREAM_END)
    return out_len;
  if (ret == Z_OK || ret == Z_BUF_ERROR)
    return -2;
  return -1;
}

MOONBIT_FFI_EXPORT int mizchi_zlib_native_gzip_decompress(
    moonbit_bytes_t input, int input_len, moonbit_bytes_t output,
    int max_output_len) {
  z_stream strm;
  memset(&strm, 0, sizeof(strm));
  /* windowBits = 15 + 16 for gzip decoding */
  int ret = inflateInit2(&strm, 15 + 16);
  if (ret != Z_OK)
    return -1;
  strm.next_in = input;
  strm.avail_in = (uInt)input_len;
  strm.next_out = output;
  strm.avail_out = (uInt)max_output_len;
  ret = inflate(&strm, Z_FINISH);
  int out_len = (int)strm.total_out;
  inflateEnd(&strm);
  if (ret == Z_STREAM_END)
    return out_len;
  if (ret == Z_OK || ret == Z_BUF_ERROR)
    return -2;
  return -1;
}
