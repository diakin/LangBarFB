' ---------------------------------------------------------------------------
'  actions.bi - действия горячих клавиш.
'
'  0 Break        - последнее набранное слово заново в следующей раскладке
'                   (повторное нажатие - в следующей по кругу)
'  1 Shift+Break  - выделенный текст в другой раскладке
'  2 Alt+Break    - регистр букв выделенного текста наоборот
'  3 Alt+Scroll   - выделенный текст транслитом (кириллица в латиницу)
'
'  Выделенный текст копируется через Ctrl+C и печатается заново поверх
'  выделения, потом снова выделяется. Повтор того же сочетания сразу
'  после действия возвращает исходный текст, как Rollback у LangBarXX.
'
'  Часть LangBarFB (https://github.com/diakin/LangBarFB), лицензия LGPL-3.0
'  (COPYING.LESSER и COPYING в корне репозитория).
' ---------------------------------------------------------------------------

#pragma once

#include once "winapi.bi"
#include once "config.bi"
#include once "layouts.bi"
#include once "hotkeys.bi"
#include once "sendkeys.bi"
#include once "convert.bi"
#include once "spell.bi"

' выделение не выделяется заново, если оно длиннее (Shift+Left по одному
' символу на длинном тексте идёт заметно долго)
Const RESELECT_MAX_CHARS = 2000

Type ActionLogFn As Sub(ByRef LineText As String)
' запись хода действий в окно отладки (ставит главная программа)
Dim Shared ActionLog As ActionLogFn

Dim Shared ActionBusy As Long
' последнее действие с выделенным текстом - для возврата
Dim Shared LastActionIdx As Long = -1
Dim Shared LastActionWindow As Any Ptr
Dim Shared LastActionLayout As UInteger
Dim Shared LastOriginal() As UShort
Dim Shared LastOriginalCount As Long
Dim Shared LastResult() As UShort
Dim Shared LastResultCount As Long

Private Function SameText(FirstChars() As UShort, ByVal FirstCount As Long, _
        SecondChars() As UShort, ByVal SecondCount As Long) As Long
    If FirstCount <> SecondCount Then Return 0
    Dim CharIdx As Long
    For CharIdx = 0 To FirstCount - 1
        If FirstChars(CharIdx) <> SecondChars(CharIdx) Then Return 0
    Next
    Return 1
End Function

Private Sub CopyText(SourceChars() As UShort, ByVal CharCount As Long, TargetChars() As UShort)
    If CharCount <= 0 Then
        Erase TargetChars
        Exit Sub
    End If
    ReDim TargetChars(0 To CharCount - 1)
    Dim CharIdx As Long
    For CharIdx = 0 To CharCount - 1
        TargetChars(CharIdx) = SourceChars(CharIdx)
    Next
End Sub

' Номер раскладки en-US (или другой английской) для транслита; -1 - нет
Private Function EnglishLayoutIdx() As Long
    Dim LayoutIdx As Long
    For LayoutIdx = 0 To LayoutCount - 1
        If LayoutList(LayoutIdx).LanguageId = &h0409 Then Return LayoutIdx
    Next
    For LayoutIdx = 0 To LayoutCount - 1
        If (LayoutList(LayoutIdx).LanguageId And &hFF) = &h09 Then Return LayoutIdx
    Next
    Return -1
End Function

' Смена раскладки с проверкой. Запрос уходит через DelayMillis (окно
' успевает разобрать посланные или отпущенные клавиши) элементу с
' фокусом; если за 300 мс раскладка окна не сменилась - самому окну,
' как SetInputLayout у LangBarXX. Возвращает 1 - сменилась после первого
' запроса, 2 - после второго, 0 - не сменилась.
Private Function WaitWindowLayout(ByVal TargetWindow As Any Ptr, ByVal LayoutHandle As UInteger) As Long
    Dim TryIdx As Long
    For TryIdx = 1 To 6
        If LayoutOfWindow(TargetWindow).LayoutHandle = LayoutHandle Then Return 1
        SendWaitPump(50)
    Next
    Return IIf(LayoutOfWindow(TargetWindow).LayoutHandle = LayoutHandle, 1, 0)
End Function

Function LayoutSwitchChecked(ByVal TargetWindow As Any Ptr, ByVal LayoutHandle As UInteger, _
        ByVal DelayMillis As Long) As Long
    If TargetWindow = 0 Or LayoutHandle = 0 Then Return 0
    If DelayMillis > 0 Then SendWaitPump(DelayMillis)
    LayoutRequest(TargetWindow, LayoutHandle)
    If WaitWindowLayout(TargetWindow, LayoutHandle) Then Return 1
    LbPostMessage(TargetWindow, LB_WM_INPUTLANGCHANGEREQUEST, 0, Cast(Integer, LayoutHandle))
    If WaitWindowLayout(TargetWindow, LayoutHandle) Then Return 2
    Return 0
End Function

