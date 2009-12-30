#include "gfx_directx_TESTAPPconst.h"
#if !TESTAPP
#define ISOLATION_AWARE_ENABLED  1
#endif

#include "gfx_directx.new.h"
#include "gfx_directx_cls_window.h"
#include "gfx_directx_cls.h"
#include "gfx_directx_cls_dinput.h"
#include "gfx_directx_cls_osmouse.h"
using namespace gfx;

#include "di2fb_scancodes.h"
#include "resource.h"

#define DX_BUILD_DIRECTX_DYNAMIC TRUE //can only be TRUE or FALSE, or 1 or 0 respectively
#define DX_BUILD_MSVC_DYNAMIC FALSE //can only be TRUE or FALSE, or 1 or 0 respectively
#define DX_VERSION_MAJOR 0x2
#define DX_VERSION_MINOR 0x0
#define DX_VERSION_BUILD ((DX_BUILD_MSVC_DYNAMIC << 1) + DX_BUILD_DIRECTX_DYNAMIC)
#define DX_BACKEND_VERSION ((DX_VERSION_MAJOR << 16) + (DX_VERSION_MINOR << 8) + DX_VERSION_BUILD)

//use common controls available on different windows OS'
#if defined _M_IX86
#pragma comment(linker,"/manifestdependency:\"type='win32' name='Microsoft.Windows.Common-Controls' version='6.0.0.0' processorArchitecture='x86' publicKeyToken='6595b64144ccf1df' language='*'\"")
#elif defined _M_IA64
#pragma comment(linker,"/manifestdependency:\"type='win32' name='Microsoft.Windows.Common-Controls' version='6.0.0.0' processorArchitecture='ia64' publicKeyToken='6595b64144ccf1df' language='*'\"")
#elif defined _M_X64
#pragma comment(linker,"/manifestdependency:\"type='win32' name='Microsoft.Windows.Common-Controls' version='6.0.0.0' processorArchitecture='amd64' publicKeyToken='6595b64144ccf1df' language='*'\"")
#else
#pragma comment(linker,"/manifestdependency:\"type='win32' name='Microsoft.Windows.Common-Controls' version='6.0.0.0' processorArchitecture='*' publicKeyToken='6595b64144ccf1df' language='*'\"")
#endif

//resource loading from module
#if TESTAPP
#define MODULENAME NULL
#else
#define MODULENAME TEXT("gfx_directx.dll")
#endif //TESTAPP

Window g_Window;
HWND g_hWndDlg;
DirectX g_DirectX;
DirectInput g_DirectInput;
OSMouse g_OSMouse;

struct gfx_BackendState
{
	tstring szWindowTitle;
	tstring szWindowIcon;
	void (__cdecl *PostTerminateSignal)(void);
	void (__cdecl *OnCriticalError)(const char* szError);
	void (__cdecl *SendDebugString)(const char* szMessage);
	bool bClosing; //flagged when shutting down
	bool bBlockOhrMouseInput; //toggles ohr mouse control
} g_State;

LRESULT CALLBACK OHRWndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
BOOL CALLBACK OHROptionsDlgModeless(HWND hWndDlg, UINT msg, WPARAM wParam, LPARAM lParam);
SIZE CalculateNativeResolutionMultiple(UINT width, UINT height, UINT targetWidth = 320, UINT targetHeight = 200);
bool IsNativeResolutionMultiple(UINT width, UINT height, UINT targetWidth = 320, UINT targetHeight = 200);

