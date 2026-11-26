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
#include once "fixrank.bi"
#include once "fixmore.bi"

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
' цена правок каждого варианта (fixrank.bi) и уверенность в первом
Dim Shared FixCosts() As Long
' цена правок плюс цена редкости слова (wordfreq.bi) - по ней порядок
Dim Shared FixScores() As Long
' Ctrl + Break перебирает не больше стольких лучших вариантов
Const FIX_MAX_VARIANTS = 4
Dim Shared FixConfident As Long
Declare Sub FixRankSort(ByVal TypedLayout As UInteger)
' 1 - исправление сделало автоисправление после пробела (Break его отменяет)
Dim Shared FixAuto As Long
' автоисправление в другой раскладке (autoswitch.bi): набранное слово и
' раскладка набора - их возвращает Break; FixUndoLayoutIdx -1 - исправление
' в раскладке набора
Dim Shared FixUndoLayoutIdx As Long = -1
Dim Shared FixUndoChars() As UShort
Dim Shared FixUndoCount As Long

' Слово, исправленное вручную после исправления опечатки, запоминается
' (FixLearnOnSpace). Последние FIXLEARN_KEEP исправлений: окно, словарь,
' исходное слово и вариант (без знаков по краям).
Const FIXLEARN_KEEP = 5
Const FIXLEARN_MIN_LETTERS = 3
Type FixLearnItem
    WindowHandle As Any Ptr
    LayoutIdx As Long
    OriginalChars(0 To SPELL_MAX_WORD - 1) As UShort
    OriginalLength As Long
    VariantChars(0 To SPELL_MAX_WORD - 1) As UShort
    VariantLength As Long
End Type
Dim Shared FixLearnItems(0 To FIXLEARN_KEEP - 1) As FixLearnItem
Dim Shared FixLearnCount As Long
' последнее исправление: весь текст, который оно поставило в окно (с
' пробелами после слова), и номер сброса буфера в тот момент
Dim Shared FixLearnRecentActive As Long
Dim Shared FixLearnRecentReset As Long
Dim Shared FixLearnRecentText() As UShort
Dim Shared FixLearnRecentLength As Long
Declare Sub FixLearnNote(ShownText() As UShort, ByVal ShownCount As Long)

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

' Слово у каретки: Ctrl+Left - к началу слова (каретка в слове, сразу
' после него или после пробела за ним), Ctrl+Shift+Right - выделить до
' конца, скопировать. KeepSelected 0 - выделение снимается Right (каретка
' - после слова), 1 - остаётся (его заменит исправление опечатки).
' Каретка в самом начале слова даст предыдущее слово. Возвращает число
' символов; 0 - ничего не скопировалось.
Private Function CopyWordAtCaret(TextChars() As UShort, ByVal KeepSelected As Long) As Long
    SendKeyWithModifier(LB_VK_CONTROL, LB_VK_LEFT)
    SendKeyWithModifiers(LB_VK_CONTROL, LB_VK_SHIFT, LB_VK_RIGHT)
    SendWaitPump(20)
    Dim CharCount As Long = CopySelectionText(TextChars())
    If KeepSelected = 0 Then SendKeyTap(LB_VK_RIGHT)
    Return CharCount
End Function

' Выделенный текст, а если выделения нет - слово у каретки (оно
' выделяется). LogPrefix - начало строк окна отладки. Возвращает число
' символов; 0 - нет ни выделения, ни слова.
Private Function CopySelectionOrWord(TextChars() As UShort, ByVal KeepSelected As Long, _
        ByRef LogPrefix As String) As Long
    Dim CharCount As Long = CopySelectionText(TextChars())
    ' VS Code, Notepad++ и т. п. без выделения копируют строку целиком
    ' (с переводом строки в конце) - это не выделение
    If CharCount > 0 AndAlso (TextChars(CharCount - 1) = 10 Or TextChars(CharCount - 1) = 13) Then
        LogAction(LogPrefix & ": скопирована строка целиком - выделения нет, берётся слово у каретки")
        CharCount = 0
    End If
    If CharCount > 0 Then
        LogAction(LogPrefix & ": взят выделенный текст")
        Return CharCount
    End If
    CharCount = CopyWordAtCaret(TextChars(), KeepSelected)
    If CharCount > 0 Then LogAction(LogPrefix & ": взято слово у каретки")
    Return CharCount
End Function

Declare Function FixPrepareOriginal(ByVal TargetWindow As Any Ptr, ByVal TypedLayout As UInteger, _
    ByVal TrailingSpaces As Long, ByVal ShownChars As Long, ByVal WithLog As Long) As Long

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
    Return FixPrepareOriginal(TargetWindow, TypedLayout, TrailingSpaces, FixOriginalCount + TrailingSpaces, WithLog)
