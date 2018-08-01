//OHRRPGCE COMMON - Generic Unix versions of OS-specific routines
//Please read LICENSE.txt for GNU GPL License details and disclaimer of liability

// defining _POSIX_SOURCE on FreeBSD prevents use of sys/ headers (an error about u_int)
//#if !defined(__APPLE__) && !defined(__FreeBSD__)
#ifdef __gnu_linux__
#define _POSIX_SOURCE  // for fdopen
//#define _BSD_SOURCE  // for usleep
//#define _DEFAULT_SOURCE  // replaces _BSD_SOURCE in recent glibc
#define _GNU_SOURCE  // needed for FNM_CASEFOLD, also includes _BSD_SOURCE
#endif
//fb_stub.h MUST be included first, to ensure fb_off_t is 64 bit
#include "fb/fb_stub.h"

#ifdef __ANDROID__
#include <android/log.h>
#endif

#ifdef HAVE_GLIBC
#include <malloc.h>
#endif

#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <errno.h>
#include <stdio.h>
#include <sys/types.h>
#include <dirent.h>
#include <fnmatch.h>

#include "misc.h"
#include "os.h"
#include "array.h"


void external_log(FBSTRING *str) {
#ifdef __ANDROID__
	__android_log_write(ANDROID_LOG_INFO, "OHRRPGCE", str->data);
#endif
}

static long long milliseconds() {
	struct timeval tv;
	gettimeofday(&tv, NULL);
	return (long long)tv.tv_sec * 1000 + tv.tv_usec / 1000;
}

static char _timestamp_buf[16];

// Returns a timestamp which is consistent between different programs running at once
static const char *timestamp() {
	long long now = milliseconds();
	snprintf(_timestamp_buf, 15, "%05lld.%03lld", (now / 1000) % 1000, now % 1000);
	return _timestamp_buf;
}

int memory_usage() {
#ifdef HAVE_GLIBC
	struct mallinfo info = mallinfo();
	// "This is the total size of memory occupied by chunks handed out by malloc."
	return info.uordblks;
#else
	return 0;
#endif
}

FBSTRING *memory_usage_string() {
#ifdef HAVE_GLIBC
	struct mallinfo info = mallinfo();
	FBSTRING ret;
	char buf[128];
	snprintf(buf, 128, "used=%d, free=%d, mmap allocs=%d, other allocs=%d", info.uordblks, info.fordblks, info.hblkhd, info.arena);
	init_fbstring(&ret, buf);
	return return_fbstring(&ret);
#else
	return empty_fbstring();
#endif
}

void setup_exception_handler() {
	// Unimplemented (but glibc makes this easy!)
}

void save_backtrace(boolint show_message) {
	// Unimplemented (but glibc makes this easy!)
}


//==========================================================================================
//                                       Filesystem
//==========================================================================================

// Returns 0 on success, or error code
int checked_stat(const char *filename, struct stat *finfo) {
	if (!filename) return EINVAL;
	// stat follows symlinks recursively
	if (stat(filename, finfo)) {
		// While scanning with readdir(), ENOENT (path not found) indicates a broken symlink,
		// nothing to write home about.
		// Given an arbitrary path, get either ENOENT (doesn't exist) or ENOTDIR (component
		// of the path is a file, not a dir).
		if (errno != ENOENT)
			debug(errInfo, "Could not stat(%s): %s", filename, strerror(errno));
		return errno;
	}
	return 0;
}

FileTypeEnum get_file_type (FBSTRING *fname) {
	if (!fname->data)
		return fileTypeDirectory;  // The current directory
	struct stat finfo;
	int err;
	if ((err = checked_stat(fname->data, &finfo))) {
		if (err == ENOENT || err == ENOTDIR)
			return fileTypeNonexistent;
		else
			return fileTypeError;
	}
	if (S_ISREG(finfo.st_mode))
		return fileTypeFile;
	if (S_ISDIR(finfo.st_mode))
		return fileTypeDirectory;
	return fileTypeOther;
}