int gfx_Initialize(const GFX_INIT *pCreationData)
{
	if(pCreationData == NULL)
		return FALSE;

	TCHAR buffer[256] = TEXT("");
	g_State.szWindowIcon = CharToTchar(buffer, 256, pCreationData->szWindowIcon, 0);
	g_State.PostTerminateSignal = pCreationData->PostTerminateSignal;
	g_State.OnCriticalError = pCreationData->OnCriticalError;
	g_State.SendDebugString = pCreationData->SendDebugString;

	if(g_State.PostTerminateSignal == NULL || g_State.OnCriticalError == NULL || g_State.SendDebugString == NULL)
		return FALSE;

	g_State.SendDebugString("gfx_directx: Initializing...");

	if(S_OK != g_Window.Initialize(::GetModuleHandle(MODULENAME), 
								   (pCreationData->szWindowIcon ? g_State.szWindowIcon.c_str() : NULL), 
								   (WNDPROC)OHRWndProc))
	{
		g_State.SendDebugString("gfx_directx: Failed at window initialization! Fallback...");
		return FALSE;
	}

	g_State.SendDebugString("gfx_directx: Window Intialized!");

	if(DX_OK != g_DirectX.Initialize(&g_Window, MODULENAME))
	{
		g_Window.Shutdown();
		gfx_PumpMessages();
		g_State.SendDebugString("gfx_directx: Failed at d3d initialization! Fallback...");
		return FALSE;
	}

	g_State.SendDebugString("gfx_directx: D3D Initialized!");

	if(DI_OK != g_DirectInput.Initialize(&g_Window))
	{
		g_DirectX.Shutdown();
		g_Window.Shutdown();
		gfx_PumpMessages();
		g_State.SendDebugString("gfx_directx: Failed at dinput initialization! Fallback...");
		return FALSE;
	}

	g_State.SendDebugString("gfx_directx: DInput Initialized!");

	if(S_OK != g_OSMouse.Initialize(g_Window.GetWindowHandle()))
	{
		g_DirectInput.Shutdown();
		g_DirectX.Shutdown();
		g_Window.Shutdown();
		gfx_PumpMessages();
		g_State.SendDebugString("gfx_directx: Failed at os mouse initialization! Fallback...");
		return FALSE;
	}

	g_State.SendDebugString("gfx_directx: OSMouse Initialized!");
	gfx_SetWindowTitle(pCreationData->szInitWindowTitle);

	g_Window.SetClientSize(640, 400);
	g_Window.CenterWindow();

	g_State.SendDebugString("gfx_directx: Initialization success!");
	return TRUE;
}

void gfx_Close()
{
	g_State.SendDebugString("gfx_directx: Closing backend...");
	g_DirectInput.Shutdown();
	g_DirectX.Shutdown();
	g_Window.Shutdown();
	gfx_PumpMessages();
	g_State.SendDebugString("gfx_directx: Close complete!");
}

void gfx_SetPreferences(const GFX_PREFERENCES *pPreferences)
{
	if(pPreferences == NULL)
		return;
	g_DirectX.SetView(FALSE == pPreferences->bFullscreen);
	g_DirectX.SetAspectRatioPreservation(FALSE != pPreferences->bAspectRatioPreservation);
	g_DirectX.SetSmooth(FALSE != pPreferences->bSmooth);
	switch(pPreferences->nScreenshotFormat)
	{
	case 0: //ohr bmp
		g_DirectX.SetImageFileFormat(D3DXIFF_FORCE_DWORD);
		break;
	case 1: //jpg
		g_DirectX.SetImageFileFormat(D3DXIFF_JPG);
		break;
	case 2: //bmp
		g_DirectX.SetImageFileFormat(D3DXIFF_BMP);
		break;
	case 3: //png
		g_DirectX.SetImageFileFormat(D3DXIFF_PNG);
		break;
	case 4: //dds
		g_DirectX.SetImageFileFormat(D3DXIFF_DDS);
		break;
	default: //default to ohr bmp
		g_DirectX.SetImageFileFormat(D3DXIFF_FORCE_DWORD);
	}

	if(!g_DirectX.IsViewFullscreen())
	{
		g_Window.SetClientSize(pPreferences->width, pPreferences->height);
		g_Window.SetWindowPosition(pPreferences->left, pPreferences->top);
	}
}

