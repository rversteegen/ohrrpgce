#include <string>
#include "joystick.hpp"
#include "gfx_directx.hpp"
#include "ohrstring.hpp"

#pragma comment (lib, "dxguid.lib")
using namespace gfx;

static int nInstanceCounter = 0;   // For assigning Device.nInstanceID


///////////////////////////////////////////////////////////////////////////////

// Callback called (from IDirectInput8->EnumDevices) for each game controller attached to the system
BOOL Joystick::EnumADevice(LPCDIDEVICEINSTANCE lpddi, LPVOID pvRef)
{
	if(pvRef == NULL)
		return DIENUM_STOP;

	std::list<Device>& m_devices = *(std::list<Device>*)pvRef;
	std::list<Device>::iterator iter = m_devices.begin();

	Device newDev;
	newDev.info = *lpddi;

	while(iter != m_devices.end())
	{
		if(IsEqualGUID(newDev.info.guidInstance, iter->info.guidInstance))
		{
			iter->bEnumRefreshed = true;
			return DIENUM_CONTINUE;
		}
		iter++;
	}

	newDev.nInstanceID = ++nInstanceCounter;
	m_devices.push_back(newDev);
	return DIENUM_CONTINUE;
}

// Callback called (from IDirectInputDevice8->EnumObjects) for each abs axis on a joystick
// Sets the desired range for the axis.
BOOL Joystick::EnumADeviceObject(LPCDIDEVICEOBJECTINSTANCE lpddoi, LPVOID pvRef)
{
	IDirectInputDevice8* pJoystick = (IDirectInputDevice8*)pvRef;
	if(lpddoi->dwType & DIDFT_AXIS)
	{
		DIPROPRANGE range;
		range.diph.dwHeaderSize = sizeof(range.diph);
		range.diph.dwHow = DIPH_BYID;
		range.diph.dwObj = lpddoi->dwType;
		range.diph.dwSize = sizeof(range);
		range.lMin = -1000;
		range.lMax = +1000;

		if(FAILED( pJoystick->SetProperty(DIPROP_RANGE, &range.diph) ))
			return DIENUM_STOP;

		// TODO: looking at src/joystick/windows/SDL_dinputjoystick.c in SDL 2,
		// you'll see that in this callback they work out which axes are actually
		// present, in order to number them. See the axis code in Joystick::Poll().
		// In order to number them they check (lpddoi is named dev there)
		// dev->guidType for each DIDFT_AXIS to find out which DIJOYSTATE member
		// holds the value for the axis. Incomplete implementation:
		/*
		#define IS_GUID(guid)  !memcmp(lpddoi->guidType, guid, sizeof(lpddoi->guidType)))
		#define ADD_AXIS(offset)  dev->axis_info[dev->nNumAxes++].off = offset

		if (IS_GUID(GUID_XAxis)) ADD_AXIS(DIJOFS_X);
		if (IS_GUID(GUID_YAxis)) ADD_AXIS(DIJOFS_Y);
		if (IS_GUID(GUID_ZAxis)) ADD_AXIS(DIJOFS_Z);
		if (IS_GUID(GUID_RxAxis)) ADD_AXIS(DIJOFS_RX);
		if (IS_GUID(GUID_RyAxis)) ADD_AXIS(DIJOFS_RY);
		if (IS_GUID(GUID_RzAxis)) ADD_AXIS(DIJOFS_RZ);
		if (IS_GUID(GUID_Slider)) ADD_AXIS(DIJOFS_SLIDER(dev->nNumSliders++));
		*/
	}

	// std::string objname = TstringToOHR(lpddoi->tszName);
	// debug(errInfo, "   device has object type=0x%x %s", lpddoi->dwFlags, objname.c_str());

	return DIENUM_CONTINUE;
}


///////////////////////////////////////////////////////////////////////////////