// Returns a string vector
// whichtype: 0 for files, 1 for directory, other for either
array_t list_files_or_subdirs (FBSTRING *searchdir, FBSTRING *nmask, int showhidden, int whichtype) {
	// whichtype is 0 for files and 1 for directories
	DIR *dp;
	char *dirpath;
	if (searchdir->data)
		dirpath = searchdir->data;
	else
		dirpath = ".";
	dp = opendir(dirpath);
	int save_errno = errno;

	array_t ret = NULL;
	array_new(&ret, 0, 0, &type_table(string));
	if (dp == NULL) {
		debug(errError, "list_files/subdirs: unable to opendir(%s): %s", dirpath, strerror(save_errno));
	} else {
		int wcflags = FNM_PATHNAME | FNM_CASEFOLD;
		if (!showhidden) {
			//special handling of leading . if we don't want to see hidden files
			wcflags = wcflags | FNM_PERIOD;
		}
		struct dirent *ep;
		while ((ep = readdir(dp)) != NULL) {
			if (ep->d_type == DT_LNK) {
				// Is it a symlink to a dir or a file?
				char filename[512];
				if (snprintf(filename, 512, "%s/%s", dirpath, ep->d_name) > 511)
					continue;
				struct stat finfo;
				if (checked_stat(filename, &finfo))
					continue;  // error
				if (S_ISREG(finfo.st_mode)) {
					if (whichtype == 1) continue;
				} else if (S_ISDIR(finfo.st_mode)) {
					if (whichtype == 0) continue;
				} else
					// It's something else, like a FIFO or block device
					continue;
			} else if (ep->d_type == DT_REG) {
				if (whichtype == 1) continue;
			} else if (ep->d_type == DT_DIR) {
				if (whichtype == 0) continue;
			} else
				// It's something else, like a FIFO or block device
				continue;
			if (strcmp(ep->d_name, ".") == 0 || strcmp(ep->d_name, "..") == 0) continue;
			if (fnmatch(nmask->data, ep->d_name, wcflags) == 0) {
				//fnmatch returns 0 on a successful match because it hates me :(
				FBSTRING *newelem = array_expand(&ret, 1);
				init_fbstring(newelem, ep->d_name);
			}
		}
		(void) closedir (dp);
	}
	return array_temp(ret);
}

// Returns a string vector
array_t list_files (FBSTRING *searchdir, FBSTRING *nmask, int showhidden) {
	return list_files_or_subdirs(searchdir, nmask, showhidden, 0);
}

// Returns a string vector
array_t list_subdirs (FBSTRING *searchdir, FBSTRING *nmask, int showhidden) {
	return list_files_or_subdirs(searchdir, nmask, showhidden, 1);
}

int drivelist (void *drives_array) {
	// on Unix there is only one drive, the root /
	return 0;
}

FBSTRING *drivelabel (FBSTRING *drive) {
	return empty_fbstring();
}

int isremovable (FBSTRING *drive) {
	return 0;
}

int hasmedia (FBSTRING *drive) {
	return 0;
}

/*
boolint setwriteable (FBSTRING *fname) {
	// Under Unix, FB's fb_FileCopy and copy_file_replacing do not copy file permissions, so this isn't needed;
	// we assume that a reasonable umask which allows writable files is in effect.
	return -1;
}
*/

//(setq c-basic-offset 8)
//(setq indent-tabs-mode t)

#define COPYBUF_SIZE 16*1024
char copybuf[COPYBUF_SIZE];

//A file copy function which deals safely with the case where the file is open already. On Unix, unlink first.
//
//Based on FB's Unix fb_FileCopy function.
//It's not necessary for this to exist rather than just call remove and fb_FileCopy,
//but the benefit is fine-grained error reporting.
//Originally I was going to do file locking, but that's unneeded on Unix.
int copy_file_replacing(const char *source, const char *destination) {
	FILE *src = NULL, *dst = NULL;
	long len;
	size_t bytes_to_copy;
	
	if (remove(destination)) {
		if (errno != ENOENT) {
			debug(errError, "copy_file_replacing: remove(%s) error: %s", destination, strerror(errno));
			goto err;
		}
	}
	
	if (!(src = fopen(source, "rb"))) {
		debug(errError, "copy_file_replacing: could not fopen(%s, r): %s", source, strerror(errno));
		goto err;
	}

	fseek(src, 0, SEEK_END);
	len = ftell(src);
	fseek(src, 0, SEEK_SET);
	
	if (!(dst = fopen(destination, "wb"))) {
		debug(errError, "copy_file_replacing: could not fopen(%s, w): %s", destination, strerror(errno));
		goto err;
	}
	
	while (len > 0) {
		bytes_to_copy = (len >= COPYBUF_SIZE) ? COPYBUF_SIZE : len;
		if (fread(copybuf, 1, bytes_to_copy, src) != bytes_to_copy) {
			debug(errError, "copy_file_replacing: fread(%s) error: %s", source, strerror(errno));
			goto err;
		}
		if (fwrite(copybuf, 1, bytes_to_copy, dst) != bytes_to_copy) {
			debug(errError, "copy_file_replacing: fwrite(%s) error: %s", destination, strerror(errno));
			goto err;
		}
		len -= bytes_to_copy;
	}	
	fclose(src);
	fclose(dst);
	return -1;
 err:
	if (src) fclose(src);
	if (dst) fclose(dst);
	return 0;
}


