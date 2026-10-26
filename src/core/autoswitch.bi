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
'  Проверка идёт в главном потоке (не в хуке), уже после того как окно
'  получило пробел; если пользователь успел нажать что-то ещё, слово
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

    ActionBusy = 1
    ' слово и пробел - заново в другой раскладке
    ReDim Preserve TargetChars(0 To CharCount)
    TargetChars(CharCount) = 32
    SendKeyTap(LB_VK_BACK, CharCount + 1)
    SendUnicodeText(TargetChars(), CharCount + 1)
    ' Break сразу после этого вернёт слово в исходную раскладку
    WordCycleActive = 1
    WordCycleStart = WordStart
    WordCycleLayoutIdx = TargetIdx
    WordCycleShownChars = CharCount + 1
    WordCycleUndoIdx = SourceIdx
    PlayEventSound(SOUND_AUTOSWITCH)
    Dim TargetHandle As UInteger = LayoutList(TargetIdx).LayoutHandle
    LogAction(LogText & " -> автопереключение, раскладка: " _
        & SwitchResultText(LayoutSwitchChecked(TargetWindow, TargetHandle, 30)))
    ActionBusy = 0
    ' пока ждали смены раскладки, набрали следующее слово
    If WordSpaceFed Then
        WordSpaceFed = 0
        AutoSwitchWord()
    End If
End Sub
