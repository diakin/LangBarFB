' ---------------------------------------------------------------------------
'  winapi.bi - функции и структуры Windows, нужные LangBarFB.
'  Объявлены здесь со своими именами (префикс Lb), а не через windows.bi:
'  так же сделано в RqLcl (rqrt.bi, rqtimer.bi), и имена не пересекаются
'  с типами rqlcl.bi.
'  Integer в FreeBASIC - размер указателя: 32 бита в win32, 64 в win64,
'  как WPARAM, LPARAM и LRESULT.
' ---------------------------------------------------------------------------

#pragma once

Const LB_WH_KEYBOARD_LL = 13
Const LB_HC_ACTION = 0

Const LB_WM_NULL = &h0000
Const LB_WM_DESTROY = &h0002
Const LB_WM_COMMAND = &h0111
Const LB_WM_KEYDOWN = &h0100
Const LB_WM_KEYUP = &h0101
Const LB_WM_SYSKEYDOWN = &h0104
Const LB_WM_SYSKEYUP = &h0105
Const LB_WM_LBUTTONUP = &h0202
Const LB_WM_LBUTTONDBLCLK = &h0203
Const LB_WM_RBUTTONUP = &h0205
Const LB_WM_APP = &h8000

Const LB_LLKHF_EXTENDED = &h01
Const LB_LLKHF_INJECTED = &h10
Const LB_LLKHF_ALTDOWN = &h20
Const LB_LLKHF_UP = &h80

Const LB_NIM_ADD = 0
Const LB_NIM_MODIFY = 1
Const LB_NIM_DELETE = 2
Const LB_NIF_MESSAGE = 1
Const LB_NIF_ICON = 2
Const LB_NIF_TIP = 4

Const LB_MF_STRING = &h0000
Const LB_MF_SEPARATOR = &h0800
Const LB_MF_GRAYED = &h0001
Const LB_MF_CHECKED = &h0008
Const LB_MF_POPUP = &h0010
Const LB_TPM_RIGHTBUTTON = &h0002
Const LB_TPM_RETURNCMD = &h0100

Const LB_IDI_APPLICATION = 32512
Const LB_ERROR_ALREADY_EXISTS = 183
Const LB_LOCALE_SISO639LANGNAME = &h59
Const LB_MB_ICONINFORMATION = &h40
Const LB_LOCALE_SISO3166CTRYNAME = &h5A
Const LB_WM_INPUTLANGCHANGEREQUEST = &h0050
Const LB_SM_CXSMICON = 49
Const LB_QS_ALLINPUT = &h04FF
Const LB_CP_ACP = 0

Type LbKbdLLHookStruct
    vkCode As ULong
    scanCode As ULong
    flags As ULong
    time As ULong
    dwExtraInfo As UInteger
End Type

Type LbPoint
    PosX As Long
    PosY As Long
End Type

Type LbRect
    RectLeft As Long
    RectTop As Long
    RectRight As Long
    RectBottom As Long
End Type

Type LbGuiThreadInfo
    cbSize As ULong
    flags As ULong
    hwndActive As Any Ptr
    hwndFocus As Any Ptr
    hwndCapture As Any Ptr
    hwndMenuOwner As Any Ptr
    hwndMoveSize As Any Ptr
    hwndCaret As Any Ptr
    rcCaret As LbRect
End Type

Type LbWndClassA
    style As ULong
    lpfnWndProc As Any Ptr
    cbClsExtra As Long
    cbWndExtra As Long
    hInstance As Any Ptr
    hIcon As Any Ptr
    hCursor As Any Ptr
    hbrBackground As Any Ptr
    lpszMenuName As ZString Ptr
    lpszClassName As ZString Ptr
End Type