void gfx_GetPreferences(GFX_PREFERENCES *pPreferences)
{
	if(pPreferences == NULL)
		return;
	pPreferences->bAspectRatioPreservation = g_DirectX.IsAspectRatioPreserved() ? TRUE : FALSE;
	pPreferences->bFullscreen = g_DirectX.IsViewFullscreen() ? TRUE : FALSE;
	pPreferences->bSmooth = g_DirectX.IsSmooth() ? TRUE : FALSE;
	pPreferences->bVsync = g_DirectX.IsVsyncEnabled() ? TRUE : FALSE;
	pPreferences->width = g_Window.GetClientSize().cx;
	pPreferences->height = g_Window.GetClientSize().cy;
	pPreferences->left = g_Window.GetWindowSize().left;
	pPreferences->top = g_Window.GetWindowSize().top;
	switch(g_DirectX.GetImageFileFormat())
	{
	case D3DXIFF_JPG:
		pPreferences->nScreenshotFormat = 1;
		break;
	case D3DXIFF_BMP:
		pPreferences->nScreenshotFormat = 2;
		break;
	case D3DXIFF_PNG:
		pPreferences->nScreenshotFormat = 3;
		break;
	case D3DXIFF_DDS:
		pPreferences->nScreenshotFormat = 4;
		break;
	default:
		pPreferences->nScreenshotFormat = 0;
	}
}

int gfx_GetVersion()
{
	return DX_VERSION_MAJOR;
}

void gfx_PumpMessages()
{
	static MSG msg;
	while(::PeekMessage(&msg, 0, 0, 0, PM_REMOVE))
	{
		if(!::IsWindow(g_hWndDlg) || !::IsDialogMessage(g_hWndDlg, &msg))
		{
			::TranslateMessage(&msg);
			::DispatchMessage(&msg);
		}
	}
	g_DirectInput.PollKeyboard();
	if(!g_State.bBlockOhrMouseInput)
		g_DirectInput.PollKeyboard();
}

void gfx_Present(unsigned char *pSurface, int nWidth, int nHeight, unsigned int *pPalette)
{
	if(pPalette)
		g_DirectX.SetPalette(&Palette<UINT>(pPalette, 256));
	g_DirectX.ShowPage(pSurface, nWidth, nHeight);
}

int gfx_ScreenShot(const char *szFileName)
{
	if(!g_DirectX.IsScreenShotsActive())
		return FALSE;
	if(szFileName == NULL)
		return FALSE;
	TCHAR buffer[256] = TEXT("");
	if(DX_OK != g_DirectX.ScreenShot(CharToTchar(buffer, 256, szFileName, 0)))
		return FALSE;
	return TRUE;
}

void gfx_SetWindowTitle(const char *szTitle)
{
	if(szTitle == NULL)
		g_State.szWindowTitle = TEXT("");
	else
	{
		TCHAR buffer[256] = TEXT("");
		g_State.szWindowTitle = CharToTchar(buffer, 256, szTitle, 0);
	}
	tstring szTemp = g_State.szWindowTitle;
	if(!g_State.bBlockOhrMouseInput && g_OSMouse.IsOHRMouseActive())
		szTemp += TEXT(" Press 'Scroll Lock' to free mouse");
	else if(g_State.bBlockOhrMouseInput && g_OSMouse.IsOHRMouseActive())
		szTemp += TEXT(" Press 'Scroll Lock' to lock mouse");
	g_Window.SetWindowTitle(szTemp.c_str());
}

const char* gfx_GetWindowTitle()
{
	char buffer[256] = "";
	return TcharToChar(buffer, 256, g_State.szWindowTitle.c_str(), 0);
}

int gfx_AcquireKeyboard(int bEnable)
{
	return TRUE; //acquired by default
}

int gfx_AcquireMouse(int bEnable)
{
	g_OSMouse.OHRMouseActive(FALSE != bEnable);
	char buffer[256] = "";
	gfx_SetWindowTitle(TcharToChar(buffer, 256, g_State.szWindowTitle.c_str(), 0));
	return TRUE;
}

int gfx_AcquireJoystick(int bEnable, int nDevice)
{
	return FALSE; //no joystick support yet
}

