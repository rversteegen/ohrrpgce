/* OHRRPGCE - 8-bit graphics blitting
 * (C) Copyright 1997-2020 James Paige, Ralph Versteegen, and the OHRRPGCE Developers
 * Dual licensed under the GNU GPL v2+ and MIT Licenses. Read LICENSE.txt for terms and disclaimer of liability.
 */

#include "config.h"
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <assert.h>
#include "allmodex.h"
#include "surface.h"
#include "errorlog.h"
#include "blend.h"

void smoothzoomblit_8_to_8bit(uint8_t *srcbuffer, uint8_t *destbuffer, XYPair size, int pitch, int zoom, int smooth, RGBcolor dummypal[]);
void smoothzoomblit_8_to_32bit(uint8_t *srcbuffer, RGBcolor *destbuffer, XYPair size, int pitch, int zoom, int smooth, RGBcolor pal[]);
void smoothzoomblit_32_to_32bit(RGBcolor *srcbuffer, RGBcolor *destbuffer, XYPair size, int pitch, int zoom, int smooth, RGBcolor dummypal[]);

//// Globals
enum BlendAlgo blend_algo = blendAlgoDither;
// This cache is wiped as needed in intpal_changed()
uint8_t nearcolor_cache[65536] = {0};


static inline int get_frame_buf(Frame *spr, uint8_t *restrict *srcpp, uint8_t *restrict *maskpp) {
	if (spr->surf) {
		if (spr->surf->format != SF_8bit) {
			debug(errShowBug, "blitohr[scaled]: 32bit sprite!");
			return 0;
		}
		*srcpp = spr->surf->pPaletteData;
		*maskpp = spr->surf->pMaskData;
	} else {
		*srcpp = spr->image;
		*maskpp = spr->mask;
	}
	return 1;
}

