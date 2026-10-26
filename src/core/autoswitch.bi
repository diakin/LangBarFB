' ---------------------------------------------------------------------------
'  autoswitch.bi - автопереключение (этап 5).
'
'  Слово проверяется, когда после него нажали пробел. Буфер слова хранит
'  клавиши, поэтому слово можно получить в любой раскладке. Если в
'  раскладке, где его набрали, такого слова нет в словаре, а в другой
'  раскладке есть - слово с пробелом стирается, печатается в той
'  раскладке, и раскладка окна меняется. Break сразу после этого
'  возвращает слово обратно и запоминает его (actions.bi).
'
'  Как у LangBarXX, слово не трогается, если:
'  - его правили Backspace или раскладку сменили посреди слова;
'  - в нём цифры, оно из одних заглавных (аббревиатура) - по настройкам;
'  - оно из одной буквы (по настройке) или начинается с трёх одинаковых
'    знаков;
'  - у одной из раскладок нет словаря.
'  Слово «есть» в раскладке, если его ядро (без знаков по краям) есть в
'  словаре. Если в обеих раскладках слово есть, переключение будет, только
'  когда в другой раскладке у него больше букв: «;er» и «жук» - «er» есть
'  в английском словаре, но «жук» длиннее.
'
'  Раньше пробела - на третьей букве (настройка «с третьей буквы», как
'  «Обработка текста с 3-х символов» LangBarXX): если в раскладке набора
'  нет слов с таким началом (wordstart.bi), а в другой есть, три буквы
'  перепечатываются и раскладка меняется; дальше слово набирается уже в
'  новой раскладке, и проверка на пробеле его пропускает (раскладку
'  сменили посреди слова).

'  Проверка идёт в главном потоке (не в хуке), уже после того как окно
'  получило клавишу; если пользователь успел нажать что-то ещё, слово
'  пропускается.
' ---------------------------------------------------------------------------

#pragma once

#include once "winapi.bi"
#include once "config.bi"
#include once "layouts.bi"
#include once "sendkeys.bi"
#include once "convert.bi"
#include once "spell.bi"
#include once "actions.bi"

Const AUTOSWITCH_MAX_KEYS = 40

' Текст клавиш буфера StartIdx..EndIdx в раскладке LayoutIdx; 0 - какая-то
' клавиша символа не даёт (мёртвая клавиша и т. п.)
Private Function AutoWordText(ByVal StartIdx As Long, ByVal EndIdx As Long, ByVal LayoutIdx As Long, _
        TextChars() As UShort) As Long
    Dim LayoutHandle As UInteger = LayoutList(LayoutIdx).LayoutHandle
    ReDim TextChars(0 To EndIdx - StartIdx)
    Dim KeyIdx As Long
    For KeyIdx = StartIdx To EndIdx
        With WordKeys(KeyIdx)
            TextChars(KeyIdx - StartIdx) = KeyCharInLayout(.VirtualKey, .WithShift, .CapsOn, LayoutHandle)
        End With
        If TextChars(KeyIdx - StartIdx) < 32 Then Return 0
    Next
    Return EndIdx - StartIdx + 1
End Function

Private Function AutoHasDigit(TextChars() As UShort, ByVal CharCount As Long) As Long
    Dim CharIdx As Long
    For CharIdx = 0 To CharCount - 1
        If TextChars(CharIdx) >= Asc("0") And TextChars(CharIdx) <= Asc("9") Then Return 1
    Next
    Return 0
End Function

' Все буквы заглавные (и букв больше одной)
Private Function AutoAllCaps(TextChars() As UShort, ByVal CharCount As Long) As Long
    Dim CharIdx As Long, Letters As Long
    For CharIdx = 0 To CharCount - 1
        If LbIsCharAlpha(TextChars(CharIdx)) Then
            If LbIsCharUpper(TextChars(CharIdx)) = 0 Then Return 0
            Letters += 1
        End If
    Next
    Return IIf(Letters > 1, 1, 0)
End Function

' Слово «есть» в раскладке: ядро в словаре. Letters - число букв ядра.
Private Function AutoWordKnown(ByVal LayoutIdx As Long, TextChars() As UShort, ByVal CharCount As Long, _
        ByRef Letters As Long, ByRef WordText As String) As Long
    Dim CoreStart As Long, CoreLength As Long
    Letters = SpellCoreRange(TextChars(), CharCount, CoreStart, CoreLength)
    WordText = SpellAnsiOf(TextChars(), 0, CharCount)
    If Letters = 0 Then Return 0
    Return SpellCheck(LayoutIdx, TextChars(), CoreStart, CoreLength)
End Function

