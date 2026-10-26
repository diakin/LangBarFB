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
' ---------------------------------------------------------------------------

#pragma once

#include once "winapi.bi"
#include once "config.bi"
#include once "layouts.bi"
#include once "hotkeys.bi"
#include once "sendkeys.bi"
#include once "convert.bi"

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

' Break: последнее слово - в следующей раскладке
Private Sub ActionUndoConvert(ByVal TargetWindow As Any Ptr)
    If WordKeyCount = 0 Or TargetWindow <> WordWindow Or LayoutCount < 2 Then Exit Sub
    Dim TrailingSpaces As Long
    Dim WordStart As Long = WordLastStart(TrailingSpaces)
    If WordStart < 0 Then Exit Sub
    Dim WordEnd As Long = WordKeyCount - 1 - TrailingSpaces

    Dim SourceIdx As Long
    If WordCycleActive Then
        SourceIdx = WordCycleLayoutIdx
    Else
        SourceIdx = LayoutIndexOf(LayoutOfWindow(TargetWindow).LayoutHandle)
        If SourceIdx < 0 Then SourceIdx = 0
        WordCycleShownChars = WordKeyCount - WordStart
    End If
    Dim TargetIdx As Long = (SourceIdx + 1) Mod LayoutCount
    Dim TargetHandle As UInteger = LayoutList(TargetIdx).LayoutHandle

    Dim NewChars(0 To WordKeyCount - WordStart - 1) As UShort
    Dim NewCount As Long, KeyIdx As Long
    For KeyIdx = WordStart To WordKeyCount - 1
        Dim KeyChar As UShort
        If KeyIdx > WordEnd Then
            KeyChar = 32
        Else
            With WordKeys(KeyIdx)
                KeyChar = KeyCharInLayout(.VirtualKey, .WithShift, .CapsOn, TargetHandle)
            End With
        End If
        If KeyChar >= 32 Then
            NewChars(NewCount) = KeyChar
            NewCount += 1
        End If
    Next

    SendKeyTap(LB_VK_BACK, WordCycleShownChars)
    SendUnicodeText(NewChars(), NewCount)
    LogAction("Break: слово в " & LayoutList(TargetIdx).LocaleCode & ", раскладка: " _
        & SwitchResultText(LayoutSwitchChecked(TargetWindow, TargetHandle, 50)))
    WordCycleActive = 1
    WordCycleLayoutIdx = TargetIdx
    WordCycleShownChars = NewCount
    PlayEventSound(SOUND_UNDO_AUTOSWITCH)
End Sub

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

    Dim Positions As Long = SendUnicodeText(TextChars(), CharCount)
    If Positions <= RESELECT_MAX_CHARS Then SendKeyWithModifier(LB_VK_SHIFT, LB_VK_LEFT, Positions)
    If NewLayout = 0 Then
        ' регистр: раскладка не меняется
    ElseIf NewLayout = WindowLayout Then
        LogAction("раскладка окна уже " & LayoutCodeOf(NewLayout) & ", менять не нужно")
    Else
        LogAction("раскладка " & LayoutCodeOf(WindowLayout) & " -> " & LayoutCodeOf(NewLayout) & ": " _
            & SwitchResultText(LayoutSwitchChecked(TargetWindow, NewLayout, 50)))
    End If
    WordBufferReset()
    PlayEventSound(SOUND_CONVERT_SELECTION)
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
    If SendWaitModifiersUp(1500) = 0 Then LogAction("модификаторы не отпущены за 1,5 с")
    If ActionIdx = ACTION_UNDO_CONVERT Then
        ActionUndoConvert(TargetWindow)
    Else
        ActionSelection(ActionIdx, TargetWindow)
    End If
    ActionBusy = 0
End Sub