//==========================================================================================
//                                    Advisory locking
//==========================================================================================


static int lock_file_base(FILE *fh, int timeout_ms, int flag, char *funcname) {
	int fd = fileno(fh);
	long long timeout = milliseconds() + timeout_ms;
	do {
		if (!flock(fd, flag | LOCK_NB))
			return 1;
		if (errno != EWOULDBLOCK && errno != EINTR) {
			debuginfo("%s: error: %s", funcname, strerror(errno));
			return 0;
		}
		usleep(10000);
	} while (milliseconds() < timeout);
	debuginfo("%s: timed out", funcname);
	return 0;
}

//For debugging
int test_locked(const char *filename, int writable) {
	int fd = open(filename, O_RDONLY);
	if (!flock(fd, LOCK_NB | (writable ? LOCK_EX : LOCK_SH))) {
		close(fd);
		return 0;
	}
	if (errno != EWOULDBLOCK && errno != EINTR) {
		debuginfo("test_locked: error: %s", strerror(errno));
		close(fd);
		return 0;
	}
	close(fd);
	return 1;
}

//Returns true on success
int lock_file_for_write(FILE *fh, int timeout_ms) {
	return lock_file_base(fh, timeout_ms, LOCK_EX, "lock_file_for_write");
}

//Returns true on success
int lock_file_for_read(FILE *fh, int timeout_ms) {
	return lock_file_base(fh, timeout_ms, LOCK_SH, "lock_file_for_read");
}

void unlock_file(FILE *fh) {
	flock(fileno(fh), LOCK_UN);
}


//==========================================================================================
//                               Inter-process communication
//==========================================================================================


//FBSTRING *channel_pick_name(const char *id, const char *tempdir, const char *rpg) {
//	  FBSTRING *ret;
//}

// Size of a PipeState readbuf in bytes
#define PIPEBUFSZ 2048

typedef struct BufferedMsg BufferedMsg;
struct BufferedMsg {
	BufferedMsg *next;
	char *msg;
	int msglen;
};

struct PipeState {
	char *basename;
	// Writing
	int writefd;
	BufferedMsg *writebuf_head;
	BufferedMsg *writebuf_tail;
	// Reading
	int readfd;
	char *readbuf; // PIPEBUFSZ bytes
	int readamnt;  // Next byte to be read from readbuf
	int usedamnt;  // Total amount of data in readbuf, including already read
};

static void channel_writebuf_push_msg(PipeState *channel, const char *buf, int buflen);
static void channel_writebuf_pop_msg(PipeState *channel);


static PipeState *channel_new(const char *basename) {
	PipeState *ret = malloc(sizeof(PipeState));
	ret->readfd = -1;
	ret->writefd = -1;
	ret->writebuf_head = ret->writebuf_tail = NULL;
	ret->readbuf = malloc(PIPEBUFSZ);
	ret->readamnt = ret->usedamnt = 0;
	ret->basename = malloc(strlen(basename) + 1);
	strcpy(ret->basename, basename);

	return ret;
}

static void channel_delete(PipeState *channel) {
	if (!channel) return;
	free(channel->readbuf);
	free(channel->basename);
	while (channel->writebuf_head)
		channel_writebuf_pop_msg(channel);
	free(channel);
}