End Function

' Продолжение FixPrepare и FixPrepareSelection: слово уже в FixOriginal,
' TypedLayout - раскладка, по словарю которой искать; ShownChars - сколько
' символов стереть Backspace перед первым вариантом (0 - слово выделено,
' вариант набирается поверх выделения)
Function FixPrepareOriginal(ByVal TargetWindow As Any Ptr, ByVal TypedLayout As UInteger, _
        ByVal TrailingSpaces As Long, ByVal ShownChars As Long, ByVal WithLog As Long) As Long
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
    If SpellCheckUpper(LayoutIdx, FixOriginal(), FixCoreStart, FixCoreLength) Then
        If WithLog Then LogAction("опечатка: «" & WordText & "» есть в словаре " & LayoutCodeOf(TypedLayout) _
            & " заглавными (сокращение) - не исправляется")
        Return 0
    End If
    ' Hunspell ищет варианты в главном потоке; пока он ищет, хук ждёт
    Dim SuggestStart As Double = Timer
    FixCount = SpellSuggest(LayoutIdx, FixOriginal(), FixCoreStart, FixCoreLength, FixChars(), FixStarts(), FixLengths())
    LogAction("опечатка: поиск вариантов для «" & WordText & "» - " & CLng((Timer - SuggestStart) * 1000) & " мс")
    ' слова в две правки, которых Hunspell не нашёл (fixmore.bi)
    Dim MoreStart As Double = Timer
    Dim MoreChecks As Long
    Dim MoreAdded As Long = FixMoreSuggest(LayoutIdx, TypedLayout, FixOriginal(), FixCoreStart, FixCoreLength, _
        FixChars(), FixStarts(), FixLengths(), FixCount, MoreChecks)
    LogAction("опечатка: свой поиск - добавлено " & MoreAdded & ", проверено слов " & MoreChecks _
        & ", " & CLng((Timer - MoreStart) * 1000) & " мс")
    FixRankSort(TypedLayout)
    If FixCount = 0 Then
        LogAction("опечатка: для «" & WordText & "» вариантов нет")
        Return 0
    End If
    FixLayoutIdx = LayoutIdx
    FixTrailing = TrailingSpaces
    FixWindow = TargetWindow
    FixShownIdx = -1
    FixShownChars = ShownChars
    FixAuto = 0
    FixUndoLayoutIdx = -1
    FixActive = 1
    ' буфер больше не совпадает с текстом в окне: Break и
    ' автопереключение для этого слова не работают
    WordBufferReset()
    Return 1
End Function

' Готовит исправление выделенного слова (или слова у каретки, которое
' выделяется): варианты набираются поверх выделения. Раскладка - окна,
' а если в ней слово не набрать - первая, где набирается.
Function FixPrepareSelection(ByVal TargetWindow As Any Ptr) As Long
    FixActive = 0
    If HunspellSuggest = 0 Then
        LogAction("опечатка: словари не загружены или в библиотеке нет HunspellSuggest")
        Return 0
    End If
    Dim TextChars() As UShort
    Dim CharCount As Long = CopySelectionOrWord(TextChars(), 1, "опечатка")
    If CharCount <= 0 Then
        LogAction("опечатка: нет ни набранного слова, ни выделения, ни слова у каретки")
        Return 0
    End If
    ' одно слово: пробелы допустимы только по краям
    Dim FirstIdx As Long = 0, LastIdx As Long = CharCount - 1, CharIdx As Long
    While FirstIdx <= LastIdx AndAlso TextChars(FirstIdx) <= 32
        FirstIdx += 1
    Wend
    While LastIdx >= FirstIdx AndAlso TextChars(LastIdx) <= 32
        LastIdx -= 1
    Wend
    For CharIdx = FirstIdx To LastIdx
        If TextChars(CharIdx) <= 32 Then
            LogAction("опечатка: выделено больше одного слова")
            Return 0
        End If
    Next
    If LastIdx < FirstIdx Or CharCount > SPELL_MAX_WORD Then Return 0
    ReDim FixOriginal(0 To CharCount - 1)
    For CharIdx = 0 To CharCount - 1
        FixOriginal(CharIdx) = TextChars(CharIdx)
    Next
    FixOriginalCount = CharCount
    Dim TypedLayout As UInteger = LayoutOfWindow(TargetWindow).LayoutHandle
    Dim LayoutIdx As Long, OrderIdx As Long
    Dim StartIdx As Long = LayoutIndexOf(TypedLayout)
    If StartIdx < 0 Then StartIdx = 0
    For OrderIdx = 0 To LayoutCount - 1
        LayoutIdx = (StartIdx + OrderIdx) Mod LayoutCount
        Dim AllTypeable As Long = 1
        For CharIdx = FirstIdx To LastIdx
            If LbIsCharAlpha(TextChars(CharIdx)) AndAlso _
                    LbVkKeyScanEx(TextChars(CharIdx), Cast(Any Ptr, LayoutList(LayoutIdx).LayoutHandle)) = -1 Then
                AllTypeable = 0
                Exit For
            End If
        Next
        If AllTypeable Then
            TypedLayout = LayoutList(LayoutIdx).LayoutHandle
            Exit For
        End If
    Next
    Return FixPrepareOriginal(TargetWindow, TypedLayout, 0, 0, 1)