' Перепечатывает клавиши буфера WordStart..WordKeyCount-1 (они заняли
' ShownChars символов) текстом TargetChars в раскладке TargetIdx, меняет
' раскладку окна; Break сразу после этого вернёт SourceIdx
Private Sub AutoRetype(ByVal TargetWindow As Any Ptr, ByVal WordStart As Long, ByVal ShownChars As Long, _
        TargetChars() As UShort, ByVal CharCount As Long, ByVal SourceIdx As Long, ByVal TargetIdx As Long, _
        ByRef LogText As String)
    ActionBusy = 1
    Dim TargetHandle As UInteger = LayoutList(TargetIdx).LayoutHandle
    Dim VirtualKeys() As UShort, ShiftFlags() As Long
    Dim KeyCount As Long = WordKeysFor(WordStart, WordStart + CharCount - 1, TargetHandle, VirtualKeys(), ShiftFlags())
    SendKeyTap(LB_VK_BACK, ShownChars)
    ' сначала раскладка, потом нажатия (как Break, actions.bi)
    Dim SwitchResult As Long = LayoutSwitchChecked(TargetWindow, TargetHandle, 30)
    If SwitchResult Then
        SendKeysWithShift(VirtualKeys(), ShiftFlags(), KeyCount)
    Else
        SendUnicodeText(TargetChars(), CharCount)
    End If
    WordCycleActive = 1
    WordCycleStart = WordStart
    WordCycleLayoutIdx = TargetIdx
    WordCycleShownChars = CharCount
    WordCycleUndoIdx = SourceIdx
    PlayEventSound(SOUND_AUTOSWITCH)
    LogAction(LogText & " -> автопереключение, раскладка: " & SwitchResultText(SwitchResult))
    ActionBusy = 0
End Sub

' Клавиша слова попала в буфер: если в слове ровно три клавиши - проверка
' начала слова по таблицам начал
Sub AutoSwitchStart()
    If Settings.AutoSwitch = 0 Or Settings.AutoEarly = 0 Or SpellDictCount = 0 Or LayoutCount < 2 Then Exit Sub
    If ActionBusy Or WordKeyCount < 3 Then Exit Sub
    Dim WordStart As Long = WordKeyCount - 3
    ' ровно три клавиши после пробела или начала буфера
    Dim KeyIdx As Long
    For KeyIdx = WordStart To WordKeyCount - 1
        If WordKeys(KeyIdx).VirtualKey = LB_VK_SPACE Then Exit Sub
    Next
    If WordStart > 0 AndAlso WordKeys(WordStart - 1).VirtualKey <> LB_VK_SPACE Then Exit Sub
    Dim SourceHandle As UInteger = WordKeys(WordStart).LayoutHandle
    For KeyIdx = WordStart To WordKeyCount - 1
        If WordKeys(KeyIdx).LayoutHandle <> SourceHandle Or WordKeys(KeyIdx).AfterBackspace Then Exit Sub
    Next
    Dim TargetWindow As Any Ptr = WordWindow
    If LayoutOfWindow(TargetWindow).LayoutHandle <> SourceHandle Then Exit Sub
    Dim SourceIdx As Long = LayoutIndexOf(SourceHandle)
    If SourceIdx < 0 Then Exit Sub
    Dim SourceChars() As UShort
    If AutoWordText(WordStart, WordKeyCount - 1, SourceIdx, SourceChars()) = 0 Then Exit Sub
    If SourceChars(0) = SourceChars(1) AndAlso SourceChars(1) = SourceChars(2) Then Exit Sub
    If Settings.AutoIgnoreDigits AndAlso AutoHasDigit(SourceChars(), 3) Then Exit Sub
    ' начало из букв, которое есть в языке раскладки, - всё в порядке
    Dim SourceLetters As Long = 1
    Dim CharIdx As Long
    For CharIdx = 0 To 2
        If LbIsCharAlpha(SourceChars(CharIdx)) = 0 Then SourceLetters = 0
    Next
    Dim SourceKnown As Long = 0
    If SourceLetters Then
        SourceKnown = StartKnown(SourceIdx, SourceChars(), 0)
        ' таблицы нет - решать не по чему
        If SourceKnown < 0 Then Exit Sub
    End If
    Dim LogText As String = "начало «" & SpellAnsiOf(SourceChars(), 0, 3) & "» " & LayoutList(SourceIdx).LocaleCode _
        & IIf(SourceKnown, " есть", " нет")
    If SourceKnown Then
        LogAction(LogText)
        Exit Sub
    End If

    Dim AltIdx As Long
    For AltIdx = 0 To LayoutCount - 1
        If AltIdx = SourceIdx Then Continue For
        Dim AltChars() As UShort
        If AutoWordText(WordStart, WordKeyCount - 1, AltIdx, AltChars()) = 0 Then Continue For
        Dim AltLetters As Long = 1
        For CharIdx = 0 To 2
            If LbIsCharAlpha(AltChars(CharIdx)) = 0 Then AltLetters = 0
        Next
        If AltLetters = 0 Then Continue For
        If Settings.AutoIgnoreCaps AndAlso AutoAllCaps(AltChars(), 3) Then Continue For
        Dim AltKnown As Long = StartKnown(AltIdx, AltChars(), 0)
        LogText &= "; «" & SpellAnsiOf(AltChars(), 0, 3) & "» " & LayoutList(AltIdx).LocaleCode _
            & IIf(AltKnown > 0, " есть", " нет")
        If AltKnown > 0 Then
            AutoRetype(TargetWindow, WordStart, 3, AltChars(), 3, SourceIdx, AltIdx, LogText)
            Exit Sub
        End If
    Next
    LogAction(LogText)
