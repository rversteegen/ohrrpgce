#ifndef _UNICODE_H
#define _UNICODE_H

#include <stdint.h>
#include <wchar.h>

int utf8_length(const unsigned char* s);
wchar_t *utf8_decode(const unsigned char *input, int *length);
int utf8_decode_char(const unsigned char **input);
int utf8_offset(const char *s, int charnum);
int utf8_charnum(const char *s, int offset);
int utf8_charlen(uint32_t ch);

int utf8_encode_char(char *dest, uint32_t ch);
char *utf8_encode(const wchar_t *input, int input_len, int *length);

//wchar_t compose_char(wchar_t src1, wchar_t src2);
int partially_normalise_unicode(const wchar_t *input, wchar_t *output, int outsize);
int wstring_to_latin1(const wchar_t *input, unsigned char *output, int outsize);

#endif