End Function

' Цена в десятых как текст: 8 - «0.8»
Private Function FixCostText(ByVal CostValue As Long) As String
    Return (CostValue \ 10) & "." & (CostValue Mod 10)
End Function

' Варианты - по цене правок (fixrank.bi) плюс цене редкости слова
' (wordfreq.bi), при равной цене - в порядке Hunspell; FixConfident -
' первый вариант можно ставить автоматически
Sub FixRankSort(ByVal TypedLayout As UInteger)
    If FixCount <= 0 Then Exit Sub
    ReDim FixCosts(0 To FixCount - 1)
    ReDim FixScores(0 To FixCount - 1)
    Dim LayoutIdx As Long = LayoutIndexOf(TypedLayout)
    Dim ItemIdx As Long, ScanIdx As Long, WithFreq As Long
    For ItemIdx = 0 To FixCount - 1
        FixCosts(ItemIdx) = FixRankCost(FixOriginal(), FixCoreStart, FixCoreLength, _
            FixChars(), FixStarts(ItemIdx), FixLengths(ItemIdx), TypedLayout)
        Dim RareCost As Long = FreqCost(LayoutIdx, FixChars(), FixStarts(ItemIdx), FixLengths(ItemIdx))
        If RareCost > 0 Then WithFreq = 1
        FixScores(ItemIdx) = FixCosts(ItemIdx) + RareCost
    Next
    ' вставками: порядок равных сохраняется
    For ItemIdx = 1 To FixCount - 1
        Dim KeyCost As Long = FixCosts(ItemIdx), KeyScore As Long = FixScores(ItemIdx)
        Dim KeyStart As Long = FixStarts(ItemIdx), KeyLength As Long = FixLengths(ItemIdx)
        ScanIdx = ItemIdx - 1
        While ScanIdx >= 0 AndAlso FixScores(ScanIdx) > KeyScore
            FixCosts(ScanIdx + 1) = FixCosts(ScanIdx)
            FixScores(ScanIdx + 1) = FixScores(ScanIdx)
            FixStarts(ScanIdx + 1) = FixStarts(ScanIdx)
            FixLengths(ScanIdx + 1) = FixLengths(ScanIdx)
            ScanIdx -= 1
        Wend
        FixCosts(ScanIdx + 1) = KeyCost
        FixScores(ScanIdx + 1) = KeyScore
        FixStarts(ScanIdx + 1) = KeyStart
        FixLengths(ScanIdx + 1) = KeyLength
    Next
    Dim NextScore As Long
    If FixCount > 1 Then NextScore = FixScores(1)
    FixConfident = FixRankConfident(FixCosts(0), FixScores(0), NextScore, FixCount, FixCoreLength)
    ' лишние варианты отбрасываются после оценки: второй вариант нужен для
    ' FixRankConfident в любом случае
    Dim AllCount As Long = FixCount
    If FixCount > FIX_MAX_VARIANTS Then FixCount = FIX_MAX_VARIANTS
    Dim RankText As String
    For ItemIdx = 0 To FixCount - 1
        RankText &= IIf(ItemIdx = 0, "", ", ") & SpellAnsiOf(FixChars(), FixStarts(ItemIdx), FixLengths(ItemIdx)) _
            & " " & FixCostText(FixCosts(ItemIdx))
        If WithFreq Then RankText &= "+" & FixCostText(FixScores(ItemIdx) - FixCosts(ItemIdx))
    Next
    If AllCount > FixCount Then RankText &= " (из " & AllCount & ")"
    LogAction("опечатка: варианты по цене правок" & IIf(WithFreq, " + частоте", "") & ": " & RankText _
        & IIf(FixConfident, "", " (первый не очевиден)"))
End Sub