Private Sub LogAction(ByRef LineText As String)
    If ActionLog <> 0 Then ActionLog(LineText)
End Sub

Private Function LayoutCodeOf(ByVal LayoutHandle As UInteger) As String
    Dim LayoutIdx As Long = LayoutIndexOf(LayoutHandle)
    If LayoutIdx < 0 Then Return Hex(LayoutHandle)
    Return LayoutList(LayoutIdx).LocaleCode
End Function

Private Function SwitchResultText(ByVal SwitchResult As Long) As String
    Select Case SwitchResult
    Case 1
        Return "сменилась"
    Case 2
        Return "сменилась со второго запроса (окну)"
    End Select
    Return "НЕ сменилась"
End Function

' Действия с выделенным текстом
Private Sub ActionSelection(ByVal ActionIdx As Long, ByVal TargetWindow As Any Ptr)
    Dim TextChars() As UShort
    Dim CharCount As Long = CopySelectionText(TextChars())
    If CharCount = 0 Then
        LogAction("действие " & (ActionIdx + 1) & ": выделенный текст не скопировался (Ctrl+C не изменил буфер обмена)")
        Exit Sub
    End If

    Dim OriginalChars() As UShort
    CopyText(TextChars(), CharCount, OriginalChars())
    Dim OriginalCount As Long = CharCount
    Dim WindowLayout As UInteger = LayoutOfWindow(TargetWindow).LayoutHandle
    Dim NewLayout As UInteger

    If ActionIdx = LastActionIdx And TargetWindow = LastActionWindow AndAlso _
            SameText(TextChars(), CharCount, LastResult(), LastResultCount) Then
        ' то же сочетание по только что изменённому тексту - вернуть исходный
        CopyText(LastOriginal(), LastOriginalCount, TextChars())
        CharCount = LastOriginalCount
        NewLayout = LastActionLayout
        LastActionIdx = -1
    Else
        Select Case ActionIdx
        Case ACTION_CONVERT_SELECTION
            If LayoutCount < 2 Then Exit Sub
            Dim SourceIdx As Long = ConvertSourceLayout(TextChars(), CharCount, LayoutIndexOf(WindowLayout))
            Dim TargetIdx As Long = (SourceIdx + 1) Mod LayoutCount
            ConvertLayoutText(TextChars(), CharCount, SourceIdx, TargetIdx)
            NewLayout = LayoutList(TargetIdx).LayoutHandle
            LogAction("раскладка выделенного: " & CharCount & " симв., текст набран в " _
                & LayoutList(SourceIdx).LocaleCode & ", перевод в " & LayoutList(TargetIdx).LocaleCode)
        Case ACTION_TOGGLE_CASE
            InvertTextCase(TextChars(), CharCount)
        Case ACTION_TRANSLIT
            CharCount = TranslitText(TextChars(), CharCount)
            Dim EnglishIdx As Long = EnglishLayoutIdx()
            If EnglishIdx >= 0 Then NewLayout = LayoutList(EnglishIdx).LayoutHandle
        End Select
        LastActionIdx = ActionIdx
        LastActionWindow = TargetWindow
        LastActionLayout = WindowLayout
        CopyText(OriginalChars(), OriginalCount, LastOriginal())
        LastOriginalCount = OriginalCount
        CopyText(TextChars(), CharCount, LastResult())
        LastResultCount = CharCount
    End If

    ' раскладка - до печати: окна без Unicode переводят символ в кодировку
    ' текущей раскладки
    If NewLayout = 0 Then
        ' регистр: раскладка не меняется
    ElseIf NewLayout = WindowLayout Then
        LogAction("раскладка окна уже " & LayoutCodeOf(NewLayout) & ", менять не нужно")
    Else
        LogAction("раскладка " & LayoutCodeOf(WindowLayout) & " -> " & LayoutCodeOf(NewLayout) & ": " _
            & SwitchResultText(LayoutSwitchChecked(TargetWindow, NewLayout, 50)))
    End If
    Dim Positions As Long = SendUnicodeText(TextChars(), CharCount)
    If Positions <= RESELECT_MAX_CHARS Then SendKeyWithModifier(LB_VK_SHIFT, LB_VK_LEFT, Positions)
    WordBufferReset()
    PlayEventSound(SOUND_CONVERT_SELECTION)
End Sub

