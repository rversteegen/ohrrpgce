#include <string>
#include "joystick.hpp"
#include "gfx_directx.hpp"
#include "ohrstring.hpp"

#pragma comment (lib, "dxguid.lib")
using namespace gfx;


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

	while(iter != dev.end())
	{
		if(IsEqualGUID(newDev.info.guidInstance, iter->info.guidInstance))
		{
			iter->bRefreshed = true;
			return DIENUM_CONTINUE;
		}
		iter++;
	}

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
		range.lMin = -100;
		range.lMax = +100;

		if(FAILED( pJoystick->SetProperty(DIPROP_RANGE, &range.diph) ))
			return DIENUM_STOP;
	}
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

		if(iter->bNewDevice) // || iter->bRefreshed)
		{
			std::string name = TstringToOHR(iter->info.tszProductName);
			std::string instname = TstringToOHR(iter->info.tszInstanceName);
			debug(errInfo, " Found %s %s type=0x%x", prodname.c_str(), instname.c_str(), iter->info.dwDevType);
		}
		if(iter->bNewDevice)
		{
			const char *errsrc;
			iter->bNewDevice = false;
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
			hr = iter->pDevice->EnumObjects((LPDIENUMDEVICEOBJECTSCALLBACK)EnumADeviceObject, (void*)iter->pDevice, DIDFT_ABSAXIS);
			if(FAILED(hr))
			{
				errsrc = "EnumObjects";
				goto error;
			}
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
		if(iter->bRefreshed == false)
		{
			std::string name = TstringToOHR(iter->info.tszInstanceName);
			debug(errInfo, " Device %s disappeared", name.c_str());
			m_devices.erase(iter);
		}
		else
			iter->bRefreshed = false;
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

BOOL Joystick::getState(int &nDevice, unsigned int &buttons, int &xPos, int &yPos)
{
	if(m_dinput == NULL)
		return FALSE;
	if((UINT)nDevice >= m_devices.size() || nDevice < 0)
		return FALSE;

	std::list<Device>::iterator iter = m_devices.begin();
	for(int i = 0; i < nDevice; i++, iter++);

	buttons = iter->nButtons;
	xPos = iter->xPos;
	yPos = iter->yPos;
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
			iter->nButtons = 0x0;
			for(UINT i = 0; i < 32; i++)
				iter->nButtons |= (js.rgbButtons[i] & 0x80) ? (0x1 << i) : 0x0;
			iter->xPos = js.lX;
			iter->yPos = js.lY;
			//debug(errInfo, "%s x %d y %d buttons %u", name, iter->xPos, iter->yPos, iter->nButtons);
		}
		iter = iterNext;
	}
}