// 8-bit -> 8-bit scale=1 blitting routine. Supports 8-bit Surface-backed Frames too.
// The arguments must already be clipped to the destination (done in draw_clipped())
// opts should be a ptr to def_drawoptions if no extra options are needed.
void blitohr(Frame *spr, Frame *destspr, Palette16 *pal, int startoffset, int startx, int starty, int endx, int endy, boolint trans, DrawOptions *opts) {
	int i, j;
	unsigned char *maskp, *srcp, *original_maskp, *restrict destp, *restrict destmaskp;
	int srclineinc, destlineinc;

	if (!opts) {
		debug(errShowBug, "blitohr: opts not optional!");
		return;
	}

	if (!get_frame_buf(spr, &srcp, &maskp))
		return;
	if (maskp == NULL) {
		//we could add an optimised version for this case, which is the 99% case
		maskp = srcp;
	}

	srcp += startoffset;
	maskp += startoffset;
	original_maskp = maskp;

	srclineinc = spr->pitch - (endx - startx + 1);

	if (!get_frame_buf(destspr, &destp, &destmaskp))
		return;
	destp += startx + starty * destspr->pitch;
	if (destmaskp)
		destmaskp += startx + starty * destspr->pitch;

	destlineinc = destspr->pitch - (endx - startx + 1);

	int tog = 0;

	if (opts->with_blending && (opts->opacity < 1. || opts->blend_mode != blendModeNormal)) {
		int alpha = 256 * opts->opacity;
		if (alpha <= 0)
			goto no_draw;

		for (i = starty; i <= endy; i++) {
			struct RGBerrors rgberr = {};
			for (j = endx - startx; j >= 0; j--) {
				tog ^= 1;
				if (trans && *maskp == 0) {
					destp++;
					maskp++;
					srcp++;
					continue;
				}

				RGBcolor srcc, destc = curmasterpal[*destp];
				if (pal)
					srcc = curmasterpal[pal->col[*srcp]];
				else
					srcc = curmasterpal[*srcp];

				// Blend source and dest pixels in 24-bit colour space (.a ignored for now)
				RGBcolor blended = alpha_blend(srcc, destc, alpha, opts->blend_mode, false);

				destp[0] = map_rgb_to_masterpal(blended, &rgberr, tog, (i&j));
				destp++;
				maskp++;
				srcp++;
			}
			destp += destlineinc;
			maskp += srclineinc;
			srcp += srclineinc;
			tog ^= srclineinc & 1;
			tog ^= 1;
		}
	} else
	if (pal != NULL && trans != 0) {
		for (i = starty; i <= endy; i++) {
			//loop unrolling copied from below, but not nearly as effective
			for (j = endx - startx; j >= 3; j -= 4) {
				if (maskp[0]) destp[0] = pal->col[srcp[0]];
				if (maskp[1]) destp[1] = pal->col[srcp[1]];
				if (maskp[2]) destp[2] = pal->col[srcp[2]];
				if (maskp[3]) destp[3] = pal->col[srcp[3]];
				maskp += 4;
				srcp += 4;
				destp += 4;
			}
			for (; j >= 0; j--) {
				if (maskp++[0]) destp[0] = pal->col[srcp[0]];
				destp++;
				srcp++;
			}

			destp += destlineinc;
			maskp += srclineinc;
			srcp += srclineinc;
		}
	} else if (pal != NULL && trans == 0) {
		for (i = starty; i <= endy; i++) {
			//loop unrolling blindly copied from below
			for (j = endx - startx; j >= 3; j -= 4) {
				destp[0] = pal->col[srcp[0]];
				destp[1] = pal->col[srcp[1]];
				destp[2] = pal->col[srcp[2]];
				destp[3] = pal->col[srcp[3]];
				srcp += 4;
				destp += 4;
			}
			for (; j >= 0; j--)
				destp++[0] = pal->col[srcp++[0]];

			destp += destlineinc;
			srcp += srclineinc;
		}
	} else if (trans == 0) { //&& pal == NULL
		for (i = starty; i <= endy; i++) {
			memcpy(destp, srcp, endx - startx + 1);
			srcp += spr->pitch;
			destp += destspr->pitch;
		}
	} else { //pal == NULL && trans != 0
		for (i = starty; i <= endy; i++) {
			//a little loop unrolling
			for (j = endx - startx; j >= 3; j -= 4) {
				//the following line is surprisingly slow
				//*(int*)destp = (*(int*)srcp & *(int*)maskp) | (*(int*)destp & ~*(int*)maskp)
				if (maskp[0]) destp[0] = srcp[0];
				if (maskp[1]) destp[1] = srcp[1];
				if (maskp[2]) destp[2] = srcp[2];
				if (maskp[3]) destp[3] = srcp[3];
				maskp += 4;
				srcp += 4;
				destp += 4;
			}
			for (; j >= 0; j--) {
				if (*maskp++) *destp = *srcp;
				srcp++;
				destp++;
			}

			destp += destlineinc;
			maskp += srclineinc;
			srcp += srclineinc;
		}
	}
  no_draw:

	// Set the destination mask
	if (opts->write_mask && destmaskp) {
		srcp = original_maskp;
		destp = destmaskp;
		for (i = starty; i <= endy; i++) {
			memcpy(destp, srcp, endx - startx + 1);
			srcp += spr->pitch;
			destp += destspr->pitch;
		}
	}
}