// Called after enumerating all devices: configure the new ones
void Joystick::configNewDevices()
{
	HRESULT hr = S_OK;
	std::list<Device>::iterator iter = m_devices.begin(), iterNext;
	while(iter != m_devices.end())
	{
		iterNext = iter;
		iterNext++;

		if(iter->bEnumNewDevice) // || iter->bEnumRefreshed)
		{
			std::string prodname = TstringToOHR(iter->info.tszProductName);
			std::string instname = TstringToOHR(iter->info.tszInstanceName);
			debug(errInfo, " Found %s %s type=0x%x", prodname.c_str(), instname.c_str(), iter->info.dwDevType);
		}
		if(iter->bEnumNewDevice)
		{
			const char *errsrc;
			iter->bEnumNewDevice = false;
			hr = m_dinput->CreateDevice(iter->info.guidInstance, &iter->pDevice, NULL);
			if(FAILED(hr))
			{
				errsrc = "CreateDevice";
				goto error;
			}
			// Foreground, so that the device input is lost when switching to another window
			hr = iter->pDevice->SetCooperativeLevel(m_hWnd, DISCL_FOREGROUND | DISCL_EXCLUSIVE);
			if(FAILED(hr))
			{
				errsrc = "SetCooperativeLevel";
				goto error;
			}
			// Want GetDeviceState to return a DIJOYSTATE
			hr = iter->pDevice->SetDataFormat(&c_dfDIJoystick);
			if(FAILED(hr))
			{
				errsrc = "SetDataFormat";
				goto error;
			}
			// Set the desired range -1000 to 1000 on each axis
			hr = iter->pDevice->EnumObjects((LPDIENUMDEVICEOBJECTSCALLBACK)EnumADeviceObject, (void*)iter->pDevice, DIDFT_ALL);
			if(FAILED(hr))
			{
				errsrc = "EnumObjects";
				goto error;
			}
			// Read properties
			DIDEVCAPS devcaps;
			devcaps.dwSize = sizeof(DIDEVCAPS);
			hr = iter->pDevice->GetCapabilities(&devcaps);
			if(FAILED(hr))
			{
				errsrc = "GetCapabilities";
				goto error;
			}
			iter->nNumButtons = devcaps.dwButtons;
			iter->nNumAxes = devcaps.dwAxes;  // Both absolute and relative axes
			iter->nNumHats = devcaps.dwPOVs;
			iter->bHasForceFeedback = !!(devcaps.dwFlags & DIDC_FORCEFEEDBACK);

			// Don't attempt to acquire yet; won't work if the Options menu is open

			debug(errInfo, " ...initialised successfully.");
			iter = iterNext;
			continue;

		  error:
			debug(errError, " ...but initialisation failed: %s %s", errsrc, HRESULTString(hr));
			m_devices.erase(iter);
		}
		iter = iterNext;
	}
}

// Called after configNewDevices(): remove entries from m_device that are no longer present
void Joystick::filterAttachedDevices()
{
	std::list<Device>::iterator iter = m_devices.begin(), iterNext;
	while( iter != m_devices.end() )
	{
		iterNext = iter;
		iterNext++;
		if(iter->bEnumRefreshed == false)
		{
			std::string name = TstringToOHR(iter->info.tszInstanceName);
			debug(errInfo, " Device %s disappeared", name.c_str());
			m_devices.erase(iter);
		}
		else
			iter->bEnumRefreshed = false;
		iter = iterNext;
	}
}

// Note: this does not re-initialise devices already known. Could need an option for that
void Joystick::refreshEnumeration()
{
	if(m_dinput == NULL)
		return;
	m_bRefreshRequest = FALSE;
	debug(errInfo, "Scanning for newly-attached joysticks");
	m_dinput->EnumDevices( DI8DEVCLASS_GAMECTRL, (LPDIENUMDEVICESCALLBACK)EnumADevice, (void*)&m_devices, DIEDFL_ATTACHEDONLY );
	configNewDevices();
	filterAttachedDevices();
}

///////////////////////////////////////////////////////////////////////////////


//COM initialization is used instead of loading the library
Joystick::Joystick() : /*m_hLibrary(NULL), */m_hWnd(NULL), m_bRefreshRequest(FALSE)
{
	//m_hLibrary = LoadLibrary(TEXT("dinput8.dll"));
}

Joystick::~Joystick()
{
	shutdown();

	//if(m_hLibrary)
	//	FreeLibrary(m_hLibrary);
	//m_hLibrary = NULL;
}

HRESULT Joystick::initialize(HINSTANCE hInstance, HWND hWnd)
{
	shutdown();

	HRESULT hr = S_OK;
	hr = CoCreateInstance( CLSID_DirectInput8, NULL, CLSCTX_INPROC_SERVER, IID_IDirectInput8, (void**)&m_dinput );
	if(FAILED(hr))
	{
		debug(errError, "Failed to DirectInput8 for joystick. Possibly lacking dinput8.dll: %s", HRESULTString(hr));
		return hr;
	}

	hr = m_dinput->Initialize(hInstance, DIRECTINPUT_VERSION);
	if(FAILED(hr))
	{
		debug(errError, "IDirectInput8->Initialize failed: %s", HRESULTString(hr));
		return hr;
	}

	m_hWnd = hWnd;

	refreshEnumeration();
	return hr;
}

void Joystick::shutdown()
{
	m_hWnd = NULL;
	m_devices.clear();
	m_dinput = NULL;
}

///////////////////////////////////////////////////////////////////////////////

UINT Joystick::getJoystickCount()
{
	// Detects unplugged devices, and triggers any delayed devices refresh
	poll();
	return m_devices.size();
}

