//joystick.h
//by Jay Tennant 10/5/10; updated 4/21/11
//manages joystick input through directinput

#pragma once

#include <windows.h>
#define DIRECTINPUT_VERSION 0x0800
#include <dinput.h>
#include "smartptr.hpp"
#include <list>
#include "../gfx.h"  //For IOJoystickState

namespace gfx
{
	class Joystick
	{
	protected:
		struct Device
		{
			Device() : nButtonsDown(0), bEnumNewDevice(true), bEnumRefreshed(true), bIsNew(true) {}
			~Device() {pDevice = NULL;}
			SmartPtr<IDirectInputDevice8> pDevice;
			DIDEVICEINSTANCE info;
			unsigned int nButtonsDown;
			int nNumButtons;
			int nNumAxes;
			int nNumHats;
			bool bHasForceFeedback;
			int axes[8];     // -1000 to 1000
			int hats[4];     // Length 4 bitvector: left=1, right=2, up=4, down=8
			int nInstanceID; // unique ID; unplugging and replugging assigns a new ID
			bool bIsNew;     // getState hasn't been called on this yet
			bool bEnumNewDevice; // refreshEnumeration use only
			bool bEnumRefreshed; // refreshEnumeration use only: this was seen during enumeration
		};

		static BOOL __stdcall EnumADevice(LPCDIDEVICEINSTANCE lpddi, LPVOID pvRef);
		static BOOL __stdcall EnumADeviceObject(LPCDIDEVICEOBJECTINSTANCE lpddoi, LPVOID pvRef);
	protected:
		HWND m_hWnd;
		BOOL m_bRefreshRequest;

		SmartPtr<IDirectInput8> m_dinput;
		std::list<Device> m_devices;

		void filterAttachedDevices(); //cleans list so only attached devices are in list
		void configNewDevices(); //sets data format, and initial button mappings for new devices
	public:
		Joystick();
		~Joystick();

		HRESULT initialize(HINSTANCE hInstance, HWND hWnd);
		void shutdown();

		void refreshEnumeration(); //refreshes the device list
		void delayedRefreshEnumeration() { m_bRefreshRequest = TRUE; }
		UINT getJoystickCount();
		int getState(int nDevice, IOJoystickState* pState);
		BOOL getStateOld(int nDevice, unsigned int& buttons, int& xPos, int& yPos);
		void poll();
	};
}
