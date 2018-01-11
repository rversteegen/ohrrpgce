#pragma once

#include once "crt/stdio.bi"

extern "C"

#define JO_INCLUDE_MPEG_H
declare sub jo_write_mpeg(byval fp as FILE ptr, byval rgbx as const ubyte ptr, byval width as long, byval height as long, byval fps as long)

end extern