void channel_close(PipeState **channelp) {
	PipeState *channel = *channelp;
	if (!channel) return;
	debuginfo("%s channel_close(%s) readfd=%d writefd=%d", timestamp(), channel->basename, channel->readfd, channel->writefd);
	if (channel->readfd != -1) close(channel->readfd);
	if (channel->writefd != -1) close(channel->writefd);
	channel_delete(channel);
	*channelp = NULL;
}

// Attempts to open a FIFO file for reading
// Returns true on success
static int fifo_open_read(char *name, int *out_fd) {
	debuginfo("%s fifo_open_read(%s)...", timestamp(), name);

	*out_fd = open(name, O_RDONLY | O_NONBLOCK);
	if (*out_fd == -1) {
		debug(errError, "%s fifo_open_read: open(%s) error: %s", timestamp(), name, strerror(errno));
		return 0;
	}
	debuginfo("%s ...success", timestamp());
	return 1;
}

// Attempts to open a FIFO file for writing
// Returns true on success
static int fifo_open_write(char *filename, int *out_fd, int timeout_ms) {
	debuginfo("%s fifo_open_write(%s)...", timestamp(), filename);
	*out_fd = -1;
	long long timeout = milliseconds() + timeout_ms;
	do {
		int fd = open(filename, O_WRONLY | O_NONBLOCK);
		if (fd != -1) {
			debuginfo("%s ...success", timestamp());
			*out_fd = fd;
			return 1;
		}
		if (errno != ENXIO && errno != EINTR) {	
			debug(errError, "%s fifo_open_write: open(%s) error: %s", timestamp(), filename, strerror(errno));
			return 0;
		}
		usleep(10000);
	} while (milliseconds() < timeout);
	debug(errError, "%s %dms timeout while waiting for writer to connect", timestamp(), timeout_ms);
	return 0;
}

// Creates a FIFO. To finish connecting, the client must connect and 
// channel_wait_for_client_connection must be called (in either order).
// Returns true on success
int channel_open_server(PipeState **result, FBSTRING *name) {
	*result = NULL;
	char *writefile = alloca(strlen(name->data) + 8 + 1);
	char *readfile = alloca(strlen(name->data) + 8 + 1);
	sprintf(writefile, "%s.2client", name->data);
	sprintf(readfile,  "%s.2server", name->data);

	debuginfo("%s channel_open_server(%s)...", timestamp(), name->data);

	remove(writefile);
	if (mkfifo(writefile, 0777) == -1) {
		debug(errError, "mkfifo(%s) failed: %s", writefile, strerror(errno));
		return 0;
	}

	remove(readfile);
	if (mkfifo(readfile, 0777) == -1) {
		debug(errError, "mkfifo(%s) failed: %s", readfile, strerror(errno));
		remove(writefile);
		return 0;
	}

	PipeState *ret = channel_new(name->data);
	if (fifo_open_read(readfile, &ret->readfd) == -1) {
		channel_close(&ret);
		remove(readfile);
		remove(writefile);
		return 0;
	}
	debuginfo("%s channel_open_server success", timestamp());

	// If a FIFO is opened for write in non-blocking mode and it hasn't been opened for read
	// yet, then the open fails. So we have to wait for the client to connect to the 'in'
	// FIFO first; see channel_wait_for_client_connection.

	// write() normally throws a SIGPIPE on broken pipe; ignore those and receive EPIPE instead
	signal(SIGPIPE, SIG_IGN);

	*result = ret;
	return 1;
}

// Returns true on success
int channel_open_client(PipeState **result, FBSTRING *name) {
	*result = NULL;
	char *writefile = alloca(strlen(name->data) + 8 + 1);
	char *readfile = alloca(strlen(name->data) + 8 + 1);
	sprintf(writefile, "%s.2server", name->data);  // Reversed from channel_open_server
	sprintf(readfile,  "%s.2client", name->data);

	*result = channel_new(name->data);

	if (!fifo_open_read(readfile, &(*result)->readfd)) {
		channel_close(result);
		return 0;
	}

	// At this point the server is meant to already have its read end open, so this
	// should succeed immediately.
	if (!fifo_open_write(writefile, &(*result)->writefd, 200)) {
		channel_close(result);
		return 0;
	}

	debuginfo("%s channel_open_client success", timestamp());

	// write() normally throws a SIGPIPE on broken pipe; ignore those and receive EPIPE instead
	signal(SIGPIPE, SIG_IGN);

	return 1;
}