// 8 bit scaled blitting routine. Supports 8-bit Surface-backed Frames too.
// The arguments must already be clipped to the destination (done in draw_clipped_scaled())
//horribly slow; keep putting off doing something about it
//(This function will be replaced with rotozoomSurface(), which has a fast path for scaling)
// opts should be a ptr to def_drawoptions if no extra options are needed.
void blitohrscaled(Frame *spr, Frame *destspr, Palette16 *pal, int x, int y, int startx, int starty, int endx, int endy, boolint trans, DrawOptions *opts) {
	unsigned char *restrict destbuf, *restrict destmaskp;
	unsigned char *restrict maskp;
	unsigned char *restrict srcp;
	int tx, ty;
	int pix, spix;

	if (!opts) {
		debug(errShowBug, "blitohrscaled: opts not optional!");
		return;
	}

	if (!get_frame_buf(spr, &srcp, &maskp)) return;
	if (!get_frame_buf(destspr, &destbuf, &destmaskp)) return;

	int scale = opts->scale;

	bool write_mask = opts->write_mask;
	if (maskp == 0) {
		maskp = srcp;
	}
	if (destmaskp == 0) {
		write_mask = false;
	}

	if (trans == 0) {
		for (ty = starty; ty <= endy; ty++) {
			//tx = startx
			for (tx = startx; tx <= endx; tx++) {
				//figure out where to put the pixel
				pix = (ty * destspr->pitch) + tx;
				//and where to get the pixel from
				spix = (((ty - y) / scale) * spr->pitch) + ((tx - x) / scale);

				if (pal != 0)
					destbuf[pix] = pal->col[srcp[spix]];
				else
					destbuf[pix] = srcp[spix];
				if (write_mask)
					destmaskp[pix] = maskp[spix];
			}
		}
	} else {
		for (ty = starty; ty <= endy; ty++) {
			//tx = startx
			for (tx = startx; tx <= endx; tx++) {
				//figure out where to put the pixel
				pix = (ty * destspr->pitch) + tx;
				//and where to get the pixel from
				spix = (((ty - y) / scale) * spr->pitch) + ((tx - x) / scale);

				//check mask
				if (maskp[spix]) {
					if (pal != 0)
						destbuf[pix] = pal->col[srcp[spix]];
					else
						destbuf[pix] = srcp[spix];
				}
				if (write_mask)
					destmaskp[pix] = maskp[spix];
			}
		}
	}
}

typedef void (*smoothblitfunc_t)(void *srcbuffer, void *destbuffer, XYPair size, int pitch, int zoom, int smooth, RGBcolor pal[]);

// The smoothzoomblit functions implement smoothing at 2x, 3x and 4x zooms.
// This implements smoothing at other zooms by chaining together calls to those functions
bool multismoothblit(int srcbitdepth, int destbitdepth, void *srcbuffer, void *destbuffer, XYPair size, int pitch, int zoom, int *smooth, RGBcolor pal[]) {
	if (zoom < 4 || !*smooth)
		return false;

	smoothblitfunc_t func1, func2;
	if (srcbitdepth == 32) {
		assert(destbitdepth == 32);
		// Slow: have to use 32 bit whole way
		func1 = func2 = (smoothblitfunc_t)smoothzoomblit_32_to_32bit;
	} else {
		assert(srcbitdepth == 8);
		assert(destbitdepth == 8 || destbitdepth == 32);
		// Use 8 bit for intermediate steps
		func1 = (smoothblitfunc_t)smoothzoomblit_8_to_8bit;
		if (destbitdepth == 8)
			func2 = (smoothblitfunc_t)smoothzoomblit_8_to_8bit;
		else
			func2 = (smoothblitfunc_t)smoothzoomblit_8_to_32bit;
	}

	// Scale in 2 or 3 steps
	int zoom0 = 1, zoom1 = 0, zoom2 = 0;
	int finalsmooth = 1;
	if (zoom == 4) { zoom1 = 2; zoom2 = 2; }
	else if (zoom == 6) { zoom1 = 3; zoom2 = 2; }
	else if (zoom == 8) { zoom0 = 2, zoom1 = 2; zoom2 = 2; }
	else if (zoom == 9) { zoom1 = 3; zoom2 = 3; }
	else if (zoom == 12) { zoom0 = 2; zoom1 = 3; zoom2 = 2; }
	else if (zoom == 16) { zoom0 = 2; zoom1 = 2; zoom2 = 4; finalsmooth = 0; }
	else {
		// Still attempt to smooth zooms like 5x, 7x, but the effect is very slight
		return false;
	}
	int zoom01 = zoom0 * zoom1;

	void *intermediate_buffer;
	intermediate_buffer = malloc(size.w * size.h * zoom01 * zoom01 * srcbitdepth / 8);
	if (!intermediate_buffer)
		debugc(errFatalError, "multismoothblit: malloc failed");
	void *first_buffer = srcbuffer;

	if (zoom0 > 1) {
		first_buffer = destbuffer;
		func1(srcbuffer, first_buffer, size, size.w * zoom0, zoom0, 1, pal);
	}
	func1(first_buffer, intermediate_buffer, (XYPair){size.w * zoom0, size.h * zoom0}, size.w * zoom01, zoom1, 1, pal);
	func2(intermediate_buffer, destbuffer, (XYPair){size.w * zoom01, size.h * zoom01}, pitch, zoom2, finalsmooth, pal);
	free(intermediate_buffer);
	return true;
}

