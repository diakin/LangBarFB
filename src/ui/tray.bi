' ---------------------------------------------------------------------------
'  tray.bi - служебное окно и значок в области уведомлений.
'
'  Служебное окно - обычное невидимое окно своего класса (не окно RqLcl):
'  ему приходят сообщения значка и сообщения хука. Окно с HWND_MESSAGE
'  не подходит: оно не может стать активным, и меню значка тогда не
'  закрывается щелчком мимо.
'  Строки здесь в CP1251 (функции ...A), как и в RqLcl.
' ---------------------------------------------------------------------------

#pragma once

#include once "../core/winapi.bi"

Const TRAY_ICON_ID = 1
Const TRAY_CALLBACK_MSG = LB_WM_APP + 1
Const TRAY_CMD_SHOW = 101
Const TRAY_CMD_EXIT = 102

Type TrayHandlerFn As Sub()
Type MessageHandlerFn As Sub(ByVal Msg As ULong)

Dim Shared TrayWindow As Any Ptr
Dim Shared TrayIconData As LbNotifyIconDataA
Dim Shared TrayOnShow As TrayHandlerFn
Dim Shared TrayOnClick As TrayHandlerFn
Dim Shared TrayIconHandle As Any Ptr
Dim Shared TrayOnExit As TrayHandlerFn
' сообщения LB_WM_APP + 2 и дальше уходят сюда (сигнал хука и т. п.)
Dim Shared TrayOnAppMessage As MessageHandlerFn

Private Sub TrayShowMenu()
    Dim MenuHandle As Any Ptr = LbCreatePopupMenu()
    LbAppendMenu(MenuHandle, LB_MF_STRING, TRAY_CMD_SHOW, "Окно отладки")
    LbAppendMenu(MenuHandle, LB_MF_SEPARATOR, 0, 0)
    LbAppendMenu(MenuHandle, LB_MF_STRING, TRAY_CMD_EXIT, "Выход")
    Dim CursorPos As LbPoint
    LbGetCursorPos(CursorPos)
    ' без этого меню не закрывается щелчком в другом месте (KB135788)
    LbSetForegroundWindow(TrayWindow)
    Dim ChosenId As Long = LbTrackPopupMenu(MenuHandle, _
        LB_TPM_RIGHTBUTTON Or LB_TPM_RETURNCMD, CursorPos.PosX, CursorPos.PosY, 0, TrayWindow, 0)
    LbPostMessage(TrayWindow, LB_WM_NULL, 0, 0)
    LbDestroyMenu(MenuHandle)
    Select Case ChosenId
    Case TRAY_CMD_SHOW
        If TrayOnShow <> 0 Then TrayOnShow()
    Case TRAY_CMD_EXIT
        If TrayOnExit <> 0 Then TrayOnExit()
    End Select
End Sub

Private Function TrayWndProc stdcall (ByVal WindowHandle As Any Ptr, ByVal Msg As ULong, _
        ByVal WParam As UInteger, ByVal LParam As Integer) As Integer
    If Msg = TRAY_CALLBACK_MSG Then
        Select Case CULng(LParam)
        Case LB_WM_RBUTTONUP
            TrayShowMenu()
        Case LB_WM_LBUTTONUP
            If TrayOnClick <> 0 Then TrayOnClick()
        End Select
        Return 0
    End If
    If Msg > TRAY_CALLBACK_MSG And Msg < LB_WM_APP + &h100 Then
        If TrayOnAppMessage <> 0 Then TrayOnAppMessage(Msg)
        Return 0
    End If
    Return LbDefWindowProc(WindowHandle, Msg, WParam, LParam)
End Function

' Создаёт служебное окно и значок. IconHandle 0 - стандартный значок
' приложения (его заменит TraySetIcon)
Function TrayCreate(ByRef TipText As String, ByVal IconHandle As Any Ptr = 0) As Long
    Dim InstanceHandle As Any Ptr = LbGetModuleHandle(0)
    Dim WindowClass As LbWndClassA
    Dim ClassName As ZString * 32 = "LangBarFB_Service"
    WindowClass.lpfnWndProc = @TrayWndProc
    WindowClass.hInstance = InstanceHandle
    WindowClass.lpszClassName = @ClassName
    If LbRegisterClass(WindowClass) = 0 Then Return 0
    TrayWindow = LbCreateWindowEx(0, @ClassName, "LangBarFB", 0, 0, 0, 0, 0, 0, 0, InstanceHandle, 0)
    If TrayWindow = 0 Then Return 0

    TrayIconData.cbSize = SizeOf(LbNotifyIconDataA)
    TrayIconData.hWnd = TrayWindow
    TrayIconData.uID = TRAY_ICON_ID
    TrayIconData.uFlags = LB_NIF_MESSAGE Or LB_NIF_ICON Or LB_NIF_TIP
    TrayIconData.uCallbackMessage = TRAY_CALLBACK_MSG
    If IconHandle = 0 Then IconHandle = LbLoadIcon(0, Cast(Any Ptr, LB_IDI_APPLICATION))
    TrayIconData.hIcon = IconHandle
    TrayIconData.szTip = Left(TipText, 63)
    Return LbShell_NotifyIcon(LB_NIM_ADD, TrayIconData)
End Function

Sub TraySetTip(ByRef TipText As String)
    If TrayWindow = 0 Then Exit Sub
    TrayIconData.uFlags = LB_NIF_TIP
    TrayIconData.szTip = Left(TipText, 63)
    LbShell_NotifyIcon(LB_NIM_MODIFY, TrayIconData)
End Sub

' Новый значок; прежний, если его дала программа, освобождается
Sub TraySetIcon(ByVal IconHandle As Any Ptr)
    If TrayWindow = 0 Or IconHandle = 0 Then Exit Sub
    TrayIconData.uFlags = LB_NIF_ICON
    TrayIconData.hIcon = IconHandle
    LbShell_NotifyIcon(LB_NIM_MODIFY, TrayIconData)
    If TrayIconHandle <> 0 Then LbDestroyIcon(TrayIconHandle)
    TrayIconHandle = IconHandle
End Sub

Sub TrayDestroy()
    If TrayWindow = 0 Then Exit Sub
    LbShell_NotifyIcon(LB_NIM_DELETE, TrayIconData)
    LbDestroyWindow(TrayWindow)
    TrayWindow = 0
    If TrayIconHandle <> 0 Then
        LbDestroyIcon(TrayIconHandle)
        TrayIconHandle = 0
    End If
End Sub