End Sub

' Пробел попал в буфер слова: проверить слово перед ним
Sub AutoSwitchWord()
    If Settings.AutoSwitch = 0 Or SpellDictCount = 0 Or LayoutCount < 2 Then Exit Sub
    If ActionBusy Then
        ' идёт другое действие или ждём смены раскладки - проверить потом
        WordSpaceFed = 1
        Exit Sub
    End If
    ' последний в буфере - пробел, перед ним - не пробел
    If WordKeyCount < 2 Then Exit Sub
    Dim SpaceIdx As Long = WordKeyCount - 1
    If WordKeys(SpaceIdx).VirtualKey <> LB_VK_SPACE Then Exit Sub
    If WordKeys(SpaceIdx - 1).VirtualKey = LB_VK_SPACE Then Exit Sub
    Dim WordStart As Long = WordStartBefore(SpaceIdx)
    If WordStart < 0 Then Exit Sub
    Dim WordEnd As Long = SpaceIdx - 1
    If WordEnd - WordStart + 1 > AUTOSWITCH_MAX_KEYS Then Exit Sub

    ' набрано в одной раскладке, без правки, и окно всё ещё в ней
    Dim SourceHandle As UInteger = WordKeys(WordStart).LayoutHandle
    Dim KeyIdx As Long
    For KeyIdx = WordStart To SpaceIdx
        If WordKeys(KeyIdx).LayoutHandle <> SourceHandle Then Exit Sub
        If WordKeys(KeyIdx).AfterBackspace Then
            LogAction("автопереключение: слово правили Backspace - не проверяется")
            Exit Sub
        End If
    Next
    Dim TargetWindow As Any Ptr = WordWindow
    If LayoutOfWindow(TargetWindow).LayoutHandle <> SourceHandle Then Exit Sub
    Dim SourceIdx As Long = LayoutIndexOf(SourceHandle)
    If SourceIdx < 0 Then Exit Sub
    If SpellDict(SourceIdx) = 0 Then Exit Sub

    Dim SourceChars() As UShort
    Dim CharCount As Long = AutoWordText(WordStart, WordEnd, SourceIdx, SourceChars())
    If CharCount = 0 Then Exit Sub
    ' три одинаковых знака в начале - не слово
    If CharCount >= 3 AndAlso SourceChars(0) = SourceChars(1) AndAlso SourceChars(1) = SourceChars(2) Then Exit Sub
    If Settings.AutoIgnoreDigits AndAlso AutoHasDigit(SourceChars(), CharCount) Then Exit Sub

    Dim SourceLetters As Long, SourceText As String
    Dim SourceKnown As Long = AutoWordKnown(SourceIdx, SourceChars(), CharCount, SourceLetters, SourceText)
    Dim LogText As String = "слово «" & SourceText & "» " & LayoutList(SourceIdx).LocaleCode _
        & IIf(SourceKnown, " есть", " нет")

    Dim TargetIdx As Long = -1
    Dim TargetChars() As UShort
    Dim AltIdx As Long
    For AltIdx = 0 To LayoutCount - 1
        If AltIdx = SourceIdx Or SpellDict(AltIdx) = 0 Then Continue For
        Dim AltChars() As UShort
        If AutoWordText(WordStart, WordEnd, AltIdx, AltChars()) = 0 Then Continue For
        If Settings.AutoIgnoreCaps AndAlso AutoAllCaps(AltChars(), CharCount) Then Continue For
        Dim AltLetters As Long, AltText As String
        Dim AltKnown As Long = AutoWordKnown(AltIdx, AltChars(), CharCount, AltLetters, AltText)
        LogText &= "; «" & AltText & "» " & LayoutList(AltIdx).LocaleCode & IIf(AltKnown, " есть", " нет")
        If AltKnown = 0 Then Continue For
        If AltLetters < 2 And Settings.AutoSingleLetter = 0 Then Continue For
        If SourceKnown And AltLetters <= SourceLetters Then Continue For
        TargetIdx = AltIdx
        ReDim TargetChars(0 To CharCount - 1)
        Dim CharIdx As Long
        For CharIdx = 0 To CharCount - 1
            TargetChars(CharIdx) = AltChars(CharIdx)
        Next
        Exit For
    Next
    If TargetIdx < 0 Then
        LogAction(LogText)
        Exit Sub
    End If

    ' слово и пробел - заново в другой раскладке
    ReDim Preserve TargetChars(0 To CharCount)
    TargetChars(CharCount) = 32
    AutoRetype(TargetWindow, WordStart, CharCount + 1, TargetChars(), CharCount + 1, SourceIdx, TargetIdx, LogText)
    ' пока ждали смены раскладки, набрали следующее слово
    If WordSpaceFed Then
        WordSpaceFed = 0
        AutoSwitchWord()
    End If
End Sub