#define MIN(x, y) ((x) < (y) ? (x) : (y))
#define MAX(x, y) ((x) > (y) ? (x) : (y))
#define CLAMP(x, y, z) MIN(MAX(x, y), z)

#define SCALEGETPIXEL(_a, _b, _c, _d) \
	((_a *)_b)[CLAMP(_d, 0, size.h - 1) * size.w + CLAMP(_c, 0, size.w - 1)];

#define SCALEGETSAMPLE1(_a) \
_a B = SCALEGETPIXEL(_a, srcbuffer, x + 0, y - 1); \
_a D = SCALEGETPIXEL(_a, srcbuffer, x - 1, y + 0); \
_a E = SCALEGETPIXEL(_a, srcbuffer, x + 0, y + 0); \
_a F = SCALEGETPIXEL(_a, srcbuffer, x + 1, y + 0); \
_a H = SCALEGETPIXEL(_a, srcbuffer, x + 0, y + 1); \

#define SCALEGETSAMPLE2(_a) \
_a A = SCALEGETPIXEL(_a, srcbuffer, x - 1, y - 1); \
_a C = SCALEGETPIXEL(_a, srcbuffer, x + 1, y - 1); \
_a G = SCALEGETPIXEL(_a, srcbuffer, x - 1, y + 1); \
_a I = SCALEGETPIXEL(_a, srcbuffer, x + 1, y + 1); \

#define SCALEGETSAMPLE3(_a) \
_a J = SCALEGETPIXEL(_a, srcbuffer, x + 0, y - 2); \
_a K = SCALEGETPIXEL(_a, srcbuffer, x - 2, y + 0); \
_a L = SCALEGETPIXEL(_a, srcbuffer, x + 2, y + 0); \
_a M = SCALEGETPIXEL(_a, srcbuffer, x + 0, y + 2);

#define SCALE2XFILL \
E0 = E; \
E1 = E; \
E2 = E; \
E3 = E;

#define SCALE3XFILL \
SCALE2XFILL; \
E4 = E; \
E5 = E; \
E6 = E; \
E7 = E; \
E8 = E;

// https://www.scale2x.it/algorithm

#define SCALEORIGRULE1 \
E0 = D == B ? D : E; \
E1 = B == F ? F : E; \
E2 = D == H ? D : E; \
E3 = H == F ? F : E;

#define SCALEORIGRULE2 \
E5 = (D == B && E != C) || (B == F && E != A) ? B : E; \
E6 = (D == B && E != G) || (D == H && E != A) ? D : E; \
E7 = (B == F && E != I) || (H == F && E != C) ? F : E; \
E8 = (D == H && E != I) || (H == F && E != G) ? H : E;

#define SCALE2XORIG(_a) \
SCALEGETSAMPLE1(_a); \
_a E0, E1, E2, E3; \
if (B != H && D != F) { \
	SCALEORIGRULE1; \
} else { \
	SCALE2XFILL; \
}

