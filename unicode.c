// OHRRPGCE - Unicode routines
// 
// This file is placed under the following license:
// 
// Copyright (c) 2008-2009 Bjoern Hoehrmann <bjoern@hoehrmann.de>
// See http://bjoern.hoehrmann.de/utf-8/decoder/dfa/ for details.
// Copyright (c) 2012,2016 Ralph Versteegen
// 
// Permission is hereby granted, free of charge, to any person obtaining
// a copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
// 
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
// LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
// OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


#include <stdlib.h>
#include <stdint.h>
#include <wchar.h>

#define UTF8_ACCEPT 0
#define UTF8_REJECT 1

static const uint8_t utf8d[] = {
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, // 00..1f
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, // 20..3f
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, // 40..5f
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, // 60..7f
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9, // 80..9f
  7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7, // a0..bf
  8,8,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2, // c0..df
  0xa,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x4,0x3,0x3, // e0..ef
  0xb,0x6,0x6,0x6,0x5,0x8,0x8,0x8,0x8,0x8,0x8,0x8,0x8,0x8,0x8,0x8, // f0..ff
  0x0,0x1,0x2,0x3,0x5,0x8,0x7,0x1,0x1,0x1,0x4,0x6,0x1,0x1,0x1,0x1, // s0..s0
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,1,1,1,1,1,0,1,0,1,1,1,1,1,1, // s1..s2
  1,2,1,1,1,1,1,2,1,2,1,1,1,1,1,1,1,1,1,1,1,1,1,2,1,1,1,1,1,1,1,1, // s3..s4
  1,2,1,1,1,1,1,1,1,2,1,1,1,1,1,1,1,1,1,1,1,1,1,3,1,3,1,1,1,1,1,1, // s5..s6
  1,3,1,1,1,1,1,3,1,3,1,1,1,1,1,1,1,3,1,1,1,1,1,1,1,1,1,1,1,1,1,1, // s7..s8
};

// Given an initial state and the next byte of a UTF8 string, decode it.
// *state should be initialised to UTF8_ACCEPT at the start of the string.
// After each character if *state is UTF8_ACCEPT, a complete character has
// decoded and *codep holds the codepoint, if *state is UTF8_REJECT the
// sequence is invalid (and *state stays that way), otherwise in the middle
// of a character.
static uint32_t decode_utf8_char(uint32_t* state, uint32_t* codep, uint32_t byte) {
	uint32_t type = utf8d[byte];

	*codep = (*state != UTF8_ACCEPT) ?
		(byte & 0x3fu) | (*codep << 6) :
		(0xff >> type) & (byte);

	*state = utf8d[256 + *state*16 + type];
	return *state;
}

// In codepoints. Returns negative value if invalid (actually position of bad character)
ssize_t utf8_length(unsigned char* s) {
	uint32_t codepoint = 0;
	uint32_t state = UTF8_ACCEPT;
	ssize_t count = 0;

	for (count = 0; *s; ++s) {
		if (decode_utf8_char(&state, &codepoint, *s) == UTF8_ACCEPT)
			count += 1;
		if (state == UTF8_REJECT)
			return -2 - count;
	}

	if (state != UTF8_ACCEPT)
		return -1;
	return count;
}

// Returns NULL on failure, otherwise returns an allocated UCS2 or UTF32, depending on system, string
// If length is not NULL and there was no error, then it is filled with the length
wchar_t *utf8_decode(unsigned char *input, ssize_t *length) {
	ssize_t len = utf8_length(input);
	if (len <= -1)
		return NULL;
	if (length)
		*length = len;

	uint32_t codepoint = 0;
	uint32_t state = UTF8_ACCEPT;
	wchar_t *ret, *outchar;
	outchar = ret = (wchar_t*)malloc((len + 1) * sizeof(wchar_t));

	while (*input) {
		if (decode_utf8_char(&state, &codepoint, *input++) == UTF8_ACCEPT) {
			if (codepoint > WCHAR_MAX)
				codepoint = L'?';

			*outchar++ = codepoint;
		}
	}
	*outchar = L'\0';
	return ret;
}

