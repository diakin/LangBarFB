' ---------------------------------------------------------------------------
'  caret.bi - где на экране текстовый курсор (каретка) окна.
'
'  Сейчас только GetGUIThreadInfo: окно с системной кареткой (Блокнот,
'  поля ввода Windows, Delphi/Lazarus, Word). Браузеры, Electron, окна
'  UWP системную каретку не ставят - для них LangBarXX спрашивает Acc и
'  UIA (Lib/GetCaretLocation.ahk), это следующий шаг.
' ---------------------------------------------------------------------------

#pragma once

#include once "winapi.bi"

' Каретка окна WindowHandle в экранных координатах: левый верхний угол
' (CaretPos) и высота. 0 - каретки нет или окно её не показывает.
Function CaretOfWindow(ByVal WindowHandle As Any Ptr, ByRef CaretPos As LbPoint, _
        ByRef CaretHeight As Long) As Long
    If WindowHandle = 0 Then Return 0
    Dim ThreadInfo As LbGuiThreadInfo
    ThreadInfo.cbSize = SizeOf(LbGuiThreadInfo)
    If LbGetGUIThreadInfo(LbGetWindowThreadProcessId(WindowHandle, 0), ThreadInfo) = 0 Then Return 0
    If ThreadInfo.hwndCaret = 0 Then Return 0
    ' пустой прямоугольник - показывать нечего
    If ThreadInfo.rcCaret.RectBottom <= ThreadInfo.rcCaret.RectTop Then Return 0
    CaretPos.PosX = ThreadInfo.rcCaret.RectLeft
    CaretPos.PosY = ThreadInfo.rcCaret.RectTop
    CaretHeight = ThreadInfo.rcCaret.RectBottom - ThreadInfo.rcCaret.RectTop
    LbClientToScreen(ThreadInfo.hwndCaret, CaretPos)
    Return 1
End Function
