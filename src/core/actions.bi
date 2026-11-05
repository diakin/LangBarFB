' ---------------------------------------------------------------------------
'  actions.bi - действия горячих клавиш.
'
'  0 Break        - последнее набранное слово заново в следующей раскладке
'                   (повторное нажатие - в следующей по кругу)
'  1 Shift+Break  - выделенный текст в другой раскладке
'  2 Alt+Break    - регистр букв выделенного текста наоборот
'  3 Alt+Scroll   - выделенный текст транслитом (кириллица в латиницу)
'  4 Ctrl+Break   - опечатка в последнем слове исправляется вариантом
'                   Hunspell; повтор - следующий вариант, после последнего
'                   - снова исходное слово
'  5 Ctrl+Scroll  - последнее набранное слово (или слова выделенного
'                   текста) - в словари и в user_dict.dic: больше не
'                   переключаются и не исправляются
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
#include once "rules.bi"

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

' исправление опечатки: варианты, какой сейчас в окне (-1 - исходное
' слово), сколько символов он занимает вместе с пробелами после слова
Dim Shared FixActive As Long
Dim Shared FixWindow As Any Ptr
Dim Shared FixSerial As Long
Dim Shared FixOriginal() As UShort
Dim Shared FixOriginalCount As Long
Dim Shared FixCoreStart As Long
Dim Shared FixCoreLength As Long
Dim Shared FixTrailing As Long
Dim Shared FixChars() As UShort
Dim Shared FixStarts() As Long
Dim Shared FixLengths() As Long
Dim Shared FixCount As Long
Dim Shared FixShownIdx As Long
Dim Shared FixShownChars As Long
Dim Shared FixLayoutIdx As Long
' 1 - исправление сделало автоисправление после пробела (Break его отменяет)
Dim Shared FixAuto As Long

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
        Dim KeyChar As UShort = WordKeyChar(KeyIdx, TargetHandle)
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
            RuleNoteUndo(SpellAnsiOf(NewChars(), CoreStart, CoreLength))
            LogAction("автопереключение отменено, слово «" & SpellAnsiOf(NewChars(), CoreStart, CoreLength) _
                & "» больше не переключается" & IIf(Settings.AutoRemember, " (записано в user_dict.dic)", ""))
        End If
    End If
    PlayEventSound(SOUND_UNDO_AUTOSWITCH)
End Sub

' Текст в окне для варианта FixShownIdx: начало слова до букв, вариант
' (или исходные буквы), конец слова после букв, пробелы
Private Function FixBuildText(TextChars() As UShort) As Long
    Dim CoreFrom As Long, CoreLength As Long
    If FixShownIdx < 0 Then
        CoreLength = FixCoreLength
    Else
        CoreFrom = FixStarts(FixShownIdx)
        CoreLength = FixLengths(FixShownIdx)
    End If
    Dim TotalCount As Long = FixOriginalCount - FixCoreLength + CoreLength + FixTrailing
    ReDim TextChars(0 To TotalCount)
    Dim CharIdx As Long, OutIdx As Long
    For CharIdx = 0 To FixCoreStart - 1
        TextChars(OutIdx) = FixOriginal(CharIdx) : OutIdx += 1
    Next
    For CharIdx = 0 To CoreLength - 1
        If FixShownIdx < 0 Then
            TextChars(OutIdx) = FixOriginal(FixCoreStart + CharIdx)
        Else
            TextChars(OutIdx) = FixChars(CoreFrom + CharIdx)
        End If
        OutIdx += 1
    Next
    For CharIdx = FixCoreStart + FixCoreLength To FixOriginalCount - 1
        TextChars(OutIdx) = FixOriginal(CharIdx) : OutIdx += 1
    Next
    For CharIdx = 1 To FixTrailing
        TextChars(OutIdx) = 32 : OutIdx += 1
    Next
    Return OutIdx
End Function