' NOTIFYICONDATAA в первом варианте (до Windows 2000): этого хватает для
' значка, подсказки и сообщения о щелчке
Type LbNotifyIconDataA
    cbSize As ULong
    hWnd As Any Ptr
    uID As ULong
    uFlags As ULong
    uCallbackMessage As ULong
    hIcon As Any Ptr
    szTip As ZString * 64
End Type

Declare Function LbSetWindowsHookEx Lib "user32" Alias "SetWindowsHookExA" ( _
    ByVal HookId As Long, ByVal HookProc As Any Ptr, _
    ByVal ModuleHandle As Any Ptr, ByVal ThreadId As ULong) As Any Ptr
Declare Function LbUnhookWindowsHookEx Lib "user32" Alias "UnhookWindowsHookEx" ( _
    ByVal HookHandle As Any Ptr) As Long
Declare Function LbCallNextHookEx Lib "user32" Alias "CallNextHookEx" ( _
    ByVal HookHandle As Any Ptr, ByVal HookCode As Long, _
    ByVal WParam As UInteger, ByVal LParam As Integer) As Integer

Declare Function LbGetModuleHandle Lib "kernel32" Alias "GetModuleHandleA" ( _
    ByVal ModuleName As ZString Ptr) As Any Ptr
Declare Function LbCreateMutex Lib "kernel32" Alias "CreateMutexA" ( _
    ByVal Attributes As Any Ptr, ByVal InitialOwner As Long, _
    ByVal MutexName As ZString Ptr) As Any Ptr
Declare Function LbCloseHandle Lib "kernel32" Alias "CloseHandle" ( _
    ByVal ObjectHandle As Any Ptr) As Long
Declare Function LbGetLastError Lib "kernel32" Alias "GetLastError" () As ULong
Declare Function LbQueryPerformanceCounter Lib "kernel32" Alias "QueryPerformanceCounter" ( _
    ByRef Counter As LongInt) As Long
Declare Function LbQueryPerformanceFrequency Lib "kernel32" Alias "QueryPerformanceFrequency" ( _
    ByRef Frequency As LongInt) As Long
Declare Function LbGetLocaleInfo Lib "kernel32" Alias "GetLocaleInfoA" ( _
    ByVal LocaleId As ULong, ByVal LocaleType As ULong, _
    ByVal Buffer As ZString Ptr, ByVal BufferLen As Long) As Long

Declare Function LbRegisterClass Lib "user32" Alias "RegisterClassA" ( _
    ByRef WindowClass As LbWndClassA) As UShort
Declare Function LbCreateWindowEx Lib "user32" Alias "CreateWindowExA" ( _
    ByVal ExStyle As ULong, ByVal ClassName As ZString Ptr, _
    ByVal WindowName As ZString Ptr, ByVal Style As ULong, _
    ByVal PosX As Long, ByVal PosY As Long, ByVal WndWidth As Long, ByVal WndHeight As Long, _
    ByVal ParentWnd As Any Ptr, ByVal MenuHandle As Any Ptr, _
    ByVal InstanceHandle As Any Ptr, ByVal CreateParam As Any Ptr) As Any Ptr
Declare Function LbDestroyWindow Lib "user32" Alias "DestroyWindow" ( _
    ByVal WindowHandle As Any Ptr) As Long
Declare Function LbDefWindowProc Lib "user32" Alias "DefWindowProcA" ( _
    ByVal WindowHandle As Any Ptr, ByVal Msg As ULong, _
    ByVal WParam As UInteger, ByVal LParam As Integer) As Integer
Declare Function LbPostMessage Lib "user32" Alias "PostMessageA" ( _
    ByVal WindowHandle As Any Ptr, ByVal Msg As ULong, _
    ByVal WParam As UInteger, ByVal LParam As Integer) As Long

Declare Function LbGetForegroundWindow Lib "user32" Alias "GetForegroundWindow" () As Any Ptr
Declare Function LbSetForegroundWindow Lib "user32" Alias "SetForegroundWindow" ( _
    ByVal WindowHandle As Any Ptr) As Long