#define SCALE3XORIG(_a) \
SCALEGETSAMPLE1(_a); \
_a E0, E1, E2, E3, E4, E5, E6, E7, E8; \
if (B != H && D != F) { \
	SCALEGETSAMPLE2(_a); \
	SCALEORIGRULE1; \
	E4 = E; \
	SCALEORIGRULE2; \
} else { \
	SCALE3XFILL; \
}

// https://forums.libretro.com/t/scalenx-artifact-removal-and-algorithm-improvement/1686/6

#define SCALESFXRULE1 \
E0 = D == B && (E != A || E ==C || E == G || A == J || A == K) ? D : E; \
E1 = B == F && (E != C || E ==A || E == I || C == J || C == L) ? F : E; \
E2 = D == H && (E != G || E ==A || E == I || G == K || G == M) ? D : E; \
E3 = H == F && (E != I || E ==C || E == G || I == L || I == M) ? F : E;

#define SCALESFXRULE2 \
E5 = (D == B && E != C && (E != A || E == C || E == G || A == J || A == K) && E != C) || \
	 (B == F && E != A && (E != C || E == A || E == I || C == J || C == L) && E != A) ? B : E; \
E6 = (D == B && E != G && (E != A || E == C || E == G || A == J || A == K) && E != G) || \
	 (D == H && E != A && (E != G || E == A || E == I || G == K || G == M) && E != A) ? D : E; \
E7 = (B == F && E != I && (E != I || E == C || E == G || I == L || I == M) && E != C) || \
	 (H == F && E != C && (E != C || E == A || E == I || C == J || C == L) && E != I) ? F : E; \
E8 = (D == H && E != I && (E != I || E == C || E == G || I == L || I == M) && E != G) || \
	 (H == F && E != G && (E != G || E == A || E == I || G == K || G == M) && E != I) ? H : E;

#define SCALE2XSFX(_a) \
SCALEGETSAMPLE1(_a); \
_a E0, E1, E2, E3; \
if (B != H && D != F) { \
	SCALEGETSAMPLE2(_a); \
	SCALEGETSAMPLE3(_a); \
	SCALESFXRULE1; \
} else { \
	SCALE2XFILL; \
}

#define SCALE3XSFX(_a) \
SCALEGETSAMPLE1(_a); \
_a E0, E1, E2, E3, E4, E5, E6, E7, E8; \
if (B != H && D != F) { \
	SCALEGETSAMPLE2(_a); \
	SCALEGETSAMPLE3(_a); \
	SCALESFXRULE1; \
	E4 = E; \
	SCALESFXRULE2; \
} else { \
	SCALE3XFILL; \
}

#define SCALE2X(_a) SCALE2XSFX(_a) 
#define SCALE3X(_a) SCALE3XSFX(_a) 

