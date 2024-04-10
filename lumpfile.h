/* OHRRPGCE - Lumped file format routines
 * (C) Copyright 1997-2020 James Paige, Ralph Versteegen, and the OHRRPGCE Developers
 * Dual licensed under the GNU GPL v2+ and MIT Licenses. Read LICENSE.txt for terms and disclaimer of liability.
 *
 * NOTE: many of the declarations in lumpfile.bi are in filelayer.hpp on the C side
 *       In fact most of these declarations aren't even used.
 */

#ifndef LUMPFILE_H
#define LUMPFILE_H


#ifdef __cplusplus
extern "C" {
#endif

typedef struct Lump Lump;
typedef struct FileWrapper FileWrapper;

FileWrapper* FileWrapper_open(Lump* lump);
void FileWrapper_close(FileWrapper*);
int FileWrapper_seek(FileWrapper*, int offset, int whence);
int FileWrapper_read(FileWrapper*, void* buffer, int size, int maxnum);

void log_openfile(const char *filename);
boolint read_recent_files_list(int idx, const char **filename, double *opentime);

#ifdef PROFILE_IO

// TODO: currently we only tally fseek/fread/fwrite calls for hooked files
// (lumps) and VFiles (Reload.LoadDocument), but ideally want to tally everything other
// than in-memory VFiles, including IO in the music backend, gif.h, lodepng, etc.

struct IOCounter {
	int frame;  // The count this frame
	int total;  // Accumulated count
};

// Reopens are OPENFILEs after a lazyclose
extern struct IOCounter count_fopens, count_reopens, count_fseeks, count_freads, count_fread_bytes, count_fwrites, count_fwrite_bytes;

#define PROFILE_FOPEN() count_fopens.frame += 1
#define PROFILE_REOPEN() count_reopens.frame += 1
#define PROFILE_FREAD(bytes) do { count_freads.frame += 1; count_fread_bytes.frame += (bytes); } while(0)
#define PROFILE_FWRITE(bytes) do { count_fwrites.frame += 1; count_fwrite_bytes.frame += (bytes); } while(0)
#define PROFILE_FSEEK() count_fseeks.frame += 1

#else

#define PROFILE_FOPEN()
#define PROFILE_REOPEN()
#define PROFILE_FREAD(bytes)
#define PROFILE_FWRITE(bytes)
#define PROFILE_FSEEK()

#endif

#ifdef __cplusplus
}
#endif

#endif