Declare Function LbGetWindowThreadProcessId Lib "user32" Alias "GetWindowThreadProcessId" ( _
    ByVal WindowHandle As Any Ptr, ByVal ProcessId As ULong Ptr) As ULong
Declare Function LbGetKeyboardLayout Lib "user32" Alias "GetKeyboardLayout" ( _
    ByVal ThreadId As ULong) As Any Ptr
Declare Function LbGetClassName Lib "user32" Alias "GetClassNameA" ( _
    ByVal WindowHandle As Any Ptr, ByVal Buffer As ZString Ptr, ByVal BufferLen As Long) As Long

Declare Function LbLoadIcon Lib "user32" Alias "LoadIconA" ( _
    ByVal InstanceHandle As Any Ptr, ByVal IconName As Any Ptr) As Any Ptr
Declare Function LbShell_NotifyIcon Lib "shell32" Alias "Shell_NotifyIconA" ( _
    ByVal Message As ULong, ByRef IconData As LbNotifyIconDataA) As Long

Declare Function LbCreatePopupMenu Lib "user32" Alias "CreatePopupMenu" () As Any Ptr
Declare Function LbAppendMenu Lib "user32" Alias "AppendMenuA" ( _
    ByVal MenuHandle As Any Ptr, ByVal Flags As ULong, _
    ByVal ItemId As UInteger, ByVal ItemText As ZString Ptr) As Long
Declare Function LbTrackPopupMenu Lib "user32" Alias "TrackPopupMenu" ( _
    ByVal MenuHandle As Any Ptr, ByVal Flags As ULong, _
    ByVal PosX As Long, ByVal PosY As Long, ByVal Reserved As Long, _
    ByVal WindowHandle As Any Ptr, ByVal RectPtr As Any Ptr) As Long
Declare Function LbDestroyMenu Lib "user32" Alias "DestroyMenu" ( _
    ByVal MenuHandle As Any Ptr) As Long
Declare Function LbGetCursorPos Lib "user32" Alias "GetCursorPos" ( _
    ByRef CursorPos As LbPoint) As Long
Declare Function LbMessageBox Lib "user32" Alias "MessageBoxA" ( _
    ByVal WindowHandle As Any Ptr, ByVal Text As ZString Ptr, _
    ByVal Caption As ZString Ptr, ByVal Flags As ULong) As Long

Declare Function LbGetKeyboardLayoutList Lib "user32" Alias "GetKeyboardLayoutList" ( _
    ByVal ListSize As Long, ByVal LayoutList As Any Ptr Ptr) As Long
Declare Function LbGetGUIThreadInfo Lib "user32" Alias "GetGUIThreadInfo" ( _
    ByVal ThreadId As ULong, ByRef ThreadInfo As LbGuiThreadInfo) As Long
Declare Function LbGetSystemMetrics Lib "user32" Alias "GetSystemMetrics" ( _
    ByVal MetricIndex As Long) As Long
Declare Function LbDestroyIcon Lib "user32" Alias "DestroyIcon" ( _
    ByVal IconHandle As Any Ptr) As Long
Declare Function LbMsgWaitForMultipleObjects Lib "user32" Alias "MsgWaitForMultipleObjects" ( _
    ByVal HandleCount As ULong, ByVal HandleList As Any Ptr, ByVal WaitAll As Long, _
    ByVal Milliseconds As ULong, ByVal WakeMask As ULong) As ULong
Declare Function LbMultiByteToWideChar Lib "kernel32" Alias "MultiByteToWideChar" ( _
    ByVal CodePage As ULong, ByVal Flags As ULong, ByVal SourceText As ZString Ptr, _
    ByVal SourceLen As Long, ByVal TargetText As WString Ptr, ByVal TargetLen As Long) As Long