' Показать в окне вариант ShowIdx (-1 - исходное слово)
Sub FixShow(ByVal ShowIdx As Long)
    FixShownIdx = ShowIdx
    Dim NewChars() As UShort
    Dim NewCount As Long = FixBuildText(NewChars())
    SendKeyTap(LB_VK_BACK, FixShownChars)
    SendUnicodeText(NewChars(), NewCount)
    FixShownChars = NewCount
    FixSerial = WordChangeSerial
    FixLearnNote(NewChars(), NewCount)
    If FixShownIdx < 0 Then
        LogAction("опечатка: возвращено исходное слово")
    Else
        PlayEventSound(SOUND_SPELL_FIX)
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
        If RangeStart >= 0 Then
            If FixPrepare(TargetWindow, RangeStart, TrailingSpaces, 1) = 0 Then Exit Sub
        Else
            ' набранного слова нет - выделенное слово или слово у каретки
            If FixPrepareSelection(TargetWindow) = 0 Then Exit Sub
        End If
    End If
    Dim NextIdx As Long = FixShownIdx + 1
    If NextIdx >= FixCount Then NextIdx = -1
    FixShow(NextIdx)
End Sub

' Break сразу после автоисправления: исходное слово обратно, и оно
' запоминается, как слово, автопереключение которого отменили
Private Sub FixUndoAuto()
    If FixUndoLayoutIdx >= 0 Then
        ' исправление было в другой раскладке: набранное слово и раскладка
        ' набора обратно
        Dim UndoIdx As Long = FixUndoLayoutIdx
        FixUndoLayoutIdx = -1
        FixActive = 0
        Dim UndoText(0 To FixUndoCount + FixTrailing) As UShort
        Dim CharIdx As Long
        For CharIdx = 0 To FixUndoCount - 1
            UndoText(CharIdx) = FixUndoChars(CharIdx)
        Next
        For CharIdx = 1 To FixTrailing
            UndoText(FixUndoCount + CharIdx - 1) = 32
        Next
        SendKeyTap(LB_VK_BACK, FixShownChars)
        Dim SwitchResult As Long = LayoutSwitchChecked(FixWindow, LayoutList(UndoIdx).LayoutHandle, 30)
        SendUnicodeText(UndoText(), FixUndoCount + FixTrailing)
        Dim UndoStart As Long, UndoLength As Long
        If SpellCoreRange(FixUndoChars(), FixUndoCount, UndoStart, UndoLength) > 0 Then
            SpellRemember(UndoIdx, FixUndoChars(), UndoStart, UndoLength, Settings.AutoRemember)
        End If
        LogAction("автоисправление отменено, возвращено «" & SpellAnsiOf(FixUndoChars(), 0, FixUndoCount) _
            & "» " & LayoutList(UndoIdx).LocaleCode & ", раскладка: " & SwitchResultText(SwitchResult) _
            & IIf(Settings.AutoRemember, " (записано в user_dict.dic)", ""))
        PlayEventSound(SOUND_UNDO_AUTOSWITCH)
        Exit Sub
    End If
    FixShow(-1)
    FixActive = 0
    SpellRemember(FixLayoutIdx, FixOriginal(), FixCoreStart, FixCoreLength, Settings.AutoRemember)
    LogAction("автоисправление отменено, слово «" & SpellAnsiOf(FixOriginal(), FixCoreStart, FixCoreLength) _
        & "» больше не исправляется" & IIf(Settings.AutoRemember, " (записано в user_dict.dic)", ""))
    PlayEventSound(SOUND_UNDO_AUTOSWITCH)
End Sub

' --- слово, исправленное вручную после исправления опечатки ---
'
' Хук видит только нажатия, текста окна программа не читает. Поэтому
' правка узнаётся так:
' 1) сразу после исправления стёрли Backspace часть слова и допечатали:
'    слово = начало показанного варианта + набранное;
' 2) вернулись к слову мышью или стрелками (буфер сброшен), набрали
'    исходное слово заново (поверх выделенного варианта, после его
'    стирания Backspace или допечатав конец к варианту) - если каретка
'    стояла в конце варианта, получается исходное слово одного из
'    FIXLEARN_KEEP последних исправлений в том же окне.
' Слово проверяется, когда после него набрали пробел или буфер
' сбрасывается (щелчок, стрелки, Enter): после допечатки к слову пробел
' обычно не набирают. Такое слово, если его нет в словаре, запоминается,
' как после Break. В случае 1 запоминается и другое слово не из словаря,
' если оно ближе к исходному, чем к варианту.

' Строчная копия куска текста
Private Sub FixLearnLower(SourceChars() As UShort, ByVal StartIdx As Long, ByVal CharCount As Long, _
        LowerChars() As UShort)
    ReDim LowerChars(0 To CharCount)
    Dim CharIdx As Long
    For CharIdx = 0 To CharCount - 1
        LowerChars(CharIdx) = SourceChars(StartIdx + CharIdx)
    Next
    If CharCount > 0 Then LbCharLowerBuff(@LowerChars(0), CharCount)
End Sub