+#if LJ_53
+/* Format utf8 code into buff. Note that `buff` goes backwards. */
+MSize LJ_FASTCALL lj_strfmt_utf8(char *buff, unsigned long x)
+{
+  int n = 1;  /* number of bytes put in buffer (backwards) */
+  lua_assert(x <= 0x10FFFF);
+  if (x < 0x80)  /* ascii? */
+    buff[STRFMT_MAXBUF_UTF8 - 1] = (char)x;
+  else {  /* need continuation bytes */
+    unsigned int mfb = 0x3f;  /* maximum that fits in first byte */
+    do {  /* add continuation bytes */
+      buff[STRFMT_MAXBUF_UTF8 - (n++)] = (char)(0x80 | (x & 0x3f));
+      x >>= 6;  /* remove added bits */
+      mfb >>= 1;  /* now there is one less bit available in first byte */
+    } while (x > mfb);  /* still needs continuation byte? */
+    buff[STRFMT_MAXBUF_UTF8 - n] = (char)((~mfb << 1) | x);  /* add first byte */
+  }
+  return n;
+}
+#endif

// Generated by misc/generate_unicode_compose_table.c
// This table only contains composition rules that generate
// characters below 0x500
static const short compose_table[] = {
    65,768,192,65,769,193,65,770,194,65,771,195,65,772,256,65,774,258,
    65,775,550,65,776,196,65,778,197,65,780,461,65,783,512,65,785,514,
    65,808,260,67,769,262,67,770,264,67,775,266,67,780,268,67,807,199,
    68,780,270,69,768,200,69,769,201,69,770,202,69,772,274,69,774,276,
    69,775,278,69,776,203,69,780,282,69,783,516,69,785,518,69,807,552,
    69,808,280,71,769,500,71,770,284,71,774,286,71,775,288,71,780,486,
    71,807,290,72,770,292,72,780,542,73,768,204,73,769,205,73,770,206,
    73,771,296,73,772,298,73,774,300,73,775,304,73,776,207,73,780,463,
    73,783,520,73,785,522,73,808,302,74,770,308,75,780,488,75,807,310,
    76,769,313,76,780,317,76,807,315,78,768,504,78,769,323,78,771,209,
    78,780,327,78,807,325,79,768,210,79,769,211,79,770,212,79,771,213,
    79,772,332,79,774,334,79,775,558,79,776,214,79,779,336,79,780,465,
    79,783,524,79,785,526,79,795,416,79,808,490,82,769,340,82,780,344,
    82,783,528,82,785,530,82,807,342,83,769,346,83,770,348,83,780,352,
    83,806,536,83,807,350,84,780,356,84,806,538,84,807,354,85,768,217,
    85,769,218,85,770,219,85,771,360,85,772,362,85,774,364,85,776,220,
    85,778,366,85,779,368,85,780,467,85,783,532,85,785,534,85,795,431,
    85,808,370,87,770,372,89,769,221,89,770,374,89,772,562,89,776,376,
    90,769,377,90,775,379,90,780,381,97,768,224,97,769,225,97,770,226,
    97,771,227,97,772,257,97,774,259,97,775,551,97,776,228,97,778,229,
    97,780,462,97,783,513,97,785,515,97,808,261,99,769,263,99,770,265,
    99,775,267,99,780,269,99,807,231,100,780,271,101,768,232,101,769,233,
    101,770,234,101,772,275,101,774,277,101,775,279,101,776,235,101,780,283,
    101,783,517,101,785,519,101,807,553,101,808,281,103,769,501,103,770,285,
    103,774,287,103,775,289,103,780,487,103,807,291,104,770,293,104,780,543,
    105,768,236,105,769,237,105,770,238,105,771,297,105,772,299,105,774,301,
    105,776,239,105,780,464,105,783,521,105,785,523,105,808,303,106,770,309,
    106,780,496,107,780,489,107,807,311,108,769,314,108,780,318,108,807,316,
    110,768,505,110,769,324,110,771,241,110,780,328,110,807,326,111,768,242,
    111,769,243,111,770,244,111,771,245,111,772,333,111,774,335,111,775,559,
    111,776,246,111,779,337,111,780,466,111,783,525,111,785,527,111,795,417,
    111,808,491,114,769,341,114,780,345,114,783,529,114,785,531,114,807,343,
    115,769,347,115,770,349,115,780,353,115,806,537,115,807,351,116,780,357,
    116,806,539,116,807,355,117,768,249,117,769,250,117,770,251,117,771,361,
    117,772,363,117,774,365,117,776,252,117,778,367,117,779,369,117,780,468,
    117,783,533,117,785,535,117,795,432,117,808,371,119,770,373,121,769,253,
    121,770,375,121,772,563,121,776,255,122,769,378,122,775,380,122,780,382,
    168,769,901,196,772,478,197,769,506,198,769,508,198,772,482,213,772,556,
    214,772,554,216,769,510,220,768,475,220,769,471,220,772,469,220,780,473,
    228,772,479,229,769,507,230,769,509,230,772,483,245,772,557,246,772,555,
    248,769,511,252,768,476,252,769,472,252,772,470,252,780,474,439,780,494,
    490,772,492,491,772,493,550,772,480,551,772,481,558,772,560,559,772,561,
    658,780,495,776,769,836,913,769,902,917,769,904,919,769,905,921,769,906,
    921,776,938,927,769,908,933,769,910,933,776,939,937,769,911,945,769,940,
    949,769,941,951,769,942,953,769,943,953,776,970,959,769,972,965,769,973,
    965,776,971,969,769,974,970,769,912,971,769,944,978,769,979,978,776,980,
    1030,776,1031,1040,774,1232,1040,776,1234,1043,769,1027,1045,768,1024,
    1045,774,1238,1045,776,1025,1046,774,1217,1046,776,1244,1047,776,1246,
    1048,768,1037,1048,772,1250,1048,774,1049,1048,776,1252,1050,769,1036,
    1054,776,1254,1059,772,1262,1059,774,1038,1059,776,1264,1059,779,1266,
    1063,776,1268,1067,776,1272,1069,776,1260,1072,774,1233,1072,776,1235,
    1075,769,1107,1077,768,1104,1077,774,1239,1077,776,1105,1078,774,1218,
    1078,776,1245,1079,776,1247,1080,768,1117,1080,772,1251,1080,774,1081,
    1080,776,1253,1082,769,1116,1086,776,1255,1091,772,1263,1091,774,1118,
    1091,776,1265,1091,779,1267,1095,776,1269,1099,776,1273,1101,776,1261,
    1110,776,1111,1140,783,1142,1141,783,1143,1240,776,1242,1241,776,1243,
    1256,776,1258,1257,776,1259,
};
#define N_COMPOSE_RULES 328