// This is used by the server process only. Attempts to open the write side of a pair
// of pipes. Requires that the other process opens its read side first. Waits for that to happen.
// Returns true on success, false on error or timeout
int channel_wait_for_client_connection(PipeState **channelp, int timeout_ms) {
	PipeState *chan = *channelp;

	if (!chan) return 0;

	debuginfo("%s channel_wait_for_client_connection", timestamp());

	char *namebuf = alloca(strlen(chan->basename) + 8 + 1);
	sprintf(namebuf, "%s.2client", chan->basename);

	if (!fifo_open_write(namebuf, &chan->writefd, timeout_ms)) {
		channel_close(channelp);
		return 0;
	}
	return 1;
}

// Returns: 0 error, channel closed;  1 success;  2 no room in buffer
static int channel_write_internal(PipeState **channelp, const char *buf, int buflen) {
	int fd = (*channelp)->writefd;
	if (fd == -1) {
		debug(errBug, "channel_write: no file descriptor! (forgot channel_wait_for_client_connection?)");
		channel_close(channelp);
		return 0;
	}
	int written = 0;
	while (written < buflen) {
		int res = write(fd, buf + written, buflen - written);
		if (res == -1) {
			if (errno == EINTR)  // write interrupted, retry
				continue;
			if (errno == EAGAIN)
				return 2;
			if (errno == EPIPE)
				// Reading end closed
				debuginfo("%s channel_write: pipe closed.", timestamp());
			else
				debug(errError, "%s channel_write: error: %s", timestamp(), strerror(errno));
			channel_close(channelp);
			return 0;
		}
		written += res;
	}
	return 1;
}

static void channel_writebuf_push_msg(PipeState *channel, const char *buf, int buflen) {
	BufferedMsg *elmt = malloc(sizeof(BufferedMsg));
	elmt->msg = malloc(buflen);
	memcpy(elmt->msg, buf, buflen);
	elmt->msglen = buflen;
	elmt->next = NULL;

	if (channel->writebuf_tail) {
		channel->writebuf_tail->next = elmt;
		channel->writebuf_tail = elmt;
	} else {
		channel->writebuf_head = channel->writebuf_tail = elmt;
	}
}

static void channel_writebuf_pop_msg(PipeState *channel) {
	BufferedMsg *elmt = channel->writebuf_head;
	channel->writebuf_head = elmt->next;
	if (!channel->writebuf_head)
		channel->writebuf_tail = NULL;
	free(elmt->msg);
	free(elmt);
}

// Returns true on apparent success (which may mean the output is buffered
// instead of immediately written)
int channel_write(PipeState **channelp, const char *buf, int buflen) {
	int res;
	PipeState *channel = *channelp;
	if (!channel) return 0;

	// Flush delayed writes
	while (channel->writebuf_head) {
		res = channel_write_internal(channelp, channel->writebuf_head->msg, channel->writebuf_head->msglen);
		if (res == 0) {
			channel_close(channelp);
			return 0;
		}
		if (res == 1) {
			channel_writebuf_pop_msg(channel);
		}
		if (res == 2) {
			// Still not enough room
			channel_writebuf_push_msg(channel, buf, buflen);
			return 1;
		}
	}

	res = channel_write_internal(channelp, buf, buflen);
	if (res == 2) {
		if (!channel->writebuf_head) {
			// This is the first overflow
			debuginfo("%s channel_write warning: OS pipe buffer full, starting internal buffering", timestamp());
		}
		channel_writebuf_push_msg(channel, buf, buflen);
		return 1;
	} else {
		return res;
	}
}

// Returns true on apparent success (which may mean the output is buffered
// instead of immediately written)
// Automatically appends a newline
int channel_write_line(PipeState **channelp, FBSTRING *buf) {
	// Temporarily replace NULL byte with a newline
	buf->data[FB_STRSIZE(buf)] = '\n';
	int ret = channel_write(channelp, buf->data, FB_STRSIZE(buf) + 1);
	buf->data[FB_STRSIZE(buf)] = '\0';
	return ret;
}

