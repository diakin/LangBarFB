' ---------------------------------------------------------------------------
'  layouts.bi - раскладка активного окна.
'  Этап 0: только чтение через GetKeyboardLayout потока активного окна.
'  У консоли и окон UWP этот способ даёт неверный ответ - их разбор
'  (как в LangBarXX, Lib/LangCode.ahk) переносится на этапе 1.
' ---------------------------------------------------------------------------

#pragma once

#include once "winapi.bi"

Type LayoutInfo
    WindowHandle As Any Ptr
    WindowClass As String
    LayoutHandle As UInteger
    LanguageId As ULong
    LanguageCode As String
End Type

Function LayoutOfForeground() As LayoutInfo
    Dim Result As LayoutInfo
    Result.WindowHandle = LbGetForegroundWindow()
    If Result.WindowHandle = 0 Then Return Result

    Dim ClassBuffer As ZString * 256
    LbGetClassName(Result.WindowHandle, @ClassBuffer, 256)
    Result.WindowClass = ClassBuffer

    Dim ThreadId As ULong = LbGetWindowThreadProcessId(Result.WindowHandle, 0)
    Result.LayoutHandle = Cast(UInteger, LbGetKeyboardLayout(ThreadId))
    Result.LanguageId = Result.LayoutHandle And &hFFFF

    Dim CodeBuffer As ZString * 16
    If LbGetLocaleInfo(Result.LanguageId, LB_LOCALE_SISO639LANGNAME, @CodeBuffer, 16) > 0 Then
        Result.LanguageCode = CodeBuffer
    Else
        Result.LanguageCode = "?"
    End If
    Return Result
End Function