void smoothzoomblit_8_to_8bit(uint8_t *srcbuffer, uint8_t *destbuffer, XYPair size, int pitch, int zoom, int smooth, RGBcolor dummypal[]) {
//srcbuffer: source w x h buffer paletted 8 bit
//destbuffer: destination scaled buffer pitch x h*zoom also 8 bit
//supports zoom 1 to 16

	if (multismoothblit(8, 8, srcbuffer, destbuffer, size, pitch, zoom, &smooth, dummypal))
		return;

	if (smooth == 1 && zoom == 2) {
	
		int x, y;
		
		for (y = 0; y < size.h; y++) {

			uint8_t *row0 = destbuffer + (y * zoom + 0) * pitch;
			uint8_t *row1 = destbuffer + (y * zoom + 1) * pitch;

			for (x = 0; x < size.w; x++) {
			
				SCALE2X(uint8_t);
			
				*row0++ = E0;
				*row0++ = E1;

				*row1++ = E2;
				*row1++ = E3;
			}
		}
		
		return;
	}
 
	if (smooth == 1 && zoom == 3) {
	
		int x, y;
		
		for (y = 0; y < size.h; y++) {
		
			uint8_t *row0 = destbuffer + (y * zoom + 0) * pitch;
			uint8_t *row1 = destbuffer + (y * zoom + 1) * pitch;
			uint8_t *row2 = destbuffer + (y * zoom + 2) * pitch;
		
			for (x = 0; x < size.w; x++) {

				SCALE3X(uint8_t);

				*row0++ = E0;
				*row0++ = E5;
				*row0++ = E1;

				*row1++ = E6;
				*row1++ = E4;
				*row1++ = E7;

				*row2++ = E2;
				*row2++ = E8;
				*row2++ = E3;
			}
		}
		
		return;
	}

	uint8_t *sptr;
	int i, j;
	int wide = size.w * zoom;

	sptr = destbuffer;

	if (zoom == 1) {
		for (i = 0; i <= size.h - 1; i++) {
			memcpy(sptr, srcbuffer, size.w);
			srcbuffer += size.w;
			sptr += pitch;
		}
	} else {
		for (j = 0; j <= size.h - 1; j++) {
			// Write up to 4 copies of a pixel at a time.
			// Skip last 4 pixels so that we can never write off the end of the image buffer.
			for (i = size.w; i >= 4; i--) {
				uint32_t temp = *srcbuffer++;
				temp *= 0x1010101;
				//temp |= temp << 16;
				//temp |= temp << 8;
				((uint32_t *)sptr)[0] = temp;
				if (zoom > 4) {
					((uint32_t *)sptr)[1] = temp;
					if (zoom > 8) {
						((uint32_t *)sptr)[2] = temp;
						if (zoom > 12)
							((uint32_t *)sptr)[3] = temp;
					}
				}
				sptr += zoom;
			}
			while (i-- > 0) {
				uint8_t temp = *srcbuffer++;
				for (int ii = zoom; ii--; )
					*sptr++ = temp;
			}
			sptr += pitch - wide;
			//repeat row zoom times
			for (i = 2; i <= zoom; i++) {
				memcpy(sptr, sptr - pitch, wide);
				sptr += pitch;
			}
		}
	}
}

void smoothzoomblit_8_to_32bit(uint8_t *srcbuffer, RGBcolor *destbuffer, XYPair size, int pitch, int zoom, int smooth, RGBcolor pal[]) {
//srcbuffer: source w x h buffer paletted 8 bit
//destbuffer: destination scaled buffer pitch x h*zoom 32 bit (so pitch is in pixels, not bytes)
//supports any positive zoom

	if (multismoothblit(8, 32, srcbuffer, destbuffer, size, pitch, zoom, &smooth, pal))
		return;

	if (smooth == 1 && zoom == 2) {
	
		int x, y;
		
		for (y = 0; y < size.h; y++) {

			uint32_t *row0 = (uint32_t *)destbuffer + (y * zoom + 0) * pitch;
			uint32_t *row1 = (uint32_t *)destbuffer + (y * zoom + 1) * pitch;

			for (x = 0; x < size.w; x++) {
			
				SCALE2X(uint8_t);

				*row0++ = pal[E0].col;
				*row0++ = pal[E1].col;

				*row1++ = pal[E2].col;
				*row1++ = pal[E3].col;
			}
		}
		
		return;
	}
 
	if (smooth == 1 && zoom == 3) {
	
		int x, y;
		
		for (y = 0; y < size.h; y++) {
		
			uint32_t *row0 = (uint32_t *)destbuffer + (y * zoom + 0) * pitch;
			uint32_t *row1 = (uint32_t *)destbuffer + (y * zoom + 1) * pitch;
			uint32_t *row2 = (uint32_t *)destbuffer + (y * zoom + 2) * pitch;
		
			for (x = 0; x < size.w; x++) {

				SCALE3X(uint8_t);

				*row0++ = pal[E0].col;
				*row0++ = pal[E5].col;
				*row0++ = pal[E1].col;

				*row1++ = pal[E6].col;
				*row1++ = pal[E4].col;
				*row1++ = pal[E7].col;

				*row2++ = pal[E2].col;
				*row2++ = pal[E8].col;
				*row2++ = pal[E3].col;
			}
		}
		
		return;
	}

	uint32_t *sptr;
	uint32_t pixel;
	int i, j;
	int wide = size.w * zoom;

	sptr = (uint32_t *)destbuffer;

	for (j = 0; j <= size.h - 1; j++) {
		for (i = 0; i <= size.w - 1; i++) {
			//get colour
			pixel = pal[*srcbuffer].col;
			//zoom sptrs for each srcbuffer
			for (int k = zoom; k >= 1; k--) {
				*sptr = pixel;
				sptr += 1;
			}
			srcbuffer += 1;
		}
		sptr += pitch - wide;
		//repeat row zoom times
		for (i = 2; i <= zoom; i++) {
			memcpy(sptr, sptr - pitch, 4 * wide);
			sptr += pitch;
		}
	}
}