// Returns true on reading a line
int channel_input_line(PipeState **channelp, FBSTRING *output) {
	if (!*channelp) return 0;

	int wait_times = 0;
	PipeState *chan = *channelp;
	char *nl = NULL;
	int outlen = 0;
	for (;;) {
		// First try to fulfill the request from buffer
		int copylen = chan->readamnt - chan->usedamnt;
		if (copylen > 0) {
			nl = memchr(chan->readbuf + chan->usedamnt, '\n', copylen);
			if (nl)
				copylen = nl - (chan->readbuf + chan->usedamnt);
			if (!fb_hStrRealloc(output, outlen + copylen, 1))  // set length, preserving existing
				return 0;
			memcpy(output->data + outlen, chan->readbuf + chan->usedamnt, copylen);
			outlen += copylen;
			chan->usedamnt += copylen;
			if (nl) {
				chan->usedamnt++;
				return 1;
			}
			// Otherwise, have used up all buffered data
		}

		// Read into buffer
		int res = read(chan->readfd, chan->readbuf, PIPEBUFSZ);
		if (res == 0) {
			// EOF: write end of pipe has closed
			debuginfo("%s channel_input_line: pipe closed", timestamp());
			channel_close(channelp);
			goto cutshort;
		}
		if (res == -1) {
			if (errno == EINTR)
				continue;
			if (errno == EAGAIN || errno == EWOULDBLOCK) {
				// No more data available yet 
				if (outlen) {
					// Strange -- expected newline! Lets wait for a bit
					if (!wait_times)
						debug(errError, "%s channel_read_input: unexpected blocking input", timestamp());
					if (wait_times++ > 20)
						goto cutshort;
					usleep(1000);
					continue;
				}
				// not sinister
			} else {
				debug(errError, "%s channel_input_line: pipe closed due to error %s\n", timestamp(), strerror(errno));
				channel_close(channelp);
			}
			goto cutshort;
		}
		chan->readamnt = res;
		chan->usedamnt = 0;
	}

 cutshort:
	if (!outlen)
		// We haven't called fb_hStrRealloc, so haven't overwritten the old contents of output
		fb_StrDelete(output);
	return (outlen > 0);
}
//fb_StrAssign(output, -1, buf, strlen(buf), 0);
//fb_hStrCopy(output->data + outlen, buf, 512);


//==========================================================================================
//                                       Processes
//==========================================================================================


// Interpret system() return value. Returns exit code or -1 on error.
int checked_system(const char* cmdline) {
	int waitstatus = system(cmdline);
	int ret = -1;
	if (waitstatus == -1)
		debug(errError, "system() couldn't fork");
	else if (WIFEXITED(waitstatus)) {
		ret = WEXITSTATUS(waitstatus);
		// Don't report; it's done by the caller anyway
		// if (ret)
		//	debug(errInfo, "system(%.30s...) exit status %d", cmdline, ret);
	}
	else if (WIFSIGNALED(waitstatus))
		debug(errError, "system(%.30s...) killed by signal %d", cmdline, WTERMSIG(waitstatus));
	else
		debug(errError, "system(%.30s...): unknown return %d", cmdline, waitstatus);
	return ret;
}

//Partial implementation. The returned process handle can't be used for much
//aside from passing to cleanup_process (which you should do).
//program is an unescaped path. Any paths in the arguments should be escaped
//graphical: if true, launch a graphical process (displays a console for commandline programs on
//           Windows, does nothing on Unix).
//waitable is true if you want cleanup_process to wait for the command to finish (ignored on
//           Windows: always waitable)
ProcessHandle open_process (FBSTRING *program, FBSTRING *args, boolint waitable, boolint graphical) {
#ifdef __ANDROID__
	// Early versions of the NDK don't have popen
	return 0;
#else
	char *program_escaped = escape_filenamec(program->data);
	char *argstr = args->data;
	if (!argstr)
		argstr = "";
	char *buf = malloc(strlen(program_escaped) + strlen(argstr) + 2);
	sprintf(buf, "%s %s", program_escaped, argstr);
	free(program_escaped);

	errno = 0;
	ProcessHandle ret = calloc(1, sizeof(struct ProcessInfo));
	if (!ret) return ret;
	ret->waitable = waitable;
	if (waitable) {
		// pclose waits for the program to finish, so don't use popen if don't have to.
		ret->file = popen(buf, "r");  //No intention to read or write
		int err = errno;  //errno from popen is not reliable
		if (!ret->file) {
			debug(errError, "%s popen(%s, %s) failed: %s", timestamp(), program->data, args->data, strerror(err));
		}
	} else {
		// Version for fire-and-forget running of programs
		ret->pid = fork();
		if (ret->pid == 0) {
			// Use system() just because it takes whole argument list as one string
			// (popen also uses system() internally).
			int status = system(buf);
			// Calling debug() inside a fork isn't a great idea; although debug()
			// opens and closes the log file on every call, the main program might have ended, etc.
			//int status = checked_system(buf);
			_exit(status);  // Don't flush buffers, etc, that would be bad
		}
	}
	free(buf);
	return ret;
#endif
}

