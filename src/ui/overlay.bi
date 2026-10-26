' ---------------------------------------------------------------------------
'  overlay.bi - окна поверх всех без рамки (флажок у каретки, крупный
'  флажок при смене раскладки).
'
'  Окно слоистое (WS_EX_LAYERED), картинка ставится UpdateLayeredWindow
'  с альфа-каналом: края флажка сглажены, прозрачное - прозрачно. Окно не
'  активируется (WS_EX_NOACTIVATE, WM_MOUSEACTIVATE), поэтому щелчок по
'  нему не уводит фокус из окна, где печатают. ClickThrough = 1 - окно
'  пропускает мышь насквозь (WS_EX_TRANSPARENT).
'
'  Часть LangBarFB (https://github.com/diakin/LangBarFB), лицензия LGPL-3.0
'  (COPYING.LESSER и COPYING в корне репозитория).
' ---------------------------------------------------------------------------

#pragma once

#include once "../core/winapi.bi"
#include once "gfx.bi"

Const MAX_OVERLAYS = 4

Type OverlayClickFn As Sub()

Type OverlayWindow
    WindowHandle As Any Ptr
    OnClick As OverlayClickFn
    OnRightClick As OverlayClickFn
    ImageWidth As Long
    ImageHeight As Long
End Type

Dim Shared OverlayList(0 To MAX_OVERLAYS - 1) As OverlayWindow Ptr
Dim Shared OverlayClassReady As Long

Private Function OverlayFind(ByVal WindowHandle As Any Ptr) As OverlayWindow Ptr
    Dim OverlayIdx As Long
    For OverlayIdx = 0 To MAX_OVERLAYS - 1
        If OverlayList(OverlayIdx) <> 0 Then
            If OverlayList(OverlayIdx)->WindowHandle = WindowHandle Then Return OverlayList(OverlayIdx)
        End If
    Next
    Return 0
End Function

Private Function OverlayWndProc stdcall (ByVal WindowHandle As Any Ptr, ByVal Msg As ULong, _
        ByVal WParam As UInteger, ByVal LParam As Integer) As Integer
    Select Case Msg
    Case LB_WM_MOUSEACTIVATE
        Return LB_MA_NOACTIVATE
    Case LB_WM_LBUTTONUP
        Dim Overlay As OverlayWindow Ptr = OverlayFind(WindowHandle)
        If Overlay <> 0 Then
            If Overlay->OnClick <> 0 Then Overlay->OnClick()
        End If
        Return 0
    Case LB_WM_RBUTTONUP
        Dim Overlay As OverlayWindow Ptr = OverlayFind(WindowHandle)
        If Overlay <> 0 Then
            If Overlay->OnRightClick <> 0 Then Overlay->OnRightClick()
        End If
        Return 0
    Case LB_WM_CLOSE
        ' окно закрывает программа сама (OverlayDestroy); WM_CLOSE снаружи
        ' (останов из среды разработки) приходит и в служебное окно
        Return 0
    End Select
    Return LbDefWindowProc(WindowHandle, Msg, WParam, LParam)
End Function

Function OverlayCreate(ByRef Overlay As OverlayWindow, ByVal ClickThrough As Long) As Long
    Dim InstanceHandle As Any Ptr = LbGetModuleHandle(0)
    Dim ClassName As ZString * 32 = "LangBarFB_Overlay"
    If OverlayClassReady = 0 Then
        Dim WindowClass As LbWndClassA
        WindowClass.lpfnWndProc = @OverlayWndProc
        WindowClass.hInstance = InstanceHandle
        ' без курсора класса Windows оставляет над окном прежний курсор
        ' (часики, если он был таким)
        WindowClass.hCursor = LbLoadCursor(0, Cast(Any Ptr, LB_IDC_ARROW))
        WindowClass.lpszClassName = @ClassName
        If LbRegisterClass(WindowClass) = 0 Then Return 0
        OverlayClassReady = 1
    End If
    Dim ExStyle As ULong = LB_WS_EX_LAYERED Or LB_WS_EX_TOPMOST Or LB_WS_EX_TOOLWINDOW Or LB_WS_EX_NOACTIVATE
    If ClickThrough Then ExStyle Or= LB_WS_EX_TRANSPARENT
    Overlay.WindowHandle = LbCreateWindowEx(ExStyle, @ClassName, "", LB_WS_POPUP, _
        0, 0, 0, 0, 0, 0, InstanceHandle, 0)
    If Overlay.WindowHandle = 0 Then Return 0
    Dim OverlayIdx As Long
    For OverlayIdx = 0 To MAX_OVERLAYS - 1
        If OverlayList(OverlayIdx) = 0 Then
            OverlayList(OverlayIdx) = @Overlay
            Exit For
        End If
    Next
    Return 1