' --- окна поверх всех (overlay.bi) ---
Const LB_WS_POPUP = &h80000000
Const LB_WS_EX_TOPMOST = &h00000008
Const LB_WS_EX_TRANSPARENT = &h00000020
Const LB_WS_EX_TOOLWINDOW = &h00000080
Const LB_WS_EX_LAYERED = &h00080000
Const LB_WS_EX_NOACTIVATE = &h08000000
Const LB_WM_MOUSEACTIVATE = &h0021
Const LB_MA_NOACTIVATE = 3
Const LB_SW_HIDE = 0
Const LB_SWP_NOSIZE = &h0001
Const LB_SWP_NOACTIVATE = &h0010
Const LB_SWP_SHOWWINDOW = &h0040
Const LB_ULW_ALPHA = 2
Const LB_AC_SRC_ALPHA = 1
Const LB_SM_CXSCREEN = 0
Const LB_SM_CYSCREEN = 1

Type LbSize
    SizeX As Long
    SizeY As Long
End Type

Type LbBlendFunction
    BlendOp As UByte
    BlendFlags As UByte
    SourceConstantAlpha As UByte
    AlphaFormat As UByte
End Type

Declare Function LbGetDC Lib "user32" Alias "GetDC" (ByVal WindowHandle As Any Ptr) As Any Ptr
Declare Function LbReleaseDC Lib "user32" Alias "ReleaseDC" ( _
    ByVal WindowHandle As Any Ptr, ByVal DeviceContext As Any Ptr) As Long
Declare Function LbCreateCompatibleDC Lib "gdi32" Alias "CreateCompatibleDC" ( _
    ByVal DeviceContext As Any Ptr) As Any Ptr
Declare Function LbDeleteDC Lib "gdi32" Alias "DeleteDC" (ByVal DeviceContext As Any Ptr) As Long
Declare Function LbSelectObject Lib "gdi32" Alias "SelectObject" ( _
    ByVal DeviceContext As Any Ptr, ByVal GdiObject As Any Ptr) As Any Ptr
Declare Function LbDeleteObject Lib "gdi32" Alias "DeleteObject" (ByVal GdiObject As Any Ptr) As Long
Declare Function LbUpdateLayeredWindow Lib "user32" Alias "UpdateLayeredWindow" ( _
    ByVal WindowHandle As Any Ptr, ByVal TargetDC As Any Ptr, ByRef TargetPos As LbPoint, _
    ByRef WindowSize As LbSize, ByVal SourceDC As Any Ptr, ByRef SourcePos As LbPoint, _
    ByVal ColorKey As ULong, ByRef Blend As LbBlendFunction, ByVal Flags As ULong) As Long
Declare Function LbSetWindowPos Lib "user32" Alias "SetWindowPos" ( _
    ByVal WindowHandle As Any Ptr, ByVal InsertAfter As Any Ptr, ByVal PosX As Long, ByVal PosY As Long, _
    ByVal WndWidth As Long, ByVal WndHeight As Long, ByVal Flags As ULong) As Long
Declare Function LbShowWindow Lib "user32" Alias "ShowWindow" ( _
    ByVal WindowHandle As Any Ptr, ByVal ShowCommand As Long) As Long
Declare Function LbIsWindowVisible Lib "user32" Alias "IsWindowVisible" ( _
    ByVal WindowHandle As Any Ptr) As Long
Declare Function LbClientToScreen Lib "user32" Alias "ClientToScreen" ( _
    ByVal WindowHandle As Any Ptr, ByRef ClientPos As LbPoint) As Long
Declare Function LbSetMenuDefaultItem Lib "user32" Alias "SetMenuDefaultItem" ( _
    ByVal MenuHandle As Any Ptr, ByVal ItemId As ULong, ByVal ByPosition As ULong) As Long

