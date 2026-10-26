' ---------------------------------------------------------------------------
'  sendkeys.bi - ввод в чужое окно (SendInput) и буфер обмена.
'
'  Текст хранится как массив UTF-16 (UShort): так его отдаёт буфер обмена
'  и так его принимает SendInput с KEYEVENTF_UNICODE, а строки FreeBASIC
'  и RqLcl - в CP1251.
'
'  Пока программа ждёт (буфер обмена, отпускание клавиш), она разбирает
'  свои сообщения (SendWaitPump): иначе вызовы хука встанут в очередь, и
'  Windows после таймаута снимет хук.
'
'  Часть LangBarFB (https://github.com/diakin/LangBarFB), лицензия LGPL-3.0
'  (COPYING.LESSER и COPYING в корне репозитория).
' ---------------------------------------------------------------------------

#pragma once

#include once "winapi.bi"
#include once "kbhook.bi"
#include once "rqlcl.bi"

' Ждёт MaxMillis, разбирая сообщения программы
Sub SendWaitPump(ByVal MaxMillis As Long)
    Dim StartTime As Double = Timer
    Do
        DoEvents
        If (Timer - StartTime) * 1000 >= MaxMillis Then Exit Do
        LbMsgWaitForMultipleObjects(0, 0, 0, 10, LB_QS_ALLINPUT)
    Loop
End Sub

Private Sub SendFillKey(ByRef KeyInput As LbKeybdInput, ByVal VirtualKey As UShort, _
        ByVal ScanCode As UShort, ByVal Flags As ULong)
    KeyInput.InputType = LB_INPUT_KEYBOARD
    KeyInput.wVk = VirtualKey
    KeyInput.wScan = ScanCode
    KeyInput.dwFlags = Flags
End Sub

' Нажатие и отпускание клавиши, Repeats раз подряд
Sub SendKeyTap(ByVal VirtualKey As UShort, ByVal Repeats As Long = 1)
    If Repeats <= 0 Then Exit Sub
    Dim KeyInputs(0 To Repeats * 2 - 1) As LbKeybdInput
    Dim TapIdx As Long
    For TapIdx = 0 To Repeats - 1
        SendFillKey(KeyInputs(TapIdx * 2), VirtualKey, 0, 0)
        SendFillKey(KeyInputs(TapIdx * 2 + 1), VirtualKey, 0, LB_KEYEVENTF_KEYUP)
    Next
    LbSendInput(Repeats * 2, @KeyInputs(0), SizeOf(LbKeybdInput))
End Sub

' Клавиша с удержанием модификатора: Ctrl+C, Shift+Left и т. п.
Sub SendKeyWithModifier(ByVal ModifierKey As UShort, ByVal VirtualKey As UShort, ByVal Repeats As Long = 1)
    If Repeats <= 0 Then Exit Sub
    Dim KeyInputs(0 To Repeats * 2 + 1) As LbKeybdInput
    SendFillKey(KeyInputs(0), ModifierKey, 0, 0)
    Dim TapIdx As Long
    For TapIdx = 0 To Repeats - 1
        SendFillKey(KeyInputs(1 + TapIdx * 2), VirtualKey, 0, 0)
        SendFillKey(KeyInputs(2 + TapIdx * 2), VirtualKey, 0, LB_KEYEVENTF_KEYUP)
    Next
    SendFillKey(KeyInputs(Repeats * 2 + 1), ModifierKey, 0, LB_KEYEVENTF_KEYUP)
    LbSendInput(Repeats * 2 + 2, @KeyInputs(0), SizeOf(LbKeybdInput))
End Sub