' Готовит исправление слова из буфера RangeStart..(конец без TrailingSpaces):
' слово - как его набрали, словарь - раскладки набора. Возвращает 1, если
' слова нет в словаре и варианты есть; WithLog - писать в окно отладки,
' почему не вышло
Function FixPrepare(ByVal TargetWindow As Any Ptr, ByVal RangeStart As Long, ByVal TrailingSpaces As Long, _
        ByVal WithLog As Long) As Long
    FixActive = 0
    If HunspellSuggest = 0 Then
        If WithLog Then LogAction("опечатка: словари не загружены или в библиотеке нет HunspellSuggest")
        Return 0
    End If
    Dim WordEnd As Long = WordKeyCount - TrailingSpaces - 1
    If RangeStart < 0 Or WordEnd < RangeStart Then Return 0
    Dim TypedLayout As UInteger = WordKeys(RangeStart).LayoutHandle
    FixOriginalCount = 0
    ReDim FixOriginal(0 To WordEnd - RangeStart)
    Dim KeyIdx As Long
    For KeyIdx = RangeStart To WordEnd
        With WordKeys(KeyIdx)
            Dim KeyChar As UShort = KeyCharInLayout(.VirtualKey, .WithShift, .CapsOn, .LayoutHandle)
            If KeyChar >= 32 Then
                FixOriginal(FixOriginalCount) = KeyChar
                FixOriginalCount += 1
            End If
        End With
    Next
    If SpellCoreRange(FixOriginal(), FixOriginalCount, FixCoreStart, FixCoreLength) = 0 Then
        If WithLog Then LogAction("опечатка: в слове нет букв")
        Return 0
    End If
    Dim WordText As String = SpellAnsiOf(FixOriginal(), FixCoreStart, FixCoreLength)
    Dim LayoutIdx As Long = LayoutIndexOf(TypedLayout)
    If LayoutIdx < 0 OrElse SpellDict(LayoutIdx) = 0 Then
        If WithLog Then LogAction("опечатка: нет словаря для раскладки " & LayoutCodeOf(TypedLayout))
        Return 0
    End If
    If SpellCheck(LayoutIdx, FixOriginal(), FixCoreStart, FixCoreLength) Then
        If WithLog Then LogAction("опечатка: «" & WordText & "» есть в словаре " & LayoutCodeOf(TypedLayout))
        Return 0
    End If
    FixCount = SpellSuggest(LayoutIdx, FixOriginal(), FixCoreStart, FixCoreLength, FixChars(), FixStarts(), FixLengths())
    If FixCount = 0 Then
        LogAction("опечатка: для «" & WordText & "» вариантов нет")
        Return 0
    End If
    FixLayoutIdx = LayoutIdx
    FixTrailing = TrailingSpaces
    FixWindow = TargetWindow
    FixShownIdx = -1
    FixShownChars = FixOriginalCount + FixTrailing
    FixAuto = 0
    FixActive = 1
    ' буфер больше не совпадает с текстом в окне: Break и
    ' автопереключение для этого слова не работают
    WordBufferReset()
    Return 1
End Function

' Показать в окне вариант ShowIdx (-1 - исходное слово)
Sub FixShow(ByVal ShowIdx As Long)
    FixShownIdx = ShowIdx
    Dim NewChars() As UShort
    Dim NewCount As Long = FixBuildText(NewChars())
    SendKeyTap(LB_VK_BACK, FixShownChars)
    SendUnicodeText(NewChars(), NewCount)
    FixShownChars = NewCount
    FixSerial = WordChangeSerial
    If FixShownIdx < 0 Then
        LogAction("опечатка: возвращено исходное слово")
    Else
        LogAction("опечатка: «" & SpellAnsiOf(FixOriginal(), FixCoreStart, FixCoreLength) & "» - вариант " _
            & (FixShownIdx + 1) & " из " & FixCount & ": «" _
            & SpellAnsiOf(FixChars(), FixStarts(FixShownIdx), FixLengths(FixShownIdx)) & "»")
    End If
End Sub

' Исправление ещё на экране и после него ничего не набирали
Function FixStillShown(ByVal TargetWindow As Any Ptr) As Long
    Return IIf(FixActive <> 0 And TargetWindow = FixWindow And FixSerial = WordChangeSerial, 1, 0)
End Function

' Опечатка в последнем набранном слове: первое нажатие - первый вариант
' Hunspell по словарю раскладки, в которой слово набрано; повтор сразу
' после - следующий вариант, после последнего - исходное слово
Private Sub ActionSpellFix(ByVal TargetWindow As Any Ptr)
    If FixStillShown(TargetWindow) = 0 Then
        Dim TrailingSpaces As Long
        Dim RangeStart As Long = -1
        If WordKeyCount > 0 And TargetWindow = WordWindow Then RangeStart = WordLastStart(TrailingSpaces)
        If RangeStart < 0 Then
            FixActive = 0
            LogAction("опечатка: набранного слова нет")
            Exit Sub
        End If
        If FixPrepare(TargetWindow, RangeStart, TrailingSpaces, 1) = 0 Then Exit Sub
    End If
    Dim NextIdx As Long = FixShownIdx + 1
    If NextIdx >= FixCount Then NextIdx = -1
    FixShow(NextIdx)
End Sub

' Break сразу после автоисправления: исходное слово обратно, и оно
' запоминается, как слово, автопереключение которого отменили
Private Sub FixUndoAuto()
    FixShow(-1)
    FixActive = 0
    SpellRemember(FixLayoutIdx, FixOriginal(), FixCoreStart, FixCoreLength, Settings.AutoRemember)
    LogAction("автоисправление отменено, слово «" & SpellAnsiOf(FixOriginal(), FixCoreStart, FixCoreLength) _
        & "» больше не исправляется" & IIf(Settings.AutoRemember, " (записано в user_dict.dic)", ""))
    PlayEventSound(SOUND_UNDO_AUTOSWITCH)