' Исправление показано в окне: запомнить его. FixShownIdx -1 (возвращено
' исходное слово) - забыть.
Sub FixLearnNote(ShownText() As UShort, ByVal ShownCount As Long)
    FixLearnRecentActive = 0
    ' это же исправление (то же слово в том же окне) - заменить
    Dim ItemIdx As Long, FoundIdx As Long = -1, CharIdx As Long
    For ItemIdx = 0 To FixLearnCount - 1
        With FixLearnItems(ItemIdx)
            If .WindowHandle <> FixWindow Or .OriginalLength <> FixCoreLength Then Continue For
            Dim SameWord As Long = 1
            For CharIdx = 0 To FixCoreLength - 1
                If .OriginalChars(CharIdx) <> FixOriginal(FixCoreStart + CharIdx) Then SameWord = 0 : Exit For
            Next
            If SameWord Then FoundIdx = ItemIdx : Exit For
        End With
    Next
    If FoundIdx >= 0 Then
        For ItemIdx = FoundIdx To FixLearnCount - 2
            FixLearnItems(ItemIdx) = FixLearnItems(ItemIdx + 1)
        Next
        FixLearnCount -= 1
    End If
    If FixShownIdx < 0 Then Exit Sub
    If FixCoreLength > SPELL_MAX_WORD Or FixLengths(FixShownIdx) > SPELL_MAX_WORD Then Exit Sub

    ' новое - в конец, самое старое уходит
    If FixLearnCount = FIXLEARN_KEEP Then
        For ItemIdx = 0 To FIXLEARN_KEEP - 2
            FixLearnItems(ItemIdx) = FixLearnItems(ItemIdx + 1)
        Next
        FixLearnCount -= 1
    End If
    With FixLearnItems(FixLearnCount)
        .WindowHandle = FixWindow
        .LayoutIdx = FixLayoutIdx
        .OriginalLength = FixCoreLength
        For CharIdx = 0 To FixCoreLength - 1
            .OriginalChars(CharIdx) = FixOriginal(FixCoreStart + CharIdx)
        Next
        .VariantLength = FixLengths(FixShownIdx)
        For CharIdx = 0 To .VariantLength - 1
            .VariantChars(CharIdx) = FixChars(FixStarts(FixShownIdx) + CharIdx)
        Next
    End With
    FixLearnCount += 1

    ReDim FixLearnRecentText(0 To ShownCount)
    For CharIdx = 0 To ShownCount - 1
        FixLearnRecentText(CharIdx) = ShownText(CharIdx)
    Next
    FixLearnRecentLength = ShownCount
    FixLearnRecentReset = WordResetCount
    WordEmptyBackspaces = 0
    FixLearnRecentActive = 1
End Sub

' Запомнить слово WordChars(CoreStart..), исправленное вручную
' Слово, исправленное вручную, не запоминается сразу: оно встаёт в очередь
' вопросов, и окно поверх всех окон (ui/dlg_learn.bi, без захвата фокуса)
' спрашивает, добавить ли его в словарь. Правку узнаём по нажатиям, и
' она может оказаться не тем, чем кажется (стёрли и набрали заново, чтобы
' попробовать ещё раз), поэтому решает пользователь.
Const FIXLEARN_ASK_MAX = 5
Dim Shared FixLearnAskLayout(0 To FIXLEARN_ASK_MAX - 1) As Long
Dim Shared FixLearnAskChars(0 To FIXLEARN_ASK_MAX - 1, 0 To SPELL_MAX_WORD - 1) As UShort
Dim Shared FixLearnAskLength(0 To FIXLEARN_ASK_MAX - 1) As Long
Dim Shared FixLearnAskHow(0 To FIXLEARN_ASK_MAX - 1) As String
Dim Shared FixLearnAskCount As Long
Type FixLearnAskFn As Sub()
' показать вопрос (ставит окно); 0 - окна нет, слово запоминается сразу
Dim Shared FixLearnAskShow As FixLearnAskFn

' Первый вопрос очереди: слово строкой CP1251 и как его исправили
Function FixLearnAskWord() As String
    If FixLearnAskCount = 0 Then Return ""
    Dim WordChars(0 To SPELL_MAX_WORD - 1) As UShort
    Dim CharIdx As Long
    For CharIdx = 0 To FixLearnAskLength(0) - 1
        WordChars(CharIdx) = FixLearnAskChars(0, CharIdx)
    Next
    Return SpellAnsiOf(WordChars(), 0, FixLearnAskLength(0))
End Function

Function FixLearnAskReason() As String
    If FixLearnAskCount = 0 Then Return ""
    Return FixLearnAskHow(0)
End Function