int gfx_GetKeyboard(int *pKeyboard)
{
	if(pKeyboard == NULL)
		return FALSE;
	BYTE *pKeys = g_DirectInput.GetKeyboardState();
	if(pKeys == NULL)
		return FALSE;
	for(UINT  i = 0; i < 256; i++)
		if(pKeys[i] & 0x80)
			pKeyboard[di2fb(i)] |= 8; //di2fb() converts di scancode to fb
	return TRUE;
}

int gfx_GetMouseMovement(int& dx, int& dy, int& dWheel, int& buttons)
{
	dx = g_DirectInput.GetMouseXChange();
	dy = g_DirectInput.GetMouseYChange();
	dWheel = g_DirectInput.GetMouseWheelChange();
	buttons = 0;
	buttons |= (g_DirectInput.IsMouseLButtonDown() ? 0x1 : 0);
	buttons |= (g_DirectInput.IsMouseRButtonDown() ? 0x2 : 0);
	buttons |= (g_DirectInput.IsMouseMButtonDown() ? 0x4 : 0);
	return TRUE;
}

int gfx_GetMousePosition(int& x, int& y, int& wheel, int& buttons)
{
	x = g_DirectInput.GetMouseX();
	y = g_DirectInput.GetMouseY();
	wheel = g_DirectInput.GetMouseWheel();
	buttons = 0;
	buttons |= (g_DirectInput.IsMouseLButtonDown() ? 0x1 : 0);
	buttons |= (g_DirectInput.IsMouseRButtonDown() ? 0x2 : 0);
	buttons |= (g_DirectInput.IsMouseMButtonDown() ? 0x4 : 0);
	return TRUE;
}

int gfx_SetMousePosition(int x, int y)
{
	g_DirectInput.SetMouseX(x);
	g_DirectInput.SetMouseY(y);
	return TRUE;
}

int gfx_GetJoystickMovement(int nDevice, int& dx, int& dy, int& buttons)
{
	return FALSE; //no support
}

int gfx_GetJoystickPosition(int nDevice, int& x, int& y, int& buttons)
{
	return FALSE; //no support
}

int gfx_SetJoystickPosition(int nDevice, int x, int y)
{
	return FALSE; //no support
}

SIZE CalculateNativeResolutionMultiple(UINT width, UINT height, UINT targetWidth, UINT targetHeight)
{
	SIZE ret = {targetWidth, targetHeight};
	UINT targetArea = targetWidth * targetHeight;
	UINT area = width * height;
	UINT i = 1;
	while(area > targetArea * i * i)
		i++;
	if(i != 1)
	{
		float midArea = targetArea * (i-.5f) * (i-.5f);
		if(area < (UINT)midArea)
		{
			ret.cx = targetWidth * (i-1);
			ret.cy = targetHeight * (i-1);
		}
		else
		{
			ret.cx = targetWidth * i;
			ret.cy = targetHeight * i;
		}
	}
	return ret;
}

bool IsNativeResolutionMultiple(UINT width, UINT height, UINT targetWidth, UINT targetHeight)
{
	if(width * height < targetWidth * targetHeight)
		return false;
	UINT i = 1;
	while(width > targetWidth * i)
		i++;
	if(width != targetWidth * i)
		return false;
	if(height != targetHeight * i)
		return false;
	return true;
}