' --- ввод, буфер обмена, настройки, звук ---
Const LB_INPUT_KEYBOARD = 1
Const LB_KEYEVENTF_KEYUP = &h0002
Const LB_KEYEVENTF_UNICODE = &h0004
Const LB_CF_UNICODETEXT = 13
Const LB_GMEM_MOVEABLE = &h0002
Const LB_HKEY_CURRENT_USER = &h80000001
Const LB_KEY_SET_VALUE = &h0002
Const LB_REG_SZ = 1
Const LB_SND_ASYNC = &h0001
Const LB_SND_NODEFAULT = &h0002
Const LB_SND_FILENAME = &h00020000
Const LB_SW_SHOWNORMAL = 1
Const LB_MAPVK_VK_TO_VSC = 0
Const LB_MAPVK_VK_TO_CHAR = 2
Const LB_VK_SHIFT = &h10
Const LB_VK_CONTROL = &h11
Const LB_VK_MENU = &h12
Const LB_VK_CAPITAL = &h14
Const LB_VK_BACK = &h08
Const LB_VK_RETURN = &h0D

' INPUT для клавиатуры. Размер и смещения должны совпадать с INPUT Windows
' (28 байт в win32, 40 в win64): union там по самому большому члену -
' MOUSEINPUT, поэтому в конце запас, а в win64 union выровнен на 8
Type LbKeybdInput
    InputType As ULong
#ifdef __FB_64BIT__
    UnionAlign As ULong
#endif
    wVk As UShort
    wScan As UShort
    dwFlags As ULong
    time As ULong
    dwExtraInfo As UInteger
    ' два ULong, а не ULongInt: ULongInt в win32 выравнивается на 8, и
    ' структура выходила 32 байта - SendInput такую не принимает
    PaddingLow As ULong
    PaddingHigh As ULong
End Type

#ifdef __FB_64BIT__
#assert SizeOf(LbKeybdInput) = 40
#else
#assert SizeOf(LbKeybdInput) = 28
#endif

Declare Function LbSendInput Lib "user32" Alias "SendInput" ( _
    ByVal InputCount As ULong, ByVal Inputs As LbKeybdInput Ptr, ByVal InputSize As Long) As ULong
Declare Function LbGetAsyncKeyState Lib "user32" Alias "GetAsyncKeyState" (ByVal VirtualKey As Long) As Short
Declare Function LbGetKeyState Lib "user32" Alias "GetKeyState" (ByVal VirtualKey As Long) As Short
Declare Function LbMapVirtualKeyEx Lib "user32" Alias "MapVirtualKeyExW" ( _
    ByVal Code As ULong, ByVal MapType As ULong, ByVal LayoutHandle As Any Ptr) As ULong
Declare Function LbVkKeyScanEx Lib "user32" Alias "VkKeyScanExW" ( _
    ByVal Character As UShort, ByVal LayoutHandle As Any Ptr) As Short
Declare Function LbToUnicodeEx Lib "user32" Alias "ToUnicodeEx" ( _
    ByVal VirtualKey As ULong, ByVal ScanCode As ULong, ByVal KeyState As UByte Ptr, _
    ByVal Buffer As UShort Ptr, ByVal BufferLen As Long, ByVal Flags As ULong, _
    ByVal LayoutHandle As Any Ptr) As Long
Declare Function LbGetKeyNameText Lib "user32" Alias "GetKeyNameTextA" ( _
    ByVal LParam As Long, ByVal Buffer As ZString Ptr, ByVal BufferLen As Long) As Long
Declare Function LbIsCharAlpha Lib "user32" Alias "IsCharAlphaW" (ByVal Character As UShort) As Long
Declare Function LbIsCharLower Lib "user32" Alias "IsCharLowerW" (ByVal Character As UShort) As Long
Declare Function LbCharUpperBuff Lib "user32" Alias "CharUpperBuffW" ( _
    ByVal Buffer As UShort Ptr, ByVal BufferLen As ULong) As ULong
Declare Function LbCharLowerBuff Lib "user32" Alias "CharLowerBuffW" ( _
    ByVal Buffer As UShort Ptr, ByVal BufferLen As ULong) As ULong