' Ответ на первый вопрос: Accept 1 - добавить в словари и user_dict.dic
Sub FixLearnAskAnswer(ByVal Accept As Long)
    If FixLearnAskCount = 0 Then Exit Sub
    Dim WordChars(0 To SPELL_MAX_WORD - 1) As UShort
    Dim CharIdx As Long, ItemIdx As Long
    Dim WordLength As Long = FixLearnAskLength(0)
    For CharIdx = 0 To WordLength - 1
        WordChars(CharIdx) = FixLearnAskChars(0, CharIdx)
    Next
    Dim LayoutIdx As Long = FixLearnAskLayout(0)
    For ItemIdx = 0 To FixLearnAskCount - 2
        FixLearnAskLayout(ItemIdx) = FixLearnAskLayout(ItemIdx + 1)
        FixLearnAskLength(ItemIdx) = FixLearnAskLength(ItemIdx + 1)
        FixLearnAskHow(ItemIdx) = FixLearnAskHow(ItemIdx + 1)
        For CharIdx = 0 To SPELL_MAX_WORD - 1
            FixLearnAskChars(ItemIdx, CharIdx) = FixLearnAskChars(ItemIdx + 1, CharIdx)
        Next
    Next
    FixLearnAskCount -= 1
    Dim WordText As String = SpellAnsiOf(WordChars(), 0, WordLength)
    If Accept = 0 Then
        LogAction("опечатка: «" & WordText & "» - в словарь не добавлено (ответ «Нет»)")
        Exit Sub
    End If
    SpellRemember(LayoutIdx, WordChars(), 0, WordLength, 1)
    LogAction("опечатка: «" & WordText & "» добавлено в словарь (записано в user_dict.dic)")
    PlayEventSound(SOUND_ADD_WORD)
End Sub

Private Sub FixLearnRemember(ByVal LayoutIdx As Long, WordChars() As UShort, ByVal CoreStart As Long, _
        ByVal CoreLength As Long, ByRef HowText As String)
    Dim WordText As String = SpellAnsiOf(WordChars(), CoreStart, CoreLength)
    If FixLearnAskShow = 0 Then
        SpellRemember(LayoutIdx, WordChars(), CoreStart, CoreLength, Settings.AutoRemember)
        LogAction("опечатка: слово «" & WordText & "» исправлено вручную (" & HowText & ") - запомнено")
        PlayEventSound(SOUND_ADD_WORD)
        Exit Sub
    End If
    If CoreLength > SPELL_MAX_WORD Then Exit Sub
    ' уже спрашиваем про это слово
    Dim ItemIdx As Long, CharIdx As Long
    For ItemIdx = 0 To FixLearnAskCount - 1
        If FixLearnAskLength(ItemIdx) <> CoreLength Then Continue For
        Dim SameWord As Long = 1
        For CharIdx = 0 To CoreLength - 1
            If FixLearnAskChars(ItemIdx, CharIdx) <> WordChars(CoreStart + CharIdx) Then SameWord = 0 : Exit For
        Next
        If SameWord Then Exit Sub
    Next
    ' очередь полна - самый старый вопрос снимается без ответа
    If FixLearnAskCount = FIXLEARN_ASK_MAX Then
        For ItemIdx = 0 To FIXLEARN_ASK_MAX - 2
            FixLearnAskLayout(ItemIdx) = FixLearnAskLayout(ItemIdx + 1)
            FixLearnAskLength(ItemIdx) = FixLearnAskLength(ItemIdx + 1)
            FixLearnAskHow(ItemIdx) = FixLearnAskHow(ItemIdx + 1)
            For CharIdx = 0 To SPELL_MAX_WORD - 1
                FixLearnAskChars(ItemIdx, CharIdx) = FixLearnAskChars(ItemIdx + 1, CharIdx)
            Next
        Next
        FixLearnAskCount -= 1
    End If
    FixLearnAskLayout(FixLearnAskCount) = LayoutIdx
    FixLearnAskLength(FixLearnAskCount) = CoreLength
    FixLearnAskHow(FixLearnAskCount) = HowText
    For CharIdx = 0 To CoreLength - 1
        FixLearnAskChars(FixLearnAskCount, CharIdx) = WordChars(CoreStart + CharIdx)
    Next
    FixLearnAskCount += 1
    LogAction("опечатка: слово «" & WordText & "» исправлено вручную (" & HowText & ") - вопрос, добавить ли в словарь")
    FixLearnAskShow()
End Sub

' Убрать исправление ItemIdx из списка
Private Sub FixLearnDrop(ByVal ItemIdx As Long)
    Dim ShiftIdx As Long
    For ShiftIdx = ItemIdx To FixLearnCount - 2
        FixLearnItems(ShiftIdx) = FixLearnItems(ShiftIdx + 1)
    Next
    If FixLearnCount > 0 Then FixLearnCount -= 1
End Sub