End Sub

' Слова текста TextChars - в словари (без знаков по краям); слова из
' одной буквы пропускаются. Возвращает число добавленных.
Const ADD_WORD_MAX_WORDS = 10

Private Function AddWordsOf(TextChars() As UShort, ByVal CharCount As Long) As Long
    Dim AddedCount As Long, SeenCount As Long
    Dim TokenStart As Long = 0, CharIdx As Long
    For CharIdx = 0 To CharCount
        Dim IsBreak As Long = 1
        If CharIdx < CharCount Then
            If TextChars(CharIdx) > 32 Then IsBreak = 0
        End If
        If IsBreak Then
            If CharIdx > TokenStart Then
                SeenCount += 1
                Dim TokenChars(0 To CharIdx - TokenStart - 1) As UShort
                Dim CopyIdx As Long
                For CopyIdx = TokenStart To CharIdx - 1
                    TokenChars(CopyIdx - TokenStart) = TextChars(CopyIdx)
                Next
                Dim CoreStart As Long, CoreLength As Long
                If SpellCoreRange(TokenChars(), CharIdx - TokenStart, CoreStart, CoreLength) >= 2 Then
                    Dim WordText As String = SpellAnsiOf(TokenChars(), CoreStart, CoreLength)
                    If SpellRememberAll(TokenChars(), CoreStart, CoreLength) Then
                        AddedCount += 1
                        LogAction("словарь: «" & WordText & "» добавлено (user_dict.dic)")
                    Else
                        LogAction("словарь: «" & WordText & "» уже есть или словарей нет")
                    End If
                End If
            End If
            TokenStart = CharIdx + 1
        End If
    Next
    Return AddedCount
End Function

' Последнее набранное слово, а если его нет - выделенный текст (не больше
' ADD_WORD_MAX_WORDS слов: Ctrl+C без выделения в некоторых редакторах
' копирует всю строку)
Private Sub ActionAddWord(ByVal TargetWindow As Any Ptr)
    Dim TextChars() As UShort
    Dim CharCount As Long
    Dim TrailingSpaces As Long
    Dim RangeStart As Long = -1
    If WordKeyCount > 0 And TargetWindow = WordWindow Then RangeStart = WordLastStart(TrailingSpaces)
    If RangeStart >= 0 Then
        Dim WordEnd As Long = WordKeyCount - TrailingSpaces - 1
        ReDim TextChars(0 To WordEnd - RangeStart)
        Dim KeyIdx As Long
        For KeyIdx = RangeStart To WordEnd
            With WordKeys(KeyIdx)
                Dim KeyChar As UShort = KeyCharInLayout(.VirtualKey, .WithShift, .CapsOn, .LayoutHandle)
                If KeyChar >= 32 Then
                    TextChars(CharCount) = KeyChar
                    CharCount += 1
                End If
            End With
        Next
    Else
        CharCount = CopySelectionText(TextChars())
        If CharCount <= 0 Then
            LogAction("словарь: нет ни набранного слова, ни выделения")
            Exit Sub
        End If
        Dim WordCount As Long, CharIdx As Long, InWord As Long
        For CharIdx = 0 To CharCount - 1
            If TextChars(CharIdx) > 32 Then
                If InWord = 0 Then WordCount += 1
                InWord = 1
            Else
                InWord = 0
            End If
        Next
        If WordCount > ADD_WORD_MAX_WORDS Then
            LogAction("словарь: выделено " & WordCount & " слов, больше " & ADD_WORD_MAX_WORDS & " - не добавляется")
            Exit Sub
        End If
    End If
    If AddWordsOf(TextChars(), CharCount) > 0 Then PlayEventSound(SOUND_CONVERT_SELECTION)
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
    If ActionIdx = ACTION_UNDO_CONVERT And FixAuto <> 0 And FixStillShown(TargetWindow) <> 0 Then
        FixUndoAuto()
    ElseIf ActionIdx = ACTION_UNDO_CONVERT Then
        ActionUndoConvert(TargetWindow)
    ElseIf ActionIdx = ACTION_SPELL_FIX Then
        ActionSpellFix(TargetWindow)
    ElseIf ActionIdx = ACTION_ADD_WORD Then
        ActionAddWord(TargetWindow)
    Else
        ActionSelection(ActionIdx, TargetWindow)
    End If
    ActionBusy = 0
    ' отмен автопереключения подряд набралось - предложить правило
    If RuleOfferText <> "" Then
        Dim OfferedText As String = RuleOfferText
        If RuleOfferRun() Then LogAction("добавлено правило: «" & OfferedText & "», слово целиком, не переключать")
    End If
End Sub