// For io_get_joystick_state
int Joystick::getState(int nDevice, IOJoystickState *pState)
{
	if(m_dinput == NULL)
		return 1;
	if((UINT)nDevice >= m_devices.size() || nDevice < 0)
		return 1;

	Device &dev = *std::next(m_devices.begin(), nDevice);

	pState->structsize = 11;  //IOJOYSTICKSTATE_SZ;
	pState->buttons_down = dev.nButtonsDown;
	pState->buttons_new = 0;  // Not implemented
	memcpy(pState->axes, dev.axes, sizeof(dev.axes));
	memcpy(pState->hats, dev.hats, sizeof(dev.hats));

	pState->info.num_buttons = dev.nNumButtons;
	pState->info.num_axes = dev.nNumAxes;
	pState->info.num_hats = dev.nNumHats;
	pState->info.num_balls = 0;  // We didn't bother to count these during object enumeration
	memcpy(&pState->info.model_guid, &dev.info.guidProduct, sizeof(pState->info.model_guid));
	pState->info.instance_id = dev.nInstanceID;

	std::string prodname = TstringToOHR(dev.info.tszProductName);
	std::string instname = TstringToOHR(dev.info.tszInstanceName);
	snprintf(pState->info.name, sizeof(pState->info.name), "%s %s", prodname.c_str(), instname.c_str());

	if(dev.bIsNew)
	{
		dev.bIsNew = false;
		return -1;  //Acquired
	}
	return 0;  //Success
}

// For io_readjoysane
BOOL Joystick::getStateOld(int nDevice, unsigned int &buttons, int &xPos, int &yPos)
{
	if(m_dinput == NULL)
		return 1;
	if((UINT)nDevice >= m_devices.size() || nDevice < 0)
		return 1;

	Device &dev = *std::next(m_devices.begin(), nDevice);

	buttons = dev.nButtonsDown;
	// We configured the range to -1000 - 1000; io_readjoysane expects -100 - 100
	xPos = dev.axes[0] / 10;
	yPos = dev.axes[1] / 10;
	return TRUE;
}

void Joystick::poll()
{
	if(m_dinput == NULL)
		return;
	if(m_bRefreshRequest)
		refreshEnumeration();

	HRESULT hr = S_OK;
	DIJOYSTATE js;
	int joynum = 0;
	std::list<Device>::iterator iter = m_devices.begin(), iterNext;
	while(iter != m_devices.end())
	{
		iterNext = iter;
		iterNext++;
		std::string name_s = TstringToOHR(iter->info.tszInstanceName);
		const char *name = name_s.c_str();
		hr = iter->pDevice->Poll();

		switch(hr)
		{
		case DIERR_NOTACQUIRED:
		case DIERR_INPUTLOST:
			// INPUTLOST happens the first time we attempt to poll after the
			// the window becomes inactive, so that the device is lost; NOTACQUIRED
			// is the result of further polling.
			if (GetActiveWindow() == m_hWnd)
			{
				// Only attempt to acquire if this is the active window, otherwise it will fail.
				// (Note: we can't acquire, and aren't active, while the Options window is shown!)
				//debug(errInfo, "Acquiring device %s", name);
				hr = iter->pDevice->Acquire();
				if(hr == DIERR_UNPLUGGED)
				{
					debug(errInfo, "Acquiring device %s failed: no longer plugged in", name);
					refreshEnumeration();
					return;
				}
				else if(hr == DIERR_OTHERAPPHASPRIO)
				{
					// In use by another program; keep trying
					// (Seems this does sometimes happen even when active window)
				}
				else if(FAILED(hr))
				{
					debug(errInfo, "Acquiring device %s failed; dropping it: %s", name, HRESULTString(hr));
					m_devices.erase(iter);
					postEvent(eventLostJoystick, joynum);
					// Don't decrement joynum
				}
			}
			break;
		case DIERR_NOTINITIALIZED:
			debug(errError, "Poll(%s) error: Not initialized", name);
			refreshEnumeration();
			return;
		default:
			hr = iter->pDevice->GetDeviceState(sizeof(js), (void*)&js);
			if(FAILED(hr))
			{
				debug(errError, "GetDeviceState(%s) failed: %s", name, HRESULTString(hr));
				break;
			}
			iter->nButtonsDown = 0x0;
			for(UINT i = 0; i < 32; i++)
				iter->nButtonsDown |= (js.rgbButtons[i] & 0x80) ? (0x1 << i) : 0x0;
			// TODO: this numbering of axes is different from how SDL 2's DirectInput backend
			// numbers them, which is to skip axes which don't exist. See EnumADeviceObject.
			// However maybe they're numbered differently by other backends, including SDL 1.2's
			// Windows Multimedia backend
			iter->axes[0] = js.lX;
			iter->axes[1] = js.lY;
			iter->axes[2] = js.lZ;
			iter->axes[3] = js.lRx;
			iter->axes[4] = js.lRy;
			iter->axes[5] = js.lRz;
			iter->axes[6] = js.rglSlider[0];
			iter->axes[7] = js.rglSlider[1];
			debug(errInfo, "%s x %d y %d buttons %u", name, iter->axes[0], iter->axes[1], iter->nButtonsDown);
		}
		iter = iterNext;
		joynum++;
	}
}