' Ядро WordChars(CoreStart..) - исходное слово исправления ItemIdx (без
' учёта регистра)
Private Function FixLearnIsOriginal(ByVal ItemIdx As Long, WordChars() As UShort, ByVal CoreStart As Long, _
        ByVal CoreLength As Long) As Long
    With FixLearnItems(ItemIdx)
        If CoreLength <> .OriginalLength Then Return 0
        Dim OriginalLower() As UShort, WordLower() As UShort
        FixLearnLower(.OriginalChars(), 0, .OriginalLength, OriginalLower())
        FixLearnLower(WordChars(), CoreStart, CoreLength, WordLower())
        Dim CharIdx As Long
        For CharIdx = 0 To CoreLength - 1
            If WordLower(CharIdx) <> OriginalLower(CharIdx) Then Return 0
        Next
    End With
    Return 1
End Function

' Набранное после сброса буфера (клавиши 0..EndIdx) не правит ли недавнее
' исправление опечатки. Возвращает 1, если слово запомнено.
Private Function FixLearnCheck(ByVal EndIdx As Long, ByVal RecentValid As Long, ByVal CaretMoved As Long) As Long
    If FixLearnCount = 0 Or (CaretMoved = 0 And RecentValid = 0) Then Return 0
    If SpellDictCount = 0 Or EndIdx < 0 Then Return 0
    Dim TypedCount As Long = EndIdx + 1
    If TypedCount > SPELL_MAX_WORD Then Return 0
    Dim TypedLayout As UInteger = WordKeys(0).LayoutHandle
    Dim TypedChars(0 To SPELL_MAX_WORD) As UShort
    Dim KeyIdx As Long, CharIdx As Long
    For KeyIdx = 0 To EndIdx
        If WordKeys(KeyIdx).VirtualKey = LB_VK_SPACE Then Return 0
        If WordKeys(KeyIdx).LayoutHandle <> TypedLayout Then Return 0
        TypedChars(KeyIdx) = WordKeyChar(KeyIdx, TypedLayout)
        If TypedChars(KeyIdx) < 32 Then Return 0
    Next
    Dim LayoutIdx As Long = LayoutIndexOf(TypedLayout)
    If LayoutIdx < 0 Then Return 0
    Dim LastItem As Long = FixLearnCount - 1
    Dim WordChars(0 To SPELL_MAX_WORD) As UShort
    Dim CoreStart As Long, CoreLength As Long

    ' 1) сразу после исправления: стёрли часть показанного и допечатали
    If RecentValid And WordEmptyBackspaces > 0 And FixLearnItems(LastItem).WindowHandle = WordWindow _
            And FixLearnItems(LastItem).LayoutIdx = LayoutIdx Then
        Dim KeptCount As Long = FixLearnRecentLength - WordEmptyBackspaces
        If KeptCount < 0 Or KeptCount + TypedCount > SPELL_MAX_WORD Then Return 0
        For CharIdx = 0 To KeptCount - 1
            WordChars(CharIdx) = FixLearnRecentText(CharIdx)
        Next
        For CharIdx = 0 To TypedCount - 1
            WordChars(KeptCount + CharIdx) = TypedChars(CharIdx)
        Next
        Dim WordCount As Long = KeptCount + TypedCount
        For CharIdx = 0 To WordCount - 1
            If WordChars(CharIdx) = 32 Then Return 0
        Next
        If SpellCoreRange(WordChars(), WordCount, CoreStart, CoreLength) < FIXLEARN_MIN_LETTERS Then Return 0
        Dim WordText As String = SpellAnsiOf(WordChars(), CoreStart, CoreLength)
        If FixLearnIsOriginal(LastItem, WordChars(), CoreStart, CoreLength) Then
            If SpellCheck(LayoutIdx, WordChars(), CoreStart, CoreLength) = 0 Then
                FixLearnRemember(LayoutIdx, WordChars(), CoreStart, CoreLength, "Backspace сразу после исправления")
            End If
            FixLearnDrop(LastItem)
            Return 1
        End If
        ' набрали тот же вариант
        With FixLearnItems(LastItem)
            If CoreLength = .VariantLength Then
                Dim SameVariant As Long = 1
                For CharIdx = 0 To CoreLength - 1
                    If WordChars(CoreStart + CharIdx) <> .VariantChars(CharIdx) Then SameVariant = 0 : Exit For
                Next
                If SameVariant Then Return 0
            End If
        End With
        If SpellCheck(LayoutIdx, WordChars(), CoreStart, CoreLength) Then
            LogAction("опечатка: исправление поправлено вручную на «" & WordText & "» - оно есть в словаре")
            Return 0
        End If
        ' правка должна вести к исходному слову, а не быть новой опечаткой в
        ' варианте («опечатка» - допечатали «опечаткаа»)
        With FixLearnItems(LastItem)
            Dim ToOriginal As Long = FixRankCost(WordChars(), CoreStart, CoreLength, _
                .OriginalChars(), 0, .OriginalLength, TypedLayout)
            Dim ToVariant As Long = FixRankCost(WordChars(), CoreStart, CoreLength, _
                .VariantChars(), 0, .VariantLength, TypedLayout)
            If ToOriginal >= ToVariant Then
                LogAction("опечатка: исправление поправлено вручную на «" & WordText _
                    & "», но это ближе к варианту, чем к набранному слову - не запоминается")
                Return 0
            End If
        End With
        FixLearnRemember(LayoutIdx, WordChars(), CoreStart, CoreLength, "Backspace сразу после исправления")
        FixLearnDrop(LastItem)
        Return 1
    End If

    ' 2) вернулись к слову мышью или стрелками: вариант выделили и набрали
    ' исходное слово поверх, или каретка стояла в конце варианта и к его
    ' началу (после Backspace) допечатали остальное
    If CaretMoved = 0 Then Return 0
    Dim ItemIdx As Long
    For ItemIdx = LastItem To 0 Step -1
        With FixLearnItems(ItemIdx)
            If .WindowHandle <> WordWindow Or .LayoutIdx <> LayoutIdx Then Continue For
            Dim OptionIdx As Long
            For OptionIdx = 0 To 1
                Dim KeptLetters As Long
                If OptionIdx = 0 Then
                    If WordEmptyBackspaces > 0 Then Continue For
                    KeptLetters = 0
                Else
                    KeptLetters = .VariantLength - WordEmptyBackspaces
                End If
                If KeptLetters < 0 Or KeptLetters + TypedCount <> .OriginalLength Then Continue For
                For CharIdx = 0 To KeptLetters - 1
                    WordChars(CharIdx) = .VariantChars(CharIdx)
                Next
                For CharIdx = 0 To TypedCount - 1
                    WordChars(KeptLetters + CharIdx) = TypedChars(CharIdx)
                Next
                If FixLearnIsOriginal(ItemIdx, WordChars(), 0, .OriginalLength) = 0 Then Continue For
                If SpellCheck(LayoutIdx, WordChars(), 0, .OriginalLength) = 0 Then
                    FixLearnRemember(LayoutIdx, WordChars(), 0, .OriginalLength, "набрано заново")
                End If
                FixLearnDrop(ItemIdx)
                Return 1
            Next
        End With
    Next
    Return 0
