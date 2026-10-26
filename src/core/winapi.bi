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
Const LB_TPM_RIGHTBUTTON = &h0002
Const LB_TPM_RETURNCMD = &h0100

Const LB_IDI_APPLICATION = 32512
Const LB_ERROR_ALREADY_EXISTS = 183
Const LB_LOCALE_SISO639LANGNAME = &h59
Const LB_MB_ICONINFORMATION = &h40

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
