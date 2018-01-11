#ifndef JO_INCLUDE_MPEG_H
#define JO_INCLUDE_MPEG_H

#include <stdio.h>

// To get a header file for this, either cut and paste the header,
// or create jo_mpeg.h, #define JO_MPEG_HEADER_FILE_ONLY, and
// then include jo_mpeg.c from it.

// Returns false on failure
extern void jo_write_mpeg(FILE *fp, const unsigned char *rgbx, int width, int height, int fps);

#endif // JO_INCLUDE_MPEG_H
