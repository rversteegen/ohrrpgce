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
#include "array.h"
int blit_mode = 0;
FBCALL double       fb_Timer            ( void );


int double_comp(double *a, double *b) {
	if (*a < *b) return -1;
	if (*a > *b) return 0;
	return 0;
}

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
	int finalsmooth = 0;
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

// https://www.scale2x.it/algorithm

// input
// A B C
// D E F
// G H I

// 2x output
// E0 E1
// E2 E3

// 3x output
// E0 E5 E1
// E6 E4 E7
// E2 E8 E3

#define MIN(x, y) ((x) < (y) ? (x) : (y))
#define MAX(x, y) ((x) > (y) ? (x) : (y))
#define CLAMP(x, y, z) MIN(MAX(x, y), z)

#define SCALEGETPIXEL(_a, _b, _c) \
	((_a *)srcbuffer)[CLAMP(_c, 0, size.h - 1) * size.w + CLAMP(_b, 0, size.w - 1)];

#define SCALEGETSAMPLE1(_a) \
_a E = SCALEGETPIXEL(_a, x, y); \
_a B = SCALEGETPIXEL(_a, x, y - 1); \
_a D = SCALEGETPIXEL(_a, x - 1, y); \
_a F = SCALEGETPIXEL(_a, x + 1, y); \
_a H = SCALEGETPIXEL(_a, x, y + 1);

#define SCALEGETSAMPLE2(_a) \
_a A = SCALEGETPIXEL(_a, x - 1, y - 1); \
_a C = SCALEGETPIXEL(_a, x + 1, y - 1); \
_a G = SCALEGETPIXEL(_a, x - 1, y + 1); \
_a I = SCALEGETPIXEL(_a, x + 1, y + 1);

#define SCALERULE1 \
E0 = D == B ? D : E; \
E1 = B == F ? F : E; \
E2 = D == H ? D : E; \
E3 = H == F ? F : E;

#define SCALERULE2 \
E5 = (D == B && E != C) || (B == F && E != A) ? B : E; \
E6 = (D == B && E != G) || (D == H && E != A) ? D : E; \
E7 = (B == F && E != I) || (H == F && E != C) ? F : E; \
E8 = (D == H && E != I) || (H == F && E != G) ? H : E;

#define SCALE2X(_a) \
SCALEGETSAMPLE1(_a); \
_a E0, E1, E2, E3; \
if (B != H && D != F) { \
	SCALERULE1; \
} else { \
	E0 = E; \
	E1 = E; \
	E2 = E; \
	E3 = E; \
}

#define SCALE3X(_a) \
SCALEGETSAMPLE1(_a); \
_a E0, E1, E2, E3, E4, E5, E6, E7, E8; \
if (B != H && D != F) { \
	SCALEGETSAMPLE2(_a); \
	SCALERULE1; \
	SCALERULE2; \
} else { \
	E0 = E; \
	E1 = E; \
	E2 = E; \
	E3 = E; \
	E5 = E; \
	E6 = E; \
	E7 = E; \
	E8 = E; \
} \
E4 = E;


static uint32_t getpixel8(uint8_t *buffer, int x, int y, const XYPair size) {
/*
	if (x < 0) {
		x = 0;
	} else if (x > size.w - 1) {
		x = size.w - 1;
	}
	
	if (y < 0) {
		y = 0;
	} else if (y > size.h - 1) {
		y = size.h - 1;
	}
*/	
	return buffer[y * size.w + x];
}