// Run a program and pass back its output in the 'output' string.
// The process name and args should be escaped if needed (with escape_filename).
// Returns -1 if there's an error running or fetching the output. Otherwise returns the exit code of the program.
// Anything written to stderr by the program goes to our stderr.
// Not used: functionally identical to run_process_and_get_output in util.bas, with no
// apparent advantages to this version, which can't pipe multiple programs,
// and there is no Windows implementation of this function.
int run_process_and_get_output(FBSTRING *program, FBSTRING *args, FBSTRING *output) {
#ifdef __ANDROID__
	// Early versions of the NDK don't have popen
	return -1;
#else

	// Clear output
	if (!fb_StrAssign(output, -1, "", 0, 0))
		return -1;
	int outlen = 0;

	ProcessHandle proc = open_process(program, args, true, false);
	if (!proc || !proc->file)
		return -1;

	// Read everything out of the pipe
	int ret = 0;
	do {
		char buf[4096];
		int bytes = fread(buf, 1, 4096, proc->file);

		if (ferror(proc->file)) {
			debug(errError, "run_process_and_get_output(%s,%s): fread error: %s", program->data, args->data, strerror(errno));
			ret = -1;
			break;
		}
		
		if (!fb_hStrRealloc(output, outlen + bytes, 1)) {  // set length, preserving existing
			ret = -1;
			break;
		}
		memcpy(output->data + outlen, buf, bytes);
		outlen += bytes;
	} while (!feof(proc->file));

	int exitcode = pclose(proc->file);
	if (exitcode == -1) {
		debug(errError, "run_process_and_get_output(%s,%s): pclose error: %s", program->data, args->data, strerror(errno));
		ret = -1;
	}
	if (ret == 0) {  // no error encountered
		// I saw reports that the exit status may sometimes actually be from sh instead of the program.
		// bash may return 128+errno
		ret = WEXITSTATUS(exitcode);
	}
	free(proc);
	return ret;
#endif
}

//Run a (hidden) commandline program and open a pipe which writes to its stdin & reads from stdout
//Returns 0 on failure.
//If successful, you should call cleanup_process with the handle after you don't need it any longer.
ProcessHandle open_piped_process (FBSTRING *program, FBSTRING *args, IPCChannel *iopipe) {
	//Unimplemented
	return NULL;
}

//Returns 0 on failure.
//If successful, you should call cleanup_process with the handle after you don't need it any longer.
//This is currently designed for asynchronously running console applications.
//On Windows it displays a visible console window, on Unix it doesn't.
//Could be generalised in future as needed.
//TODO: spawn_console_process() in customsubs.rbas basically implements this, move here!
ProcessHandle open_console_process (FBSTRING *program, FBSTRING *args) {
	return open_process(program, args, true, true);
}

//If exitcode is nonnull and the process exited, the exit code will be placed in it
boolint process_running (ProcessHandle process, int *exitcode) {
	//Unimplemented and not yet used
	return false;
}

int wait_for_process (ProcessHandle *processp, int timeoutms) {
	//Unimplemented and not yet used
	cleanup_process(processp);
	return -1;
}

void kill_process (ProcessHandle process) {
	//Unimplemented and not yet used
}

//Cleans up resources associated with a ProcessHandle
void cleanup_process (ProcessHandle *processp) {
	// Early versions of the NDK don't have popen
#ifndef __ANDROID__
	if (processp && *processp) {
		if ((*processp)->file)
			pclose((*processp)->file);
		free(*processp);
		*processp = NULL;
	}
#endif
}

int get_process_id () {
	return getpid();
}

// A breakpoint
void interrupt_self () {
	raise(SIGINT);
}
