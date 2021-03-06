#include "sdl2fb.h"
#include "SDL.h"

int scantrans[322];
bool bInitialized;

void sdl2fb_init()
{
	scantrans[SDLK_UNKNOWN] = 0;
	scantrans[SDLK_BACKSPACE] = 14;
	scantrans[SDLK_TAB] = 15;
	scantrans[SDLK_CLEAR] = 0;
	scantrans[SDLK_RETURN] = 28;
	scantrans[SDLK_PAUSE] = 0;
	scantrans[SDLK_ESCAPE] = 1;
	scantrans[SDLK_SPACE] = 57;
	scantrans[SDLK_EXCLAIM] = 2;
	scantrans[SDLK_QUOTEDBL] = 40;
	scantrans[SDLK_HASH] = 4;
	scantrans[SDLK_DOLLAR] = 5;
	scantrans[SDLK_AMPERSAND] = 8;
	scantrans[SDLK_QUOTE] = 40;
	scantrans[SDLK_LEFTPAREN] = 10;
	scantrans[SDLK_RIGHTPAREN] = 11;
	scantrans[SDLK_ASTERISK] = 9;
	scantrans[SDLK_PLUS] = 13;
	scantrans[SDLK_COMMA] = 51;
	scantrans[SDLK_MINUS] = 12;
	scantrans[SDLK_PERIOD] = 52;
	scantrans[SDLK_SLASH] = 53;
	scantrans[SDLK_0] = 11;
	scantrans[SDLK_1] = 2;
	scantrans[SDLK_2] = 3;
	scantrans[SDLK_3] = 4;
	scantrans[SDLK_4] = 5;
	scantrans[SDLK_5] = 6;
	scantrans[SDLK_6] = 7;
	scantrans[SDLK_7] = 8;
	scantrans[SDLK_8] = 9;
	scantrans[SDLK_9] = 10;
	scantrans[SDLK_COLON] = 39;
	scantrans[SDLK_SEMICOLON] = 39;
	scantrans[SDLK_LESS] = 51;
	scantrans[SDLK_EQUALS] = 13;
	scantrans[SDLK_GREATER] = 52;
	scantrans[SDLK_QUESTION] = 53;
	scantrans[SDLK_AT] = 3;
	scantrans[SDLK_LEFTBRACKET] = 26;
	scantrans[SDLK_BACKSLASH] = 43;
	scantrans[SDLK_RIGHTBRACKET] = 27;
	scantrans[SDLK_CARET] = 7;
	scantrans[SDLK_UNDERSCORE] = 12;
	scantrans[SDLK_BACKQUOTE] = 41;
	scantrans[SDLK_a] = 30;
	scantrans[SDLK_b] = 48;
	scantrans[SDLK_c] = 46;
	scantrans[SDLK_d] = 32;
	scantrans[SDLK_e] = 18;
	scantrans[SDLK_f] = 33;
	scantrans[SDLK_g] = 34;
	scantrans[SDLK_h] = 35;
	scantrans[SDLK_i] = 23;
	scantrans[SDLK_j] = 36;
	scantrans[SDLK_k] = 37;
	scantrans[SDLK_l] = 38;
	scantrans[SDLK_m] = 50;
	scantrans[SDLK_n] = 49;
	scantrans[SDLK_o] = 24;
	scantrans[SDLK_p] = 25;
	scantrans[SDLK_q] = 16;
	scantrans[SDLK_r] = 19;
	scantrans[SDLK_s] = 31;
	scantrans[SDLK_t] = 20;
	scantrans[SDLK_u] = 22;
	scantrans[SDLK_v] = 47;
	scantrans[SDLK_w] = 17;
	scantrans[SDLK_x] = 45;
	scantrans[SDLK_y] = 21;
	scantrans[SDLK_z] = 44;
	scantrans[SDLK_DELETE] = 83;
	scantrans[SDLK_KP0] = 82;
	scantrans[SDLK_KP1] = 79;
	scantrans[SDLK_KP2] = 80;
	scantrans[SDLK_KP3] = 81;
	scantrans[SDLK_KP4] = 75;
	scantrans[SDLK_KP5] = 76;
	scantrans[SDLK_KP6] = 77;
	scantrans[SDLK_KP7] = 71;
	scantrans[SDLK_KP8] = 72;
	scantrans[SDLK_KP9] = 73;
	scantrans[SDLK_KP_PERIOD] = 83;
	scantrans[SDLK_KP_DIVIDE] = 83;
	scantrans[SDLK_KP_MULTIPLY] = 55;
	scantrans[SDLK_KP_MINUS] = 74;
	scantrans[SDLK_KP_PLUS] = 78;
	scantrans[SDLK_KP_ENTER] = 28;
	scantrans[SDLK_KP_EQUALS] = 13;
	scantrans[SDLK_UP] = 72;
	scantrans[SDLK_DOWN] = 80;
	scantrans[SDLK_RIGHT] = 77;
	scantrans[SDLK_LEFT] = 75;
	scantrans[SDLK_INSERT] = 82;
	scantrans[SDLK_HOME] = 71;
	scantrans[SDLK_END] = 79;
	scantrans[SDLK_PAGEUP] = 73;
	scantrans[SDLK_PAGEDOWN] = 81;
	scantrans[SDLK_F1] = 59;
	scantrans[SDLK_F2] = 60;
	scantrans[SDLK_F3] = 61;
	scantrans[SDLK_F4] = 62;
	scantrans[SDLK_F5] = 63;
	scantrans[SDLK_F6] = 64;
	scantrans[SDLK_F7] = 65;
	scantrans[SDLK_F8] = 66;
	scantrans[SDLK_F9] = 67;
	scantrans[SDLK_F10] = 68;
	scantrans[SDLK_F11] = 87;
	scantrans[SDLK_F12] = 89;
	scantrans[SDLK_F13] = 0;
	scantrans[SDLK_F14] = 0;
	scantrans[SDLK_F15] = 0;
	scantrans[SDLK_NUMLOCK] = 69;
	scantrans[SDLK_CAPSLOCK] = 58;
	scantrans[SDLK_SCROLLOCK] = 70;
	scantrans[SDLK_RSHIFT] = 54;
	scantrans[SDLK_LSHIFT] = 42;
	scantrans[SDLK_RCTRL] = 29;
	scantrans[SDLK_LCTRL] = 29;
	scantrans[SDLK_RALT] = 56;
	scantrans[SDLK_LALT] = 56;
	scantrans[SDLK_RMETA] = 0;
	scantrans[SDLK_LMETA] = 0;
	scantrans[SDLK_LSUPER] = 0;
	scantrans[SDLK_RSUPER] = 0;
	scantrans[SDLK_MODE] = 0;
	scantrans[SDLK_COMPOSE] = 0;
	scantrans[SDLK_HELP] = 0;
	scantrans[SDLK_PRINT] = 0;
	scantrans[SDLK_SYSREQ] = 0;
	scantrans[SDLK_BREAK] = 0;
	scantrans[SDLK_MENU] = 0;
	scantrans[SDLK_POWER] = 0;
	scantrans[SDLK_EURO] = 0;
	scantrans[SDLK_UNDO] = 0;
	bInitialized = true;
}

int sdl2fb(int sdlCode)
{
	if(!bInitialized)
		sdl2fb_init();
	return scantrans[sdlCode];
}