End Function

' Текущие признаки: исправление только что показано и буфер с тех пор не
' сбрасывали
Private Function FixLearnRecentValid() As Long
    Return IIf(FixLearnRecentActive <> 0 And FixLearnRecentReset = WordResetCount, 1, 0)
End Function

' Пробел после слова. Вызывается до автопереключения; запомненное слово
' уже есть в словаре и дальше не исправляется. Признаки «сразу после
' исправления» и «каретку переносили» действуют только до первого пробела.
Sub FixLearnOnSpace()
    Dim CaretMoved As Long = WordCaretMoved
    Dim RecentValid As Long = FixLearnRecentValid()
    WordCaretMoved = 0
    FixLearnRecentActive = 0
    If WordKeyCount < 2 Then Exit Sub
    Dim SpaceIdx As Long = WordKeyCount - 1
    If WordKeys(SpaceIdx).VirtualKey <> LB_VK_SPACE Then Exit Sub
    FixLearnCheck(SpaceIdx - 1, RecentValid, CaretMoved)
End Sub

' Буфер сбрасывается (щелчок, стрелки, Enter, другое окно), а слово не
' закончено пробелом: проверить его так же. Во время действий (Ctrl + Break
' сам сбрасывает буфер) - нет.
Sub FixLearnOnReset()
    If ActionBusy Or FixLearnCount = 0 Then Exit Sub
    Dim CaretMoved As Long = WordCaretMoved
    Dim RecentValid As Long = FixLearnRecentValid()
    WordCaretMoved = 0
    FixLearnRecentActive = 0
    If CaretMoved = 0 And RecentValid = 0 Then Exit Sub
    If WordKeyCount < 1 OrElse WordKeys(WordKeyCount - 1).VirtualKey = LB_VK_SPACE Then Exit Sub
    FixLearnCheck(WordKeyCount - 1, RecentValid, CaretMoved)
End Sub
WordBeforeReset = @FixLearnOnReset

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
        CharCount = CopySelectionOrWord(TextChars(), 0, "словарь")
        If CharCount <= 0 Then
            LogAction("словарь: нет ни набранного слова, ни выделения, ни слова у каретки")
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
    If AddWordsOf(TextChars(), CharCount) > 0 Then PlayEventSound(SOUND_ADD_WORD)
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