' Break: последнее слово - в следующей раскладке. Повторное нажатие сразу
' после этого - то же слово в следующей раскладке по кругу. Целое
' предложение исправляют выделением и Shift+Break. Сразу после
' автопереключения Break возвращает слово в прежнюю раскладку и
' запоминает его, чтобы больше не переключать.
Private Sub ActionUndoConvert(ByVal TargetWindow As Any Ptr)
    If LayoutCount < 2 Then Exit Sub
    Dim RangeStart As Long, SourceIdx As Long
    Dim UndoAutoSwitch As Long
    If WordCycleActive And TargetWindow = WordWindow Then
        RangeStart = WordCycleStart
        SourceIdx = WordCycleLayoutIdx
        UndoAutoSwitch = IIf(WordCycleUndoIdx >= 0 And WordCycleUndoIdx < LayoutCount, 1, 0)
    Else
        WordCycleActive = 0
        If WordKeyCount > 0 And TargetWindow = WordWindow Then RangeStart = WordStartBefore(WordKeyCount) Else RangeStart = -1
        If RangeStart < 0 Then
            ' набранного слова нет - исправляется выделенный текст
            LogAction("Break: набранного слова нет - выделенный текст")
            ActionSelection(ACTION_CONVERT_SELECTION, TargetWindow)
            Exit Sub
        End If
        SourceIdx = LayoutIndexOf(LayoutOfWindow(TargetWindow).LayoutHandle)
        If SourceIdx < 0 Then SourceIdx = 0
        WordCycleShownChars = WordKeyCount - RangeStart
    End If
    Dim TargetIdx As Long = (SourceIdx + 1) Mod LayoutCount
    If UndoAutoSwitch Then TargetIdx = WordCycleUndoIdx
    WordCycleUndoIdx = -1
    Dim TargetHandle As UInteger = LayoutList(TargetIdx).LayoutHandle

    Dim NewChars(0 To WordKeyCount - RangeStart - 1) As UShort
    Dim NewCount As Long, KeyIdx As Long
    For KeyIdx = RangeStart To WordKeyCount - 1
        Dim KeyChar As UShort
        With WordKeys(KeyIdx)
            KeyChar = KeyCharInLayout(.VirtualKey, .WithShift, .CapsOn, TargetHandle)
        End With
        If KeyChar >= 32 Then
            NewChars(NewCount) = KeyChar
            NewCount += 1
        End If
    Next

    ' клавиши - до ожидания смены раскладки: пока ждём, буфер может измениться
    Dim VirtualKeys() As UShort, ShiftFlags() As Long
    Dim KeyCount As Long = WordKeysFor(RangeStart, WordKeyCount - 1, TargetHandle, VirtualKeys(), ShiftFlags())
    SendKeyTap(LB_VK_BACK, WordCycleShownChars)
    ' раскладка меняется до набора, и слово набирается нажатиями клавиш:
    ' окна без Unicode переводят символ в кодировку текущей раскладки, и
    ' русский текст при английской раскладке становится «?????» (LangBarXX
    ' делает так же: SetInputLayout, потом SendText по клавишам)
    Dim SwitchResult As Long = LayoutSwitchChecked(TargetWindow, TargetHandle, 50)
    If SwitchResult Then
        SendKeysWithShift(VirtualKeys(), ShiftFlags(), KeyCount)
    Else
        SendUnicodeText(NewChars(), NewCount)
    End If
    LogAction("Break: " & NewCount & " симв. в " & LayoutList(TargetIdx).LocaleCode & ", раскладка: " _
        & SwitchResultText(SwitchResult))
    WordCycleActive = 1
    WordCycleStart = RangeStart
    WordCycleLayoutIdx = TargetIdx
    WordCycleShownChars = NewCount
    If UndoAutoSwitch Then
        Dim CoreStart As Long, CoreLength As Long
        If SpellCoreRange(NewChars(), NewCount, CoreStart, CoreLength) > 0 Then
            SpellRemember(TargetIdx, NewChars(), CoreStart, CoreLength, Settings.AutoRemember)
            LogAction("автопереключение отменено, слово «" & SpellAnsiOf(NewChars(), CoreStart, CoreLength) _
                & "» больше не переключается" & IIf(Settings.AutoRemember, " (записано в user_dict.dic)", ""))
        End If
    End If
    PlayEventSound(SOUND_UNDO_AUTOSWITCH)
End Sub

' Сообщение от хука: сработало сочетание ActionIdx
Sub RunHotkeyAction(ByVal ActionIdx As Long)
    If ActionBusy Then Exit Sub
    ActionBusy = 1
    Dim TargetWindow As Any Ptr = LbGetForegroundWindow()
    ' после Alt или Win, нажатых без другой клавиши, окно открыло бы
    ' своё меню или меню «Пуск» - лишнее нажатие это отменяет
    If (HotkeyTable(ActionIdx).Modifiers And (KB_MOD_ALT Or KB_MOD_WIN)) <> 0 Then
        SendKeyTap(LB_VK_MENU_MASK)
    End If
    ' Shift и т. п. ещё держат (сочетание нажимают несколько раз подряд) -
    ' для Windows они отпускаются, иначе сложатся с Ctrl+C и текстом
    If SendWaitModifiersUp(150) = 0 Then
        LogAction("модификаторы держат - отпускаются программно")
        SendReleaseModifiers()
        SendWaitPump(20)
    End If
    If ActionIdx = ACTION_UNDO_CONVERT Then
        ActionUndoConvert(TargetWindow)
    Else
        ActionSelection(ActionIdx, TargetWindow)
    End If
    ActionBusy = 0
End Sub