Declare Function LbOpenClipboard Lib "user32" Alias "OpenClipboard" (ByVal OwnerWindow As Any Ptr) As Long
Declare Function LbCloseClipboard Lib "user32" Alias "CloseClipboard" () As Long
Declare Function LbEmptyClipboard Lib "user32" Alias "EmptyClipboard" () As Long
Declare Function LbGetClipboardData Lib "user32" Alias "GetClipboardData" (ByVal Format As ULong) As Any Ptr
Declare Function LbSetClipboardData Lib "user32" Alias "SetClipboardData" ( _
    ByVal Format As ULong, ByVal MemHandle As Any Ptr) As Any Ptr
Declare Function LbGetClipboardSequenceNumber Lib "user32" Alias "GetClipboardSequenceNumber" () As ULong
Declare Function LbGlobalAlloc Lib "kernel32" Alias "GlobalAlloc" ( _
    ByVal Flags As ULong, ByVal ByteCount As UInteger) As Any Ptr
Declare Function LbGlobalLock Lib "kernel32" Alias "GlobalLock" (ByVal MemHandle As Any Ptr) As Any Ptr
Declare Function LbGlobalUnlock Lib "kernel32" Alias "GlobalUnlock" (ByVal MemHandle As Any Ptr) As Long
Declare Function LbGlobalFree Lib "kernel32" Alias "GlobalFree" (ByVal MemHandle As Any Ptr) As Any Ptr
Declare Function LbGlobalSize Lib "kernel32" Alias "GlobalSize" (ByVal MemHandle As Any Ptr) As UInteger

Declare Function LbGetPrivateProfileString Lib "kernel32" Alias "GetPrivateProfileStringA" ( _
    ByVal Section As ZString Ptr, ByVal KeyName As ZString Ptr, ByVal DefaultValue As ZString Ptr, _
    ByVal Buffer As ZString Ptr, ByVal BufferLen As ULong, ByVal FileName As ZString Ptr) As ULong
Declare Function LbWritePrivateProfileString Lib "kernel32" Alias "WritePrivateProfileStringA" ( _
    ByVal Section As ZString Ptr, ByVal KeyName As ZString Ptr, ByVal Value As ZString Ptr, _
    ByVal FileName As ZString Ptr) As Long

Declare Function LbRegOpenKeyEx Lib "advapi32" Alias "RegOpenKeyExA" ( _
    ByVal RootKey As UInteger, ByVal SubKey As ZString Ptr, ByVal Options As ULong, _
    ByVal Access As ULong, ByRef ResultKey As Any Ptr) As Long
Declare Function LbRegSetValueEx Lib "advapi32" Alias "RegSetValueExA" ( _
    ByVal KeyHandle As Any Ptr, ByVal ValueName As ZString Ptr, ByVal Reserved As ULong, _
    ByVal ValueType As ULong, ByVal ValueData As Any Ptr, ByVal DataSize As ULong) As Long
Declare Function LbRegDeleteValue Lib "advapi32" Alias "RegDeleteValueA" ( _
    ByVal KeyHandle As Any Ptr, ByVal ValueName As ZString Ptr) As Long
Declare Function LbRegCloseKey Lib "advapi32" Alias "RegCloseKey" (ByVal KeyHandle As Any Ptr) As Long

Declare Function LbPlaySound Lib "winmm" Alias "PlaySoundA" ( _
    ByVal SoundName As ZString Ptr, ByVal ModuleHandle As Any Ptr, ByVal Flags As ULong) As Long
Declare Function LbMessageBeep Lib "user32" Alias "MessageBeep" (ByVal BeepType As ULong) As Long
Declare Function LbShellExecute Lib "shell32" Alias "ShellExecuteA" ( _
    ByVal WindowHandle As Any Ptr, ByVal Operation As ZString Ptr, ByVal FileName As ZString Ptr, _
    ByVal Parameters As ZString Ptr, ByVal Directory As ZString Ptr, ByVal ShowCommand As Long) As Any Ptr

