/*
 * blit.c - Expensive graphics utility functions
 *
 * Please read LICENSE.txt for GPL License details and disclaimer of liability
 */


#include <string.h>
#include <errno.h>
#include <stdlib.h>
#include <stdint.h>
#include "allmodex.h"
#include "common.h"

//Doesn't belong here, but can't be bothered adding another .c file for it
//Trying to read errno from FB is unlikely to even link, because it's normally a macro, so this has be in C
char *get_sys_err_string() {
	return strerror(errno);
}

void blitohr(struct Frame *spr, struct Frame *destspr, struct Palette16 *pal, int startoffset, int startx, int starty, int endx, int endy, int trans) {
	int i, j;
	unsigned char *maskp, *srcp, *destp;
	int srclineinc, destlineinc;

	srcp = spr->image;

	maskp = spr->mask;
	if (maskp == NULL)
		//we could add an optimised version for this case, which is the 99% case
		maskp = srcp;

	srcp += startoffset;
	maskp += startoffset;

	srclineinc = spr->pitch - (endx - startx + 1);

	destp = destspr->image + startx + starty * destspr->pitch;
	destlineinc = destspr->pitch - (endx - startx + 1);

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
}

//horribly slow; keep putting off doing something about it
void blitohrscaled(struct Frame *spr, struct Frame *destspr, struct Palette16 *pal, int x, int y, int startx, int starty, int endx, int endy, int trans, int scale) {
	unsigned char *sptr;
	unsigned char *mptr;
	int tx, ty;
	int pix, spix;

	sptr = destspr->image;

	mptr = spr->mask;
	if (spr->mask == 0) {
		mptr = spr->image;
	}
	
	//ty = starty
	if (trans == 0) {
		for (ty = starty; ty <= endy; ty++) {
			//tx = startx
			for (tx = startx; tx <= endx; tx++) {
				//figure out where to put the pixel
				pix = (ty * destspr->pitch) + tx;
				//and where to get the pixel from
				spix = (((ty - y) / scale) * spr->pitch) + ((tx - x) / scale);
				
				if (pal != 0)
					sptr[pix] = pal->col[spr->image[spix]];
				else
					sptr[pix] = spr->image[spix];
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
				if (mptr[spix]) {
					if (pal != 0)
						sptr[pix] = pal->col[spr->image[spix]];
					else
						sptr[pix] = spr->image[spix];
				}
			}
		}
	}
}