' Нажатия клавиш VirtualKeys, где ShiftFlags <> 0 - с Shift. Так печатает
' пользователь: символ даёт раскладка окна, и окна без Unicode (ANSI,
' например программы Delphi 7) получают его в своей кодировке.
Sub SendKeysWithShift(VirtualKeys() As UShort, ShiftFlags() As Long, ByVal KeyCount As Long)
    If KeyCount <= 0 Then Exit Sub
    Dim KeyInputs(0 To KeyCount * 4 - 1) As LbKeybdInput
    Dim InputCount As Long, KeyIdx As Long
    For KeyIdx = 0 To KeyCount - 1
        If ShiftFlags(KeyIdx) Then
            SendFillKey(KeyInputs(InputCount), LB_VK_SHIFT, 0, 0)
            InputCount += 1
        End If
        SendFillKey(KeyInputs(InputCount), VirtualKeys(KeyIdx), 0, 0)
        SendFillKey(KeyInputs(InputCount + 1), VirtualKeys(KeyIdx), 0, LB_KEYEVENTF_KEYUP)
        InputCount += 2
        If ShiftFlags(KeyIdx) Then
            SendFillKey(KeyInputs(InputCount), LB_VK_SHIFT, 0, LB_KEYEVENTF_KEYUP)
            InputCount += 1
        End If
    Next
    LbSendInput(InputCount, @KeyInputs(0), SizeOf(LbKeybdInput))
End Sub

' Печатает текст: символы - KEYEVENTF_UNICODE (не зависят от раскладки),
' перевод строки - Enter (CR LF и одиночный LF - один Enter).
' Возвращает, на сколько позиций курсора текст занял место.
Function SendUnicodeText(TextChars() As UShort, ByVal CharCount As Long) As Long
    If CharCount <= 0 Then Return 0
    Dim KeyInputs(0 To CharCount * 2 - 1) As LbKeybdInput
    Dim InputCount As Long, Positions As Long
    Dim CharIdx As Long
    For CharIdx = 0 To CharCount - 1
        Dim CharCode As UShort = TextChars(CharIdx)
        If CharCode = 10 And CharIdx > 0 Then
            If TextChars(CharIdx - 1) = 13 Then Continue For
        End If
        If CharCode = 13 Or CharCode = 10 Then
            SendFillKey(KeyInputs(InputCount), LB_VK_RETURN, 0, 0)
            SendFillKey(KeyInputs(InputCount + 1), LB_VK_RETURN, 0, LB_KEYEVENTF_KEYUP)
        Else
            SendFillKey(KeyInputs(InputCount), 0, CharCode, LB_KEYEVENTF_UNICODE)
            SendFillKey(KeyInputs(InputCount + 1), 0, CharCode, LB_KEYEVENTF_UNICODE Or LB_KEYEVENTF_KEYUP)
        End If
        InputCount += 2
        Positions += 1
    Next
    LbSendInput(InputCount, @KeyInputs(0), SizeOf(LbKeybdInput))
    Return Positions
End Function

' Отпускает для Windows модификаторы, которые пользователь ещё держит
' (Shift+Break, нажатый несколько раз подряд): иначе Ctrl+C ушёл бы как
' Ctrl+Shift+C. Хук продолжает считать их нажатыми (KbReleasedByUs).
Sub SendReleaseModifiers()
    Dim KeyInputs(0 To 7) As LbKeybdInput
    Dim InputCount As Long, BitIdx As Long
    For BitIdx = 0 To 7
        Dim KeyBit As ULong = 1 Shl BitIdx
        If (KbHeldMask And KeyBit) <> 0 And (KbReleasedByUs And KeyBit) = 0 Then
            Dim VirtualKey As Long = KbHeldBitKey(BitIdx)
            Dim Flags As ULong = LB_KEYEVENTF_KEYUP
            ' правые Ctrl и Alt, Win - расширенные клавиши
            If VirtualKey = &hA3 Or VirtualKey = &hA5 Or BitIdx >= 6 Then Flags Or= 1
            SendFillKey(KeyInputs(InputCount), VirtualKey, 0, Flags)
            InputCount += 1
            KbReleasedByUs Or= KeyBit
        End If
    Next
    If InputCount > 0 Then LbSendInput(InputCount, @KeyInputs(0), SizeOf(LbKeybdInput))
End Sub

