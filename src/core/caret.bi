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

' что вернул GetGUIThreadInfo в последний раз - для окна отладки
Dim Shared CaretDebugText As String

Private Function CaretClassOf(ByVal WindowHandle As Any Ptr) As String
    If WindowHandle = 0 Then Return "-"
    Dim ClassBuffer As ZString * 128
    LbGetClassName(WindowHandle, @ClassBuffer, 128)
    Return ClassBuffer
End Function

' Каретка окна WindowHandle в экранных координатах: левый верхний угол
' (CaretPos) и высота. 0 - каретки нет или окно её не показывает.
Function CaretOfWindow(ByVal WindowHandle As Any Ptr, ByRef CaretPos As LbPoint, _
        ByRef CaretHeight As Long) As Long
    If WindowHandle = 0 Then Return 0
    Dim ThreadInfo As LbGuiThreadInfo
    ThreadInfo.cbSize = SizeOf(LbGuiThreadInfo)
    If LbGetGUIThreadInfo(LbGetWindowThreadProcessId(WindowHandle, 0), ThreadInfo) = 0 Then Return 0
    With ThreadInfo
        CaretDebugText = "каретка: окно " & CaretClassOf(.hwndCaret) & " (" & .rcCaret.RectLeft & "," & .rcCaret.RectTop _
            & " - " & .rcCaret.RectRight & "," & .rcCaret.RectBottom & "), фокус " & CaretClassOf(.hwndFocus) _
            & ", флаги " & Hex(.flags)
    End With
    If ThreadInfo.hwndCaret = 0 Then Return 0
    ' каретка не у окна с фокусом (своя каретка редактора, а системная
    ' осталась у другого элемента) или у скрытого окна - не та
    If ThreadInfo.hwndCaret <> ThreadInfo.hwndFocus AndAlso _
            LbIsChild(ThreadInfo.hwndFocus, ThreadInfo.hwndCaret) = 0 Then Return 0
    If LbIsWindowVisible(ThreadInfo.hwndCaret) = 0 Then Return 0
    ' каретка за пределами окна - её так прячут: редактор unIDE рисует свою
    ' каретку, а системную уводит в (-100, -100)
    Dim ClientRect As LbRect
    If LbGetClientRect(ThreadInfo.hwndCaret, ClientRect) Then
        With ThreadInfo.rcCaret
            If .RectRight <= ClientRect.RectLeft Or .RectLeft >= ClientRect.RectRight Or _
                    .RectBottom <= ClientRect.RectTop Or .RectTop >= ClientRect.RectBottom Then Return 0
        End With
    End If
    ' пустой прямоугольник - показывать нечего
    If ThreadInfo.rcCaret.RectBottom <= ThreadInfo.rcCaret.RectTop Then Return 0
    CaretPos.PosX = ThreadInfo.rcCaret.RectLeft
    CaretPos.PosY = ThreadInfo.rcCaret.RectTop
    CaretHeight = ThreadInfo.rcCaret.RectBottom - ThreadInfo.rcCaret.RectTop
    LbClientToScreen(ThreadInfo.hwndCaret, CaretPos)
    Return 1
End Function