// Check for a composition rule for a character and a modifier.
static wchar_t compose_char(wchar_t src1, wchar_t src2) {
	// Each rule is a triple src1, src2, dest
	//printf("searching %c %d  %c %d\n", src1, src1, src2, src2);
	/*  Linear search
	for (int idx = 0; idx < N_COMPOSE_RULES; idx++) {
		if (rule[0] == src1 && rule[1] == src2)
			return rule[2];
		rule += 3;
	}
	*/
	// Bisection search
	int left = 0, right = N_COMPOSE_RULES - 1;
	while (left <= right) {
		unsigned int mid = (left + right) / 2;
		const short *midrule = compose_table + 3 * mid;
		if (midrule[0] < src1 || (midrule[0] == src1 && midrule[1] < src2))
			left = mid + 1;
		else if (midrule[0] == src1 && midrule[1] == src2)
			return midrule[2];
		else
			right = mid - 1;
	}
	return 0;
}

// Process a nul-terminated wstring into another wstring buffer of size 'outsize' wchars
// (the result may be shorter than the input, but not longer). Returns length in chars.
//
// Try to combine modifiers to create common pre-composed characters, where
// 'common' is defined as those with codepoints below 0x500 (which covers
// Latin, Greek and Cyrillic) not having multiple accents.
// (See http://www.tamasoft.co.jp/en/general-info/unicode.html)
// Note that these rules only work for simple cases, in general they don't
// work for creating composite characters out of multiple modifiers; to do
// that you would have to break a composite character up, sort the modifiers
// into the canonical order, and then apply them (that's the intention of
// table I am using is intended for).  (Full, optimised tables to compute NFC
// form are ~45kB)
ssize_t partially_normalise_unicode(wchar_t *input, wchar_t *output, ssize_t outsize) {
	if (outsize <= 0) return 0;

	ssize_t ret = 0;
	while (*input && outsize-- > 1) {
		wchar_t composed = compose_char(input[0], input[1]);
		if (composed) {
			*output++ = composed;
			input += 2;
			// Don't bother trying another composition of the same character
		} else
			*output++ = *input++;
		ret++;
	}
	*output = '\0';
        return ret;
}

// Process a nul-terminated wstring into a char* buffer of size 'outsize' bytes
// (the result may be shorter than the input, but not longer). Returns length in chars.
ssize_t wstring_to_latin1(wchar_t *input, unsigned char *output, ssize_t outsize) {
	if (outsize <= 0) return 0;

	ssize_t ret = 0;
	while (*input && outsize-- > 1) {
		wchar_t composed = compose_char(input[0], input[1]);
		if (composed) {
			*output++ = composed;
			input += 2;
			// Don't bother trying another composition of the same character
		} else {
			if (*input > 255)
				*output++ = '?';
			else
				*output++ = *input;
			input++;
		}
		ret++;
	}
	*output = '\0';
        return ret;
}