' Ждёт, пока пользователь отпустит Ctrl, Alt, Shift, Win (иначе они
' сложатся с тем, что посылает программа). 0 - не дождались за MaxMillis.
Function SendWaitModifiersUp(ByVal MaxMillis As Long) As Long
    Dim StartTime As Double = Timer
    Do
        If KbCurrentModifiers() = 0 Then Return 1
        If (Timer - StartTime) * 1000 >= MaxMillis Then Return 0
        SendWaitPump(15)
    Loop
End Function

' --- буфер обмена ---

' Текст из буфера обмена; -1 - текста там нет
Function ClipboardReadText(TextChars() As UShort) As Long
    Dim CharCount As Long = -1
    If LbOpenClipboard(0) = 0 Then Return -1
    Dim MemHandle As Any Ptr = LbGetClipboardData(LB_CF_UNICODETEXT)
    If MemHandle <> 0 Then
        Dim TextPtr As UShort Ptr = LbGlobalLock(MemHandle)
        If TextPtr <> 0 Then
            Dim MaxChars As Long = CLng(LbGlobalSize(MemHandle) \ 2)
            CharCount = 0
            While CharCount < MaxChars AndAlso TextPtr[CharCount] <> 0
                CharCount += 1
            Wend
            If CharCount > 0 Then
                ReDim TextChars(0 To CharCount - 1)
                Dim CharIdx As Long
                For CharIdx = 0 To CharCount - 1
                    TextChars(CharIdx) = TextPtr[CharIdx]
                Next
            End If
            LbGlobalUnlock(MemHandle)
        End If
    End If
    LbCloseClipboard()
    Return CharCount
End Function

' Кладёт текст в буфер обмена (CharCount -1 - очистить буфер)
Sub ClipboardWriteText(TextChars() As UShort, ByVal CharCount As Long)
    ' буфер может держать другая программа - несколько попыток
    Dim TryIdx As Long
    For TryIdx = 1 To 10
        If LbOpenClipboard(0) Then Exit For
        SendWaitPump(20)
    Next
    If TryIdx > 10 Then Exit Sub
    LbEmptyClipboard()
    If CharCount >= 0 Then
        Dim MemHandle As Any Ptr = LbGlobalAlloc(LB_GMEM_MOVEABLE, (CharCount + 1) * 2)
        If MemHandle <> 0 Then
            Dim TextPtr As UShort Ptr = LbGlobalLock(MemHandle)
            Dim CharIdx As Long
            For CharIdx = 0 To CharCount - 1
                TextPtr[CharIdx] = TextChars(CharIdx)
            Next
            TextPtr[CharCount] = 0
            LbGlobalUnlock(MemHandle)
            ' после SetClipboardData памятью владеет Windows
            If LbSetClipboardData(LB_CF_UNICODETEXT, MemHandle) = 0 Then LbGlobalFree(MemHandle)
        End If
    End If
    LbCloseClipboard()
End Sub

' Копирует выделенный текст активного окна (Ctrl+C) и возвращает прежний
' текст в буфер обмена. Возвращает число символов; 0 - ничего не
' выделено или окно не копирует. Буфер обмена восстанавливается только
' текстом: картинка или файлы, лежавшие там, пропадут.
Function CopySelectionText(TextChars() As UShort) As Long
    Dim SavedChars() As UShort
    Dim SavedCount As Long = ClipboardReadText(SavedChars())
    Dim StartSequence As ULong = LbGetClipboardSequenceNumber()
    SendKeyWithModifier(LB_VK_CONTROL, Asc("C"))

    Dim StartTime As Double = Timer
    Dim Copied As Long
    Do
        SendWaitPump(10)
        If LbGetClipboardSequenceNumber() <> StartSequence Then
            Copied = 1
            Exit Do
        End If
    Loop While (Timer - StartTime) < 0.5
    If Copied = 0 Then Return 0
    ' окно может положить в буфер несколько форматов подряд
    SendWaitPump(30)
    Dim CharCount As Long = ClipboardReadText(TextChars())
    If SavedCount >= 0 Then
        ClipboardWriteText(SavedChars(), SavedCount)
    End If
    Return IIf(CharCount > 0, CharCount, 0)
End Function