void smoothzoomblit_8_to_8bit(uint8_t *srcbuffer, uint8_t *destbuffer, int w, int h, int pitch, int zoom, int smooth) {
//srcbuffer: source w x h buffer paletted 8 bit
//destbuffer: destination scaled buffer pitch x h*zoom also 8 bit
//supports zoom 1 to 16
//smooth: true or false.

	uint8_t *sptr;
	int i, j;
	int wide = w * zoom, high = h * zoom;

/*
	if (zoom == 4 && smooth) {
		// Do 2x scale smoothing twice
		unsigned char *intermediate_buffer;
		intermediate_buffer = malloc(w * h * 4);
		if (!intermediate_buffer)
			debugc errDie, "smoothzoomblit: malloc failed";
		smoothzoomblit_8_to_8bit(srcbuffer, intermediate_buffer, w, h, w * 2, 2, smooth);
		smoothzoomblit_8_to_8bit(intermediate_buffer, destbuffer, w * 2, h * 2, pitch, 2, smooth);
		return;
	}
*/

	sptr = destbuffer;

	if (zoom == 1) {
		for (i = 0; i <= h - 1; i++) {
			memcpy(sptr, srcbuffer, w);
			srcbuffer += w;
			sptr += pitch;
		}
	} else {
		for (j = 0; j <= h - 1; j++) {
			// Write up to 4 copies of a pixel at a time.
			// Skip last 4 pixels so that we can never write off the end of the image buffer.
			for (i = w; i >= 4; i--) {
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

	if (smooth == 1 && zoom >= 2) {
		int pstep;
		if (zoom == 2)
			pstep = 2;
		else
			pstep = 1;
		uint8_t *sptr1, *sptr2, *sptr3;
		for (int fy = 1; fy <= high - 2; fy += pstep) {
			sptr1 = destbuffer + pitch * (fy - 1) + 1;  //(1,0)
			sptr2 = sptr1 + pitch; //(1,1)
			sptr3 = sptr2 + pitch; //(1,2)
			for (int fx = wide - 2; fx >= 1; fx--) {
				//p0=point(fx,fy)
				//p1=point(fx-1,fy-1)//nw
				//p2=point(fx+1,fy-1)//ne
				//p3=point(fx+1,fy+1)//se
				//p4=point(fx-1,fy+1)//sw
				//if p1 = p3 then p0 = p1
				//if p2 = p4 then p0 = p2
				if (sptr1[1] == sptr3[-1])
					sptr2[0] = sptr1[1];
				else
					if (sptr1[-1] == sptr3[1])
						sptr2[0] = sptr1[-1];
				
				//pset(fx,fy),p0
				sptr1 += 1;
				sptr2 += 1;
				sptr3 += 1;
			}
		}
	}
}

void smoothzoomblit_8_to_32bit(uint8_t *srcbuffer, uint32_t *destbuffer, int w, int h, int pitch, int zoom, int smooth, int pal[]) {
//srcbuffer: source w x h buffer paletted 8 bit
//destbuffer: destination scaled buffer pitch x h*zoom 32 bit (so pitch is in pixels, not bytes)
//supports any positive zoom

	uint32_t *sptr;
	uint32_t pixel;
	int i, j;
	int wide = w * zoom, high = h * zoom;

	sptr = destbuffer;

	for (j = 0; j <= h - 1; j++) {
		for (i = 0; i <= w - 1; i++) {
			//get colour
			pixel = pal[*srcbuffer];
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

	if (smooth == 1 && zoom >= 2) {
		int pstep;
		if (zoom == 2)
			pstep = 2;
		else
			pstep = 1;
		uint32_t *sptr1, *sptr2, *sptr3;
		for (int fy = 1; fy <= (high - 2); fy += pstep) {
			sptr1 = destbuffer + pitch * (fy - 1) + 1;  //(1,0)
			sptr2 = sptr1 + pitch; //(1,1)
			sptr3 = sptr2 + pitch; //(1,2)
			for (int fx = wide - 2; fx >= 1; fx--) {
				//p0=point(fx,fy)
				//p1=point(fx-1,fy-1)//nw
				//p2=point(fx+1,fy-1)//ne
				//p3=point(fx+1,fy+1)//se
				//p4=point(fx-1,fy+1)//sw
				//if p1 = p3 then p0 = p1
				//if p2 = p4 then p0 = p2
				if (sptr1[1] == sptr3[-1])
					sptr2[0] = sptr1[1];
				else
					if (sptr1[-1] == sptr3[1])
						sptr2[0] = sptr1[-1];
				
				//pset(fx,fy),p0
				sptr1 += 1;
				sptr2 += 1;
				sptr3 += 1;
			}
		}
	}
}

void smoothzoomblit_32_to_32bit(uint32_t *srcbuffer, uint32_t *destbuffer, int w, int h, int pitch, int zoom, int smooth) {
//srcbuffer: source w*h buffer, 32 bit
//destbuffer: destination scaled buffer (pitch*zoom)*(h*zoom), 32 bit (so pitch is in pixels, not bytes)
//supports any positive zoom

	uint32_t *sptr;
	uint32_t pixel;
	int i, j;
	int wide = w * zoom, high = h * zoom;

	sptr = (uint32_t*)destbuffer;

	for (j = 0; j <= h - 1; j++) {
		for (i = 0; i <= w - 1; i++) {
			pixel = *srcbuffer++;
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

	if (smooth == 1 && zoom >= 2) {
		int pstep;
		if (zoom == 2)
			pstep = 2;
		else
			pstep = 1;
		uint32_t *sptr1, *sptr2, *sptr3;
		for (int fy = 1; fy <= (high - 2); fy += pstep) {
			sptr1 = (uint32_t *)destbuffer + pitch * (fy - 1) + 1;  //(1,0)
			sptr2 = sptr1 + pitch; //(1,1)
			sptr3 = sptr2 + pitch; //(1,2)
			for (int fx = wide - 2; fx >= 1; fx--) {
				if (sptr1[1] == sptr3[-1])
					sptr2[0] = sptr1[1];
				else
					if (sptr1[-1] == sptr3[1])
						sptr2[0] = sptr1[-1];
				
				sptr1 += 1;
				sptr2 += 1;
				sptr3 += 1;
			}
		}
	}
}