void smoothzoomblit_32_to_32bit(RGBcolor *srcbuffer, RGBcolor *destbuffer, XYPair size, int pitch, int zoom, int smooth, RGBcolor dummypal[]) {
//srcbuffer: source w*h buffer, 32 bit
//destbuffer: destination scaled buffer (pitch*zoom)*(h*zoom), 32 bit (so pitch is in pixels, not bytes)
//supports any positive zoom

	if (multismoothblit(32, 32, srcbuffer, destbuffer, size, pitch, zoom, &smooth, dummypal))
		return;

	if (smooth == 1 && zoom == 2) {
	
		int x, y;
		
		for (y = 0; y < size.h; y++) {

			uint32_t *row0 = (uint32_t *)destbuffer + (y * zoom + 0) * pitch;
			uint32_t *row1 = (uint32_t *)destbuffer + (y * zoom + 1) * pitch;

			for (x = 0; x < size.w; x++) {
			
				SCALE2X(uint32_t);

				*row0++ = E0;
				*row0++ = E1;

				*row1++ = E2;
				*row1++ = E3;
			}
		}
		
		return;
	}
 
	if (smooth == 1 && zoom == 3) {
	
		int x, y;
		
		for (y = 0; y < size.h; y++) {
		
			uint32_t *row0 = (uint32_t *)destbuffer + (y * zoom + 0) * pitch;
			uint32_t *row1 = (uint32_t *)destbuffer + (y * zoom + 1) * pitch;
			uint32_t *row2 = (uint32_t *)destbuffer + (y * zoom + 2) * pitch;
		
			for (x = 0; x < size.w; x++) {

				SCALE3X(uint32_t);

				*row0++ = E0;
				*row0++ = E5;
				*row0++ = E1;

				*row1++ = E6;
				*row1++ = E4;
				*row1++ = E7;

				*row2++ = E2;
				*row2++ = E8;
				*row2++ = E3;
			}
		}
		
		return;
	}

	uint32_t *sptr;
	uint32_t pixel;
	int i, j;
	int wide = size.w * zoom;

	sptr = (uint32_t *)destbuffer;

	for (j = 0; j <= size.h - 1; j++) {
		for (i = 0; i <= size.w - 1; i++) {
			pixel = (*srcbuffer++).col;
			for (int k = zoom; k > 0; k--) {
				*sptr++ = pixel;
			}
		}
		sptr += pitch - wide;
		uint32_t *srcline = sptr - pitch;

		//repeat row zoom times
		for (i = 2; i <= zoom; i++) {
			memcpy(sptr, srcline, 4 * wide);
			sptr += pitch;
		}
	}
}