Const LB_VK_CANCEL = &h03
Const LB_VK_TAB = &h09
Const LB_VK_PAUSE = &h13
Const LB_VK_ESCAPE = &h1B
Const LB_VK_SPACE = &h20
Const LB_VK_LEFT = &h25
Const LB_VK_LWIN = &h5B
Const LB_VK_RWIN = &h5C
Const LB_VK_SCROLL = &h91
Const LB_VK_LSHIFT = &hA0
Const LB_VK_RMENU = &hA5
' клавиша без назначения: её нажатие после Alt или Win не даёт открыться
' меню окна или меню «Пуск» (так делает AutoHotkey, vkE8)
Const LB_VK_MENU_MASK = &hE8

Const LB_WH_MOUSE_LL = 14
Const LB_WM_LBUTTONDOWN = &h0201
Const LB_WM_RBUTTONDOWN = &h0204
Const LB_WM_MBUTTONDOWN = &h0207

Declare Function LbGetModuleFileName Lib "kernel32" Alias "GetModuleFileNameA" ( _
    ByVal ModuleHandle As Any Ptr, ByVal Buffer As ZString Ptr, ByVal BufferLen As ULong) As ULong

Const LB_LOCALE_SLANGUAGE = &h2
Const LB_VK_NUMLOCK = &h90
Const LB_VK_LCONTROL = &hA2
Const LB_VK_LMENU = &hA4

' --- словари Hunspell (spell.bi) ---
Const LB_CP_ACP = 0
Const LB_CP_UTF8 = 65001
Declare Function LbLoadLibrary Lib "kernel32" Alias "LoadLibraryA" ( _
    ByVal FileName As ZString Ptr) As Any Ptr
Declare Function LbGetProcAddress Lib "kernel32" Alias "GetProcAddress" ( _
    ByVal ModuleHandle As Any Ptr, ByVal ProcName As ZString Ptr) As Any Ptr
Declare Function LbWideCharToMultiByte Lib "kernel32" Alias "WideCharToMultiByte" ( _
    ByVal CodePage As ULong, ByVal Flags As ULong, ByVal SourceText As WString Ptr, _
    ByVal SourceLen As Long, ByVal TargetText As ZString Ptr, ByVal TargetLen As Long, _
    ByVal DefaultChar As ZString Ptr, ByVal UsedDefault As Long Ptr) As Long
Declare Function LbIsCharUpper Lib "user32" Alias "IsCharUpperW" (ByVal Character As UShort) As Long
Declare Function LbIsCharAlphaNumeric Lib "user32" Alias "IsCharAlphaNumericW" (ByVal Character As UShort) As Long

' --- скачивание словарей (dictload.bi) ---
Const LB_MB_YESNO = &h4
Const LB_MB_ICONQUESTION = &h20
Const LB_MB_ICONWARNING = &h30
Const LB_IDYES = 6
Type LbThreadStartFn As Function stdcall (ByVal Param As Any Ptr) As ULong
Declare Function LbCreateThread Lib "kernel32" Alias "CreateThread" ( _
    ByVal Attributes As Any Ptr, ByVal StackSize As UInteger, ByVal StartAddress As LbThreadStartFn, _
    ByVal Param As Any Ptr, ByVal CreationFlags As ULong, ByVal ThreadId As ULong Ptr) As Any Ptr
Declare Function LbURLDownloadToFile Lib "urlmon" Alias "URLDownloadToFileA" ( _
    ByVal Caller As Any Ptr, ByVal SourceUrl As ZString Ptr, ByVal TargetFile As ZString Ptr, _
    ByVal Reserved As ULong, ByVal Callback As Any Ptr) As Long