void smoothzoomblit_8_to_8bit(uint8_t *srcbuffer, uint8_t *destbuffer, XYPair size, int pitch, int zoom, int smooth, RGBcolor dummypal[]) {
//srcbuffer: source w x h buffer paletted 8 bit
//destbuffer: destination scaled buffer pitch x h*zoom also 8 bit
//supports zoom 1 to 16

	int pix = size.w*size.h;
	
	if (multismoothblit(8, 8, srcbuffer, destbuffer, size, pitch, zoom, &smooth, dummypal))
		return;

	double start_timer = fb_Timer();

	if (smooth == 1 && zoom == 2) {

		if(blit_mode == 1) {
	
		int x, y;
		
		for (y = 0; y < size.h; y++) {

			uint8_t *row0 = destbuffer + y * zoom * pitch;
			uint8_t *row1 = row0 + pitch;

			for (x = 0; x < size.w; x++) {
			
				SCALE2X(uint8_t);
			
				*row0++ = E0;
				*row0++ = E1;

				*row1++ = E2;
				*row1++ = E3;
			}
		}
		goto end;
		return;

		} else if (blit_mode == 2) {

			uint8_t *restrict outbuf = (uint8_t *)calloc(size.w, 2);
			//uint8_t *restrict srcbuffer2 = (uint8_t *)srcbuffer;
			//uint8_t *restrict destbuffer2 = (uint8_t *)destbuffer;

			for (int y = 1; y < size.h; y++) {

				uint8_t *srcrowup = srcbuffer + (y - 1) * size.w;
				uint8_t *srcrow = srcbuffer + y * size.w;
				uint8_t *srcrowdown = srcbuffer + (y + 1) * size.w;
				uint8_t *rowup = destbuffer + (y * zoom - 1) * pitch;
				uint8_t *row0 = destbuffer + (y * zoom + 0) * pitch;

				if (y == 0) srcrowup = srcrow;
				if (y == size.h - 1) srcrowdown = srcrow;

				for (int x = 0; x < size.w; x++) {
					// uint8_t B = srcbuffer2[(y - 1) * size.w + (x + 0)];
					// uint8_t D = srcbuffer2[(y + 0) * size.w + (x - 1)];
					// uint8_t E = srcbuffer2[(y + 0) * size.w + (x + 0)];
					// uint8_t F = srcbuffer2[(y + 0) * size.w + (x + 1)];
					// uint8_t H = srcbuffer2[(y + 1) * size.w + (x + 0)];

					uint8_t B = srcrowup[x];
					uint8_t D = srcrow[x - 1];
					uint8_t E = srcrow[x];
					uint8_t F = srcrow[x + 1];
					uint8_t H = srcrowdown[x];

					uint8_t E0, E1, E2, E3;

					uint8_t B2 = outbuf[x * zoom + 0];
					uint8_t B3 = outbuf[x * zoom + 1];
					bool swapB2 = B2 != B;
					bool swapB3 = B3 != B;

					if (B != H && D != F) {
						E0 = D == B && !swapB2 ? D : E;
						if (D == B) B2 = B;

						E1 = B == F && !swapB3 ? F : E;
						if (B == F) B3 = B;

						E2 = D == H ? D : E;
						E3 = H == F ? F : E;
					} else {
						E0 = E;
						E1 = E;
						E2 = E;
						E3 = E;
					}

					//destbuffer[(y * zoom + 0) * pitch + x * zoom + 0] = E0;
					//destbuffer[(y * zoom + 0) * pitch + x * zoom + 1] = E1;
					//destbuffer[(y * zoom - 1) * pitch + x * zoom + 0] = B2;
					//destbuffer[(y * zoom - 1) * pitch + x * zoom + 1] = B3;

					*row0++ = E0;
					*row0++ = E1;
					//if (y) {
					*rowup++ = B2;
					*rowup++ = B3;
					//}

					outbuf[x * zoom + 0] = E2;
					outbuf[x * zoom + 1] = E3;
				}
			}
			{
			uint8_t *rowup = destbuffer + (size.h * zoom - 1) * pitch;
			memcpy(rowup, outbuf, zoom * size.w);
			}
			free(outbuf);
			goto end;

		} // blit_mode=3

		else

		if (blit_mode == 3) {

			int x, y;
			
		
			for (y = 0; y < size.h; y++) {

				uint8_t *srcrowup = srcbuffer + (y - 1) * size.w;
				uint8_t *srcrow = srcbuffer + y * size.w;
				uint8_t *srcrowdown = srcbuffer + (y + 1) * size.w;

				if (y == 0) srcrowup = srcrow;
				if (y == size.h - 1) srcrowdown = srcrow;

				uint8_t *row0 = destbuffer + (y * zoom + 0) * pitch;
				uint8_t *row1 = destbuffer + (y * zoom + 1) * pitch;

				for (x = 0; x < size.w; x++) {
			
					// uint8_t B = getpixel8(srcbuffer, x + 0, y - 1, size);
					// uint8_t D = getpixel8(srcbuffer, x - 1, y + 0, size);
					// uint8_t E = getpixel8(srcbuffer, x + 0, y + 0, size);
					// uint8_t F = getpixel8(srcbuffer, x + 1, y + 0, size);
					// uint8_t H = getpixel8(srcbuffer, x + 0, y + 1, size);

					uint8_t B = srcrowup[x];
					uint8_t D = srcrow[x - 1];
					uint8_t E = srcrow[x];
					uint8_t F = srcrow[x + 1];
					uint8_t H = srcrowdown[x];

					uint8_t E0, E1, E2, E3;

					if (B != H && D != F) {
						E0 = D == B ? D : E;
						E1 = B == F ? F : E;
						E2 = D == H ? D : E;
						E3 = H == F ? F : E;
					} else {
						E0 = E;
						E1 = E;
						E2 = E;
						E3 = E;
					}

					*row0++ = E0;
					*row0++ = E1;

					*row1++ = E2;
					*row1++ = E3;
				}
			
				//if(pix > 70000) break;

			}
		
			goto end;
		}


	} //zoom=2
	
	if (smooth == 1 && zoom == 3) {
	

	if (blit_mode == 1) {
		int x, y;

		for (y = 0; y < size.h; y++) {
		
			uint8_t *row0 = destbuffer + y * zoom * pitch;
			uint8_t *row1 = row0 + pitch;
			uint8_t *row2 = row1 + pitch;
		
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
		goto end;
		return;
/*
	} else if (blit_mode == 2) {

		int x, y;

		for (y = 0; y < size.h; y++) {

			uint8_t *row0 = destbuffer + (y * zoom + 0) * pitch;
			uint8_t *row1 = destbuffer + (y * zoom + 1) * pitch;
			uint8_t *row2 = destbuffer + (y * zoom + 2) * pitch;


			for (x = 0; x < size.w; x++) {


				SCALEGETSAMPLE1(uint8_t);
				uint8_t E0, E1, E2, E3, E4, E5, E6, E7, E8;
				if (B != H && D != F) {
					SCALEGETSAMPLE2(uint8_t);

					E0 = D == B ? D : E;
					E1 = B == F ? F : E;
					E2 = D == H ? D : E;
					E3 = H == F ? F : E;

					E5 = (D == B && E != C) || (B == F && E != A) ? B : E;
					E6 = (D == B && E != G) || (D == H && E != A) ? D : E;
					E7 = (B == F && E != I) || (H == F && E != C) ? F : E;
					E8 = (D == H && E != I) || (H == F && E != G) ? H : E;
				} else {
					E0 = E;
					E1 = E;
					E2 = E;
					E3 = E;
					E5 = E;
					E6 = E;
					E7 = E;
					E8 = E;
				}
				E4 = E;

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
		goto end;
*/
	} else if (blit_mode == 4) {  // ANGULAR/SQUARISH
		int x, y;
		
		for (y = 1; y < size.h - 1; y++) {
		
			uint8_t *row0 = (uint8_t *)destbuffer + y * zoom * pitch;
			uint8_t *row1 = row0 + pitch;
			uint8_t *row2 = row1 + pitch;
		
			for (x = 0; x < size.w-1; x++) {

				SCALEGETSAMPLE1(uint8_t);
				uint8_t E0, E1, E2, E3, E4, E5, E6, E7, E8;
				//if (B != H && D != F) {
					SCALEGETSAMPLE2(uint8_t);

					E0 = D == B ? D : E;
					E1 = B == F ? F : E;
					E2 = D == H ? D : E;
					E3 = H == F ? F : E;
/*
					E5 = (D == B && E != C) || (B == F && E != A) ? B : E;
					E6 = (D == B && E != G) || (D == H && E != A) ? D : E;
					E7 = (B == F && E != I) || (H == F && E != C) ? F : E;
					E8 = (D == H && E != I) || (H == F && E != G) ? H : E;
*/
					/* E5 = (D == B) || (B == F) ? B : E; */
					/* E6 = (D == B) || (D == H) ? D : E; */
					/* E7 = (B == F) || (H == F) ? F : E; */
					/* E8 = (D == H) || (H == F) ? H : E; */

					E5 = E;
					E6 = E;
					E7 = E;
					E8 = E;
/*
				} else {
					E0 = E;
					E1 = E;
					E2 = E;
					E3 = E;
					E5 = E;
					E6 = E;
					E7 = E;
					E8 = E;
				}*/
				E4 = E;

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
		goto end;

	} else if (blit_mode == 2) {  // SHARP SMOOTH FILTER
		int x, y;
		
		for (y = 1; y < size.h - 1; y++) {
		
			uint8_t *row0 = (uint8_t *)destbuffer + y * zoom * pitch;
			uint8_t *row1 = row0 + pitch;
			uint8_t *row2 = row1 + pitch;
		
			for (x = 0; x < size.w-1; x++) {

				SCALEGETSAMPLE1(uint8_t);
				SCALEGETSAMPLE2(uint8_t);
				uint8_t E0, E1, E2, E3, E4, E5, E6, E7, E8;

				if (B != H && D != F) {
					E0 = D == B ? D : E;
					E1 = B == F ? F : E;
					E2 = D == H ? D : E;
					E3 = H == F ? F : E;
				} else {
					E0 = E;
					E1 = E;
					E2 = E;
					E3 = E;
				}

				// PREVIOUS
				// E0 = D == B && E != A ? D : E;
				// E1 = B == F && E != C ? F : E;
				// E2 = D == H && E != G ? D : E;
				// E3 = H == F && E != I ? F : E;


				E0 = D == B && (E == C || E == G) ? D : E;
				E1 = B == F && (E == A || E == I) ? F : E;
				E2 = D == H && (E == A || E == I) ? D : E;
				E3 = H == F && (E == C || E == G) ? F : E;

//				if ((B != H && D != F) || (A != C || G != I)) {


					#define LINERULE(Ex, Ec, LE, RE, LN, N, RN) \ 
					if (LE == E && E == RE) \
						if (LN == N && N == RN) {Ex = N; Ec = N;};

					E5 = E;
					LINERULE(E5, E0, G, F, D, B, C);
					LINERULE(E5, E1, D, I, A, B, F);
					E6 = E;
					LINERULE(E6, E2, I, B, H, D, A);
					LINERULE(E6, E0, H, C, G, D, B);
					E7 = E;
					LINERULE(E7, E1, A, H, B, F, I);
					LINERULE(E7, E3, B, G, C, F, H);
					E8 = E;
					LINERULE(E8, E2, A, F, D, H, I);
					LINERULE(E8, E3, D, C, G, H, F);

					// E5 = (D == B) || (B == F) ? B : E;
					// E6 = (D == B) || (D == H) ? D : E;
					// E7 = (B == F) || (H == F) ? F : E;
					// E8 = (D == H) || (H == F) ? H : E;

/*
				if ((B != H && D != F)) { //|| (A != C || G != I)) {

					E5 = (D == B && E != C) || (B == F && E != A) ? B : E;
					E6 = (D == B && E != G) || (D == H && E != A) ? D : E;
					E7 = (B == F && E != I) || (H == F && E != C) ? F : E;
					E8 = (D == H && E != I) || (H == F && E != G) ? H : E;

				} else {
					// E0 = E;
					// E1 = E;
					// E2 = E;
					// E3 = E;
					E5 = E;
					E6 = E;
					E7 = E;
					E8 = E;
				}
*/
				E4 = E;

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
		goto end;



	} else if (blit_mode == 3) {  // SMOOTH FILTER (bugs: isolated diagonal lines are pinched, isolate pixels become diamonds)
		int x, y;
		
		for (y = 1; y < size.h - 1; y++) {
		
			uint8_t *row0 = (uint8_t *)destbuffer + y * zoom * pitch;
			uint8_t *row1 = row0 + pitch;
			uint8_t *row2 = row1 + pitch;
		
			for (x = 0; x < size.w-1; x++) {

				SCALEGETSAMPLE1(uint8_t);
				SCALEGETSAMPLE2(uint8_t);
				uint8_t E0, E1, E2, E3, E4, E5, E6, E7, E8;

				// Using thse rules causes line ends (OK) and V-corners (looks bad)
				// and isolated diagonal lines (bad) be to chunky squares
				// but they smooth out sharp corners without turning isolated pixels
				// into diamonds
				if (B != H && D != F) {
					E0 = D == B ? D : E;
					E1 = B == F ? F : E;
					E2 = D == H ? D : E;
					E3 = H == F ? F : E;
				} else {
					E0 = E;
					E1 = E;
					E2 = E;
					E3 = E;
				}


				// // PREVIOUS
				// E0 = D == B && E != A ? D : E;
				// E1 = B == F && E != C ? F : E;
				// E2 = D == H && E != G ? D : E;
				// E3 = H == F && E != I ? F : E;


//				if ((B != H && D != F) || (A != C || G != I)) {


					// E5 = E;
					// if (G == E && E == F) { // Can smooth away E5
					// 	//E5 = (D == B) || (B == F) ? B : E;
					// 	if (D == B && B == C) E5 = B;
					// }
					// if (D == E && E == I) {
					// 	if (A == B && B == F) E5 = B;
					// }

					#define LINERULE(Ex, Ec, LE, RE, LN, N, RN) \ 
					if (LE == E && E == RE) \
						if (LN == N && N == RN) {Ex = N; Ec = N;};

					E5 = E;
					LINERULE(E5, E0, G, F, D, B, C);
					LINERULE(E5, E1, D, I, A, B, F);


					E6 = E;
					LINERULE(E6, E2, I, B, H, D, A);
					LINERULE(E6, E0, H, C, G, D, B);


					E7 = E;
					LINERULE(E7, E1, A, H, B, F, I);
					LINERULE(E7, E3, B, G, C, F, H);

					// if (A == E && E == H) { // Can smooth away E5
					// 	if (B == F && F == I) E7 = F;
					// }

					E8 = E;
					LINERULE(E8, E2, A, F, D, H, I);
					LINERULE(E8, E3, D, C, G, H, F);




					// if (G == E && H == E) {
					// 	E5 = E;
					// 	E6 = E;
					// }

					// E5 = (D == B) || (B == F) ? B : E;
					// E6 = (D == B) || (D == H) ? D : E;
					// E7 = (B == F) || (H == F) ? F : E;
					// E8 = (D == H) || (H == F) ? H : E;

/*
				if ((B != H && D != F)) { //|| (A != C || G != I)) {

					E5 = (D == B && E != C) || (B == F && E != A) ? B : E;
					E6 = (D == B && E != G) || (D == H && E != A) ? D : E;
					E7 = (B == F && E != I) || (H == F && E != C) ? F : E;
					E8 = (D == H && E != I) || (H == F && E != G) ? H : E;

				} else {
					// E0 = E;
					// E1 = E;
					// E2 = E;
					// E3 = E;
					E5 = E;
					E6 = E;
					E7 = E;
					E8 = E;
				}
*/
				E4 = E;

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
		goto end;

	}
	
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


  end:;
if (smooth) {
	double ttime = 2.4e9 * (fb_Timer() - start_timer) / (double)pix;
	static double *besttimes;
	if (! besttimes) array_new((array_t*)&besttimes, 9, 0, &type_table(double));
	static int tickn = 0, lastw;
//if (tickn ==0 || ttime > besttime) besttime = ttime;
	if (tickn <0)
		tickn++;
	else
		besttimes[tickn++] = ttime;
	if (lastw != size.w) tickn=-5;
	
	lastw= size.w;
	
	if(tickn == 9) {
		tickn = 0;
		array_sort((array_t)besttimes, (FnCompare)double_comp);

		printf("blit scale=%d: %.3f cyc/px w= %d\n", blit_mode, besttimes[4], size.w);
	}
}


// 	double ttime = 1e3 * (fb_Timer() - start_timer);
// 	static double *besttimes;
// 	if (! besttimes) array_new((array_t*)&besttimes, 9, 0, &type_table(double));
// 	static int tickn = 0;
// //if (tickn ==0 || ttime > besttime) besttime = ttime;
// 	besttimes[tickn++] = ttime;
// 	if(tickn == 9) {
// 		tickn = 0;
// 		array_sort((array_t)besttimes, (FnCompare)double_comp);

// 		printf("blit scale=%d: %.3fms\n", blit_mode, besttimes[4]);
// 	}

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

			uint32_t *row0 = (uint32_t *)destbuffer + y * zoom * pitch;
			uint32_t *row1 = row0 + pitch;

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
		
			uint32_t *row0 = (uint32_t *)destbuffer + y * zoom * pitch;
			uint32_t *row1 = row0 + pitch;
			uint32_t *row2 = row1 + pitch;
		
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

	double start_timer = fb_Timer();

	if (multismoothblit(32, 32, srcbuffer, destbuffer, size, pitch, zoom, &smooth, dummypal))
		return;
	int pix = size.w*size.h;

	if (smooth == 1 && zoom == 2) {
	
		int x, y;
		
		for (y = 0; y < size.h; y++) {

			uint32_t *row0 = (uint32_t *)destbuffer + y * zoom * pitch;
			uint32_t *row1 = row0 + pitch;

			for (x = 0; x < size.w; x++) {
			
				SCALE2X(uint32_t);

				*row0++ = E0;
				*row0++ = E1;

				*row1++ = E2;
				*row1++ = E3;
			}
		}
		goto end;
		
		return;
	}
 
	if (smooth == 1 && zoom == 3) {
	if (blit_mode == 1) {
		int x, y;
		
		for (y = 1; y < size.h - 1; y++) {
		
			uint32_t *row0 = (uint32_t *)destbuffer + y * zoom * pitch;
			uint32_t *row1 = row0 + pitch;
			uint32_t *row2 = row1 + pitch;
		
			for (x = 0; x < size.w-1; x++) {

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
		goto end;
		
		return;
	} else if (blit_mode == 2) {
		int x, y;
		
		for (y = 1; y < size.h - 1; y++) {
		
			uint32_t *row0 = (uint32_t *)destbuffer + y * zoom * pitch;
			uint32_t *row1 = row0 + pitch;
			uint32_t *row2 = row1 + pitch;
		
			for (x = 0; x < size.w-1; x++) {

				SCALEGETSAMPLE1(uint32_t);
				uint32_t E0, E1, E2, E3, E4, E5, E6, E7, E8;
				if (B != H && D != F) {
					SCALEGETSAMPLE2(uint32_t);

					E0 = D == B ? D : E;
					E1 = B == F ? F : E;
					E2 = D == H ? D : E;
					E3 = H == F ? F : E;
/*
					E5 = (D == B && E != C) || (B == F && E != A) ? B : E;
					E6 = (D == B && E != G) || (D == H && E != A) ? D : E;
					E7 = (B == F && E != I) || (H == F && E != C) ? F : E;
					E8 = (D == H && E != I) || (H == F && E != G) ? H : E;
*/
					E5 = (D == B) || (B == F) ? B : E;
					E6 = (D == B) || (D == H) ? D : E;
					E7 = (B == F) || (H == F) ? F : E;
					E8 = (D == H) || (H == F) ? H : E;
				} else {
					E0 = E;
					E1 = E;
					E2 = E;
					E3 = E;
					E5 = E;
					E6 = E;
					E7 = E;
					E8 = E;
				}
				E4 = E;

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
		goto end;

	} else if (blit_mode == 3) {
		int x, y;
		
		for (y = 1; y < size.h - 1; y++) {
		
			uint32_t *row0 = (uint32_t *)destbuffer + y * zoom * pitch;
			uint32_t *row1 = row0 + pitch;
			uint32_t *row2 = row1 + pitch;
		
			for (x = 0; x < size.w-1; x++) {

				SCALEGETSAMPLE1(uint32_t);
				uint32_t E0, E1, E2, E3, E4, E5, E6, E7, E8;
				if (B != H && D != F) {
					SCALEGETSAMPLE2(uint32_t);

					E0 = D == B ? D : E;
					E1 = B == F ? F : E;
					E2 = D == H ? D : E;
					E3 = H == F ? F : E;
/*
					E5 = (D == B && E != C) || (B == F && E != A) ? B : E;
					E6 = (D == B && E != G) || (D == H && E != A) ? D : E;
					E7 = (B == F && E != I) || (H == F && E != C) ? F : E;
					E8 = (D == H && E != I) || (H == F && E != G) ? H : E;
*/
					E5 = (D == B) || (B == F) ? B : E;
					E6 = (D == B) || (D == H) ? D : E;
					E7 = (B == F && E != I) || (H == F && E != C) ? F : E;
					E8 = (D == H && E != I) || (H == F && E != G) ? H : E;
				} else {
					E0 = E;
					E1 = E;
					E2 = E;
					E3 = E;
					E5 = E;
					E6 = E;
					E7 = E;
					E8 = E;
				}
				E4 = E;

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
		goto end;

	}
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


  end:;
	double ttime = 1e9 * (fb_Timer() - start_timer) / (double)pix;
	static double *besttimes;
	if (! besttimes) array_new((array_t*)&besttimes, 9, 0, &type_table(double));
	static int tickn = 0, lastw;
//if (tickn ==0 || ttime > besttime) besttime = ttime;
	if (tickn <0)
		tickn++;
	else
		besttimes[tickn++] = ttime;
	if (lastw != size.w) tickn=-5;
	
	lastw= size.w;
	
	if(tickn == 9) {
		tickn = 0;
		array_sort((array_t)besttimes, (FnCompare)double_comp);

		printf("blit32 scale=%d: %.3f ns/px w= %d\n", blit_mode, besttimes[4], size.w);
	}

}