LRESULT CALLBACK OHRWndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	const UINT_PTR ID_MENU_OPTIONS = 101;
	switch(msg)
	{
	case WM_KEYDOWN:
		{
			switch(wParam)
			{
			case VK_SCROLL:
				{
					if(!(lParam & 0x40000000)) //key was not pressed before
					{
						g_State.bBlockOhrMouseInput = !g_State.bBlockOhrMouseInput;
						if(g_State.bBlockOhrMouseInput)
							g_OSMouse.Push_State();
						else
							g_OSMouse.Pop_State();
						char buffer[256] = "";
						gfx_SetWindowTitle(TcharToChar(buffer, 256, g_State.szWindowTitle.c_str(), 0));
					}
				} break;
			default:
				return ::DefWindowProc(hWnd, msg, wParam, lParam);
			}
		} break;
	case WM_SYSCOMMAND:
		{
			switch(wParam)
			{
			case ID_MENU_OPTIONS:
				{//run dialog
					if(::IsWindow(g_hWndDlg))
						return 0;
					g_hWndDlg = ::CreateDialog(::GetModuleHandle(MODULENAME), TEXT("DialogOptions"), hWnd, (DLGPROC)OHROptionsDlgModeless);
					::ShowWindow(g_hWndDlg, SW_SHOWNORMAL);
					::UpdateWindow(g_hWndDlg);
				} break;
			case SC_KEYMENU:
				{
				} break;
			default:
				{
					return ::DefWindowProc(hWnd, msg, wParam, lParam);
				}
			}
		} break;
	case WM_SYSCHAR:
		{
			switch(wParam)
			{
			case VK_RETURN: //alt-enter
				{
					if(!(lParam & 0x40000000)) //key was not pressed before
						g_DirectX.SetView(g_DirectX.IsViewFullscreen());
				} break;
			default:
				return ::DefWindowProc(hWnd, msg, wParam, lParam);
			}
		} break;
	case WM_ACTIVATE:
		{
			if(LOWORD(wParam) == WA_INACTIVE)
				g_OSMouse.Push_State();
			else
				g_OSMouse.Pop_State();
			return ::DefWindowProc(hWnd, msg, wParam, lParam);
		} break;
	case WM_SIZE:
		{
			::DefWindowProc(hWnd, msg, wParam, lParam);
			if(wParam == SIZE_MINIMIZED)
			{
				g_OSMouse.Push_State();
			}
			else
			{
				g_DirectX.SetResolution(LOWORD(lParam), HIWORD(lParam));
				g_OSMouse.Pop_State();
			}
		} break;
	case WM_SIZING:
		{
			if(!g_DirectX.IsViewFullscreen())
			{
				static RECT rWindowTest = {0,0,400,400};
				static BOOL bRunOnce = FALSE;
				static SIZE sPadding = {0,0};
				if(bRunOnce == FALSE)
				{
					bRunOnce = TRUE;
					::AdjustWindowRectEx(&rWindowTest, WS_OVERLAPPEDWINDOW, FALSE, 0);
					sPadding.cx = rWindowTest.right - rWindowTest.left - 400;
					sPadding.cy = rWindowTest.bottom - rWindowTest.top - 400;
				}
				switch(wParam)
				{
				case WMSZ_BOTTOMLEFT:
					{
						RECT r = *(RECT*)lParam;
						if(!IsNativeResolutionMultiple(r.right - r.left - sPadding.cx, r.bottom - r.top - sPadding.cy))
						{
							SIZE resolution = CalculateNativeResolutionMultiple(r.right - r.left - sPadding.cx, r.bottom - r.top - sPadding.cy);
							r.bottom = r.top + (resolution.cy + sPadding.cy);
							r.left = r.right - (resolution.cx + sPadding.cx);
							*(RECT*)lParam = r;
						}
					} break;
				case WMSZ_BOTTOMRIGHT:
					{
						RECT r = *(RECT*)lParam;
						if(!IsNativeResolutionMultiple(r.right - r.left - sPadding.cx, r.bottom - r.top - sPadding.cy))
						{
							SIZE resolution = CalculateNativeResolutionMultiple(r.right - r.left - sPadding.cx, r.bottom - r.top - sPadding.cy);
							r.bottom = r.top + (resolution.cy + sPadding.cy);
							r.right = r.left + (resolution.cx + sPadding.cx);
							*(RECT*)lParam = r;
						}
					} break;
				case WMSZ_TOPLEFT:
					{
						RECT r = *(RECT*)lParam;
						if(!IsNativeResolutionMultiple(r.right - r.left - sPadding.cx, r.bottom - r.top - sPadding.cy))
						{
							SIZE resolution = CalculateNativeResolutionMultiple(r.right - r.left - sPadding.cx, r.bottom - r.top - sPadding.cy);
							r.top = r.bottom - (resolution.cy + sPadding.cy);
							r.left = r.right - (resolution.cx + sPadding.cx);
							*(RECT*)lParam = r;
						}
					} break;
				case WMSZ_TOPRIGHT:
					{
						RECT r = *(RECT*)lParam;
						if(!IsNativeResolutionMultiple(r.right - r.left - sPadding.cx, r.bottom - r.top - sPadding.cy))
						{
							SIZE resolution = CalculateNativeResolutionMultiple(r.right - r.left - sPadding.cx, r.bottom - r.top - sPadding.cy);
							r.top = r.bottom - (resolution.cy + sPadding.cy);
							r.right = r.left + (resolution.cx + sPadding.cx);
							*(RECT*)lParam = r;
						}
					} break;
				}
			}
			::DefWindowProc(hWnd, msg, wParam, lParam);
		} break;
	case WM_CLOSE:
		{
			if(g_State.bClosing)
				return ::DefWindowProc(hWnd, msg, wParam, lParam);
			g_OSMouse.Push_State();
			g_State.PostTerminateSignal();
			g_OSMouse.Pop_State();
		} break;
	case WM_CREATE:
		{
			HMENU hSysMenu = ::GetSystemMenu(hWnd, false);
			::InsertMenu(hSysMenu, 0, MF_BYPOSITION | MF_STRING, ID_MENU_OPTIONS, TEXT("Options"));
			::InsertMenu(hSysMenu, 1, MF_BYPOSITION | MF_SEPARATOR, 0, 0);
		}//intentionally fall-through
	default:
		return ::DefWindowProc(hWnd, msg, wParam, lParam);
	}
	return 0;
}

