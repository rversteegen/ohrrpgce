#include "joystick.h"
#pragma comment (lib, "dxguid.lib")
using namespace gfx;

BOOL Joystick::EnumDevices(LPCDIDEVICEINSTANCE lpddi, LPVOID pvRef)
{
	if(pvRef == NULL)
		return DIENUM_STOP;

	std::list<Device>& dev = *(std::list<Device>*)pvRef;
	std::list<Device>::iterator iter = dev.begin();

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

	dev.push_back(newDev);
	return DIENUM_CONTINUE;
}

BOOL Joystick::EnumDeviceObjects(LPCDIDEVICEOBJECTINSTANCE lpddoi, LPVOID pvRef)
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

//COM initialization is used instead of loading the library
Joystick::Joystick() : /*m_hLibrary(NULL), */m_hWnd(NULL)
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

void Joystick::filterAttachedDevices()
{
	if(m_devices.size() == 0)
		return;
	std::list<Device>::iterator iter = m_devices.begin(), iterNext;
	while( iter != m_devices.end() )
	{
		iterNext = iter;
		iterNext++;
		if(iter->bRefreshed == false)
			m_devices.erase(iter);
		else
			iter->bRefreshed = false;
		iter = iterNext;
	}
}

void Joystick::configNewDevices()
{
	HRESULT hr = S_OK;
	std::list<Device>::iterator iter = m_devices.begin(), iterNext;
	while(iter != m_devices.end())
	{
		iterNext = iter;
		iterNext++;
		if(iter->bNewDevice)
		{
			iter->bNewDevice = false;
			hr = m_dinput->CreateDevice(iter->info.guidInstance, &iter->pDevice, NULL);
			if(FAILED(hr))
				m_devices.erase(iter);
			hr = iter->pDevice->SetCooperativeLevel(m_hWnd, DISCL_FOREGROUND | DISCL_EXCLUSIVE);
			if(FAILED(hr))
				m_devices.erase(iter);
			hr = iter->pDevice->SetDataFormat(&c_dfDIJoystick);
			if(FAILED(hr))
				m_devices.erase(iter);
			hr = iter->pDevice->EnumObjects((LPDIENUMDEVICEOBJECTSCALLBACK)EnumDeviceObjects, (void*)iter->pDevice, DIDFT_PSHBUTTON | DIDFT_ABSAXIS);
			if(FAILED(hr))
				m_devices.erase(iter);
		}
		iter = iterNext;
	}
}

HRESULT Joystick::initialize(HINSTANCE hInstance, HWND hWnd)
{
	shutdown();

	HRESULT hr = S_OK;
	hr = CoCreateInstance( CLSID_DirectInput8, NULL, CLSCTX_INPROC_SERVER, IID_IDirectInput8, (void**)&m_dinput );
	if(FAILED(hr))
		return hr;

	hr = m_dinput->Initialize(hInstance, DIRECTINPUT_VERSION);
	if(FAILED(hr))
		return hr;

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

void Joystick::refreshEnumeration()
{
	if(m_dinput == NULL)
		return;
	m_dinput->EnumDevices( DI8DEVCLASS_GAMECTRL, (LPDIENUMDEVICESCALLBACK)EnumDevices, (void*)&m_devices, DIEDFL_ATTACHEDONLY );
	configNewDevices();
	filterAttachedDevices();
}

UINT Joystick::getJoystickCount()
{
	return m_devices.size();
}

BOOL Joystick::getState(int &nDevice, int &buttons, int &xPos, int &yPos)
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

	HRESULT hr = S_OK;
	DIJOYSTATE js;
	for(std::list<Device>::iterator iter = m_devices.begin(); iter != m_devices.end(); iter++)
	{
		hr = iter->pDevice->Poll();
		switch(hr)
		{
		case DIERR_NOTACQUIRED:
			iter->pDevice->Acquire();
			break;
		case DIERR_NOTINITIALIZED:
		case DIERR_INPUTLOST:
			refreshEnumeration();
			return;
		default:
			hr = iter->pDevice->GetDeviceState(sizeof(js), (void*)&js);
			if(FAILED(hr))
				break;
			iter->nButtons = 0x0;
			for(UINT i = 0; i < 32; i++)
				iter->nButtons |= (js.rgbButtons[i] & 0x80) ? (0x1 << i) : 0x0;
			iter->xPos = js.lX;
			iter->yPos = js.lY;
		}
	}
}