Declare Function LbCoInitialize Lib "ole32" Alias "CoInitialize" (ByVal Reserved As Any Ptr) As Long
Declare Sub LbCoUninitialize Lib "ole32" Alias "CoUninitialize" ()
Declare Function LbDeleteFile Lib "kernel32" Alias "DeleteFileA" (ByVal FileName As ZString Ptr) As Long

' запасной источник библиотеки Hunspell - zip (пакет NuGet), его
' распаковывает cscript со скриптом Shell.Application
Type LbStartupInfo
    StructSize As ULong
    Reserved As Any Ptr
    Desktop As Any Ptr
    Title As Any Ptr
    PosX As ULong
    PosY As ULong
    SizeX As ULong
    SizeY As ULong
    CountCharsX As ULong
    CountCharsY As ULong
    FillAttribute As ULong
    Flags As ULong
    ShowWindow As UShort
    ReservedSize As UShort
    ReservedBytes As Any Ptr
    StdInput As Any Ptr
    StdOutput As Any Ptr
    StdError As Any Ptr
End Type
Type LbProcessInfo
    ProcessHandle As Any Ptr
    ThreadHandle As Any Ptr
    ProcessId As ULong
    ThreadId As ULong
End Type
#ifdef __FB_64BIT__
#assert SizeOf(LbStartupInfo) = 104
#assert SizeOf(LbProcessInfo) = 24
#else
#assert SizeOf(LbStartupInfo) = 68
#assert SizeOf(LbProcessInfo) = 16
#endif
Const LB_CREATE_NO_WINDOW = &h08000000
Const LB_INVALID_FILE_ATTRIBUTES = &hFFFFFFFF
Declare Function LbCreateProcess Lib "kernel32" Alias "CreateProcessA" ( _
    ByVal ApplicationName As ZString Ptr, ByVal CommandLine As ZString Ptr, _
    ByVal ProcessAttributes As Any Ptr, ByVal ThreadAttributes As Any Ptr, ByVal InheritHandles As Long, _
    ByVal CreationFlags As ULong, ByVal Environment As Any Ptr, ByVal CurrentDirectory As ZString Ptr, _
    ByRef StartupInfo As LbStartupInfo, ByRef ProcessInfo As LbProcessInfo) As Long
Declare Function LbWaitForSingleObject Lib "kernel32" Alias "WaitForSingleObject" ( _
    ByVal ObjectHandle As Any Ptr, ByVal Milliseconds As ULong) As ULong
Declare Function LbGetFileAttributes Lib "kernel32" Alias "GetFileAttributesA" ( _
    ByVal FileName As ZString Ptr) As ULong

' версия библиотеки Hunspell (spell.bi): у NHunspell 0.9.6 и новее
' HunspellInit принимает содержимое файлов, а не пути
Declare Function LbGetFileVersionInfoSize Lib "version" Alias "GetFileVersionInfoSizeA" ( _
    ByVal FileName As ZString Ptr, ByVal Handle As ULong Ptr) As ULong
Declare Function LbGetFileVersionInfo Lib "version" Alias "GetFileVersionInfoA" ( _
    ByVal FileName As ZString Ptr, ByVal Handle As ULong, ByVal BufferLen As ULong, ByVal Buffer As Any Ptr) As Long
Declare Function LbVerQueryValue Lib "version" Alias "VerQueryValueA" ( _
    ByVal Block As Any Ptr, ByVal SubBlock As ZString Ptr, ByVal ValuePtr As Any Ptr Ptr, ByVal ValueLen As ULong Ptr) As Long

Declare Function LbIsChild Lib "user32" Alias "IsChild" ( _
    ByVal ParentHandle As Any Ptr, ByVal WindowHandle As Any Ptr) As Long

Const LB_IDC_ARROW = 32512
Declare Function LbLoadCursor Lib "user32" Alias "LoadCursorA" ( _
    ByVal Instance As Any Ptr, ByVal CursorName As Any Ptr) As Any Ptr