End Function

' Ставит картинку GDI+ Image в окно и показывает его в точке PosX, PosY
' (левый верхний угол). Картинку освобождает вызывающий.
Sub OverlayShowImage(ByRef Overlay As OverlayWindow, ByVal Image As Any Ptr, _
        ByVal PosX As Long, ByVal PosY As Long)
    If Overlay.WindowHandle = 0 Or Image = 0 Then Exit Sub
    Dim ImgWidth As ULong, ImgHeight As ULong
    GdipGetImageWidth(Image, ImgWidth)
    GdipGetImageHeight(Image, ImgHeight)

    Dim BitmapHandle As Any Ptr
    If GdipCreateHBITMAPFromBitmap(Image, BitmapHandle, 0) <> 0 Then Exit Sub
    Dim ScreenDC As Any Ptr = LbGetDC(0)
    Dim MemoryDC As Any Ptr = LbCreateCompatibleDC(ScreenDC)
    Dim PrevBitmap As Any Ptr = LbSelectObject(MemoryDC, BitmapHandle)

    Dim TargetPos As LbPoint, SourcePos As LbPoint, WindowSize As LbSize
    TargetPos.PosX = PosX : TargetPos.PosY = PosY
    WindowSize.SizeX = ImgWidth : WindowSize.SizeY = ImgHeight
    Dim Blend As LbBlendFunction
    Blend.SourceConstantAlpha = 255
    Blend.AlphaFormat = LB_AC_SRC_ALPHA
    LbUpdateLayeredWindow(Overlay.WindowHandle, ScreenDC, TargetPos, WindowSize, _
        MemoryDC, SourcePos, 0, Blend, LB_ULW_ALPHA)

    LbSelectObject(MemoryDC, PrevBitmap)
    LbDeleteDC(MemoryDC)
    LbReleaseDC(0, ScreenDC)
    LbDeleteObject(BitmapHandle)

    Overlay.ImageWidth = ImgWidth
    Overlay.ImageHeight = ImgHeight
    ' HWND_TOPMOST (-1): поверх окон, которые тоже «поверх всех»
    LbSetWindowPos(Overlay.WindowHandle, Cast(Any Ptr, -1), PosX, PosY, 0, 0, _
        LB_SWP_NOSIZE Or LB_SWP_NOACTIVATE Or LB_SWP_SHOWWINDOW)
End Sub

' Переносит уже показанное окно без перерисовки
Sub OverlayMove(ByRef Overlay As OverlayWindow, ByVal PosX As Long, ByVal PosY As Long)
    If Overlay.WindowHandle = 0 Then Exit Sub
    LbSetWindowPos(Overlay.WindowHandle, Cast(Any Ptr, -1), PosX, PosY, 0, 0, _
        LB_SWP_NOSIZE Or LB_SWP_NOACTIVATE Or LB_SWP_SHOWWINDOW)
End Sub

Sub OverlayHide(ByRef Overlay As OverlayWindow)
    If Overlay.WindowHandle <> 0 Then LbShowWindow(Overlay.WindowHandle, LB_SW_HIDE)
End Sub

Function OverlayVisible(ByRef Overlay As OverlayWindow) As Long
    If Overlay.WindowHandle = 0 Then Return 0
    Return IIf(LbIsWindowVisible(Overlay.WindowHandle) <> 0, 1, 0)
End Function

Sub OverlayDestroy(ByRef Overlay As OverlayWindow)
    If Overlay.WindowHandle = 0 Then Exit Sub
    Dim OverlayIdx As Long
    For OverlayIdx = 0 To MAX_OVERLAYS - 1
        If OverlayList(OverlayIdx) = @Overlay Then OverlayList(OverlayIdx) = 0
    Next
    LbDestroyWindow(Overlay.WindowHandle)
    Overlay.WindowHandle = 0
End Sub
