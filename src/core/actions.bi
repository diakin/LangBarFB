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
    LayoutRequest(TargetWindow, TargetHandle)
    WordCycleActive = 1
    WordCycleLayoutIdx = TargetIdx
    WordCycleShownChars = NewCount
    PlayEventSound(SOUND_UNDO_AUTOSWITCH)
End Sub

' Действия с выделенным текстом
Private Sub ActionSelection(ByVal ActionIdx As Long, ByVal TargetWindow As Any Ptr)
    Dim TextChars() As UShort
    Dim CharCount As Long = CopySelectionText(TextChars())
    If CharCount = 0 Then Exit Sub

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
    If NewLayout <> 0 And NewLayout <> WindowLayout Then LayoutRequest(TargetWindow, NewLayout)
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
    SendWaitModifiersUp(1500)
    If ActionIdx = ACTION_UNDO_CONVERT Then
        ActionUndoConvert(TargetWindow)
    Else
        ActionSelection(ActionIdx, TargetWindow)
    End If
    ActionBusy = 0
End Sub