BOOL CALLBACK OHROptionsDlgModeless(HWND hWndDlg, UINT msg, WPARAM wParam, LPARAM lParam)
{
	switch(msg)
	{
	case WM_COMMAND:
		{
			switch(LOWORD(wParam))
			{//control id
			case IDC_OPTIONS_SetDefaults:
				{//sets defaults
					::CheckDlgButton(hWndDlg, IDC_OPTIONS_EnableVsync, BST_CHECKED);
					::CheckDlgButton(hWndDlg, IDC_OPTIONS_EnableSmooth, BST_UNCHECKED);
					::CheckDlgButton(hWndDlg, IDC_OPTIONS_EnablePreserveAspectRatio, BST_CHECKED);
					if(g_DirectX.IsScreenShotsActive())
					{
						::CheckDlgButton(hWndDlg, IDC_OPTIONS_ScrnShotFormats_JPG, BST_CHECKED);
						::CheckDlgButton(hWndDlg, IDC_OPTIONS_ScrnShotFormats_BMP, BST_UNCHECKED);
						::CheckDlgButton(hWndDlg, IDC_OPTIONS_ScrnShotFormats_PNG, BST_UNCHECKED);
						::CheckDlgButton(hWndDlg, IDC_OPTIONS_ScrnShotFormats_DDS, BST_UNCHECKED);
						::CheckDlgButton(hWndDlg, IDC_OPTIONS_ScrnShotFormats_OHR, BST_UNCHECKED);
					}
					return TRUE;
				} break;
			case IDOK:
				{//apply all changes and return
					g_DirectX.SetVSync(BST_CHECKED == ::IsDlgButtonChecked(hWndDlg, IDC_OPTIONS_EnableVsync));
					g_DirectX.SetSmooth(BST_CHECKED == ::IsDlgButtonChecked(hWndDlg, IDC_OPTIONS_EnableSmooth));
					g_DirectX.SetAspectRatioPreservation(BST_CHECKED == ::IsDlgButtonChecked(hWndDlg, IDC_OPTIONS_EnablePreserveAspectRatio));
					if(BST_CHECKED == ::IsDlgButtonChecked(hWndDlg, IDC_OPTIONS_ScrnShotFormats_JPG))
						g_DirectX.SetImageFileFormat(D3DXIFF_JPG);
					else if(BST_CHECKED == ::IsDlgButtonChecked(hWndDlg, IDC_OPTIONS_ScrnShotFormats_BMP))
						g_DirectX.SetImageFileFormat(D3DXIFF_BMP);
					else if(BST_CHECKED == ::IsDlgButtonChecked(hWndDlg, IDC_OPTIONS_ScrnShotFormats_PNG))
						g_DirectX.SetImageFileFormat(D3DXIFF_PNG);
					else if(BST_CHECKED == ::IsDlgButtonChecked(hWndDlg, IDC_OPTIONS_ScrnShotFormats_DDS))
						g_DirectX.SetImageFileFormat(D3DXIFF_DDS);
					else
						g_DirectX.SetImageFileFormat(D3DXIFF_FORCE_DWORD);
				} //fallthrough on purpose
			case IDCANCEL:
				{//ignore all changes and return
					g_OSMouse.Pop_State();
					::DestroyWindow(hWndDlg);
					g_hWndDlg = NULL;
				} break;
			default:
				return FALSE;
			}
		} break;
	case WM_INITDIALOG:
		{
			g_OSMouse.Push_State();
			::CheckDlgButton(hWndDlg, IDC_OPTIONS_EnableVsync, (g_DirectX.IsVsyncEnabled() ? BST_CHECKED : BST_UNCHECKED));
			::CheckDlgButton(hWndDlg, IDC_OPTIONS_EnableSmooth, (g_DirectX.IsSmooth() ? BST_CHECKED : BST_UNCHECKED));
			::CheckDlgButton(hWndDlg, IDC_OPTIONS_EnablePreserveAspectRatio, (g_DirectX.IsAspectRatioPreserved() ? BST_CHECKED : BST_UNCHECKED));
			::SendDlgItemMessage(hWndDlg, IDC_OPTIONS_Status, WM_SETTEXT, 0, (LPARAM)g_DirectX.GetLastErrorMessage());
			TCHAR strInfoBuffer[128] = TEXT("");
			::_stprintf_s<128>(strInfoBuffer, TEXT("DirectX Backend version: %d.%d.%d\r\nhttp://www.hamsterrepublic.com"), DX_VERSION_MAJOR, DX_VERSION_MINOR, DX_VERSION_BUILD);
			::SendDlgItemMessage(hWndDlg, IDC_OPTIONS_Info, WM_SETTEXT, 0, (LPARAM)strInfoBuffer);
			if(g_DirectX.IsScreenShotsActive())
			{
				switch(g_DirectX.GetImageFileFormat())
				{
				case D3DXIFF_JPG:
					::CheckDlgButton(hWndDlg, IDC_OPTIONS_ScrnShotFormats_JPG, BST_CHECKED);
					break;
				case D3DXIFF_BMP:
					::CheckDlgButton(hWndDlg, IDC_OPTIONS_ScrnShotFormats_BMP, BST_CHECKED);
					break;
				case D3DXIFF_PNG:
					::CheckDlgButton(hWndDlg, IDC_OPTIONS_ScrnShotFormats_PNG, BST_CHECKED);
					break;
				case D3DXIFF_DDS:
					::CheckDlgButton(hWndDlg, IDC_OPTIONS_ScrnShotFormats_DDS, BST_CHECKED);
					break;
				default:
					::CheckDlgButton(hWndDlg, IDC_OPTIONS_ScrnShotFormats_OHR, BST_CHECKED);
				}
			}
			else
			{
				::CheckDlgButton(hWndDlg, IDC_OPTIONS_ScrnShotFormats_OHR, BST_CHECKED);
				::EnableWindow(::GetDlgItem(hWndDlg, IDC_OPTIONS_ScrnShotFormats_JPG), FALSE);
				::EnableWindow(::GetDlgItem(hWndDlg, IDC_OPTIONS_ScrnShotFormats_BMP), FALSE);
				::EnableWindow(::GetDlgItem(hWndDlg, IDC_OPTIONS_ScrnShotFormats_PNG), FALSE);
				::EnableWindow(::GetDlgItem(hWndDlg, IDC_OPTIONS_ScrnShotFormats_DDS), FALSE);
				::EnableWindow(::GetDlgItem(hWndDlg, IDC_OPTIONS_ScrnShotFormats_OHR), FALSE);
			}
		} break;
	default:
		return FALSE;
	}
	return TRUE;
}