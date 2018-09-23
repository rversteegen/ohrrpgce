extern "C" {

// gif.h must be included in exactly one .cpp file - it's not really a header.
#include "gif.h"

// This is an extension to the gif.h library.

#define boolint int

// Convert from 32-bit 'image' to 8-bit 'result' using Floyd-Steinberg dithering or nearest-neighbour.
// firstindex:
//     The lowest allowed palette index in the output. Eg. a value of 0
//     allows the whole palette, a value of 1 excludes palette[0].
//     Values > 1 unsupported if computePalette is true.
// computePalette:
//     If true, 'palette' is overwritten with a near-optimal palette. Otherwise,
//     it is the palette to quantize to.
// palette: a length 1<<bitDepth array, used either for input or output
void GifQuantizeImage(const GifRGBA* image, uint32_t width, uint32_t height, uint8_t* result, boolint dither, boolint computePalette, GifRGBA* palette, int bitDepth, int firstindex) {

    uint32_t numPixels = width*height;
    GifKDTree tree;
    GifRGBA* indexedPalette = NULL;

    if (!computePalette) {
        indexedPalette = (GifRGBA*)GIF_MALLOC((1 << bitDepth) * sizeof(GifRGBA));

        memcpy(indexedPalette, palette, (1 << bitDepth) * sizeof(GifRGBA));
        for (int idx = 0; idx < 1 << bitDepth; idx++) {
            indexedPalette[idx].a = idx;
        }

        // Remove disallowed colors
        for (int idx = 0; idx < firstindex; idx++) {
            indexedPalette[idx] = indexedPalette[firstindex];
        }

        // Create the KDTree for the palette by treating palette as an image
        GifMakePalette(NULL, indexedPalette, 1 << bitDepth, 1, bitDepth, true, &tree);

        GIF_FREE(indexedPalette);
    } else {
        // Compute a palette.
        // Only firstindex 0 or 1 is supported
        bool includeTransparent = (firstindex == 0);
        GifMakePalette(NULL, image, width, height, bitDepth, includeTransparent, &tree);
    }

    GifRGBA* resultRGBA = (GifRGBA*)GIF_MALLOC(numPixels * sizeof(GifRGBA));
    if (dither)
        GifDitherImage(NULL, image, resultRGBA, width, height, &tree);
    else
        GifThresholdImage(NULL, image, resultRGBA, width, height, &tree);

    if (!computePalette) {
        // Extra remapping from the GifKDTree palette index to the 'palette' index
        for (uint32_t ii = 0; ii < numPixels; ++ii) {
            result[ii] = tree.pal.colors[resultRGBA[ii].a].a;
        }
    } else {
        for (uint32_t ii = 0; ii < numPixels; ++ii) {
            result[ii] = resultRGBA[ii].a;
        }

        // Set palette
        for (int idx = 0; idx < 1 << bitDepth; idx++) {
            palette[idx] = tree.pal.colors[idx];
            palette[idx].a = 255;  // We haven't settled on how to treat alpha in a palette
        }
    }

    GIF_FREE(resultRGBA);
}


}
