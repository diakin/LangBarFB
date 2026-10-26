' ---------------------------------------------------------------------------
'  convert.bi - преобразования текста и буфер набранного слова.
'
'  Смена раскладки текста: для каждого символа ищется клавиша, которая
'  даёт его в исходной раскладке (VkKeyScanEx), и символ этой клавиши в
'  целевой (ToUnicodeEx). Исходная раскладка - та, в которой букв текста
'  набирается больше всего; целевая - следующая за ней в списке Windows.
'
'  Регистр - каждая буква наоборот, как InvertCase у LangBarXX.
'  Транслитерация - кириллица в латиницу по таблице Lib/Translit.ahk
'  LangBarXX (в одну сторону, как там).
'
'  Буфер слова - клавиши, нажатые в окне после последнего сброса (Enter,
'  Tab, стрелки, сочетания с Ctrl/Alt/Win, щелчок мыши, другое окно).
'  По Break последнее слово стирается и набирается заново в следующей
'  раскладке: хранятся клавиши, а не символы, поэтому слово можно набрать
'  в любой раскладке.
'
'  Часть LangBarFB (https://github.com/diakin/LangBarFB), лицензия LGPL-3.0
'  (COPYING.LESSER и COPYING в корне репозитория).
' ---------------------------------------------------------------------------

#pragma once

#include once "winapi.bi"
#include once "kbhook.bi"
#include once "layouts.bi"
#include once "sendkeys.bi"

' Символ клавиши VirtualKey в раскладке LayoutHandle; 0 - клавиша
' символа не даёт (или это мёртвая клавиша - её состояние сбрасывается)
Function KeyCharInLayout(ByVal VirtualKey As ULong, ByVal WithShift As Long, ByVal CapsOn As Long, _
        ByVal LayoutHandle As UInteger) As UShort
    Dim KeyState(0 To 255) As UByte
    If WithShift Then KeyState(LB_VK_SHIFT) = &h80
    If CapsOn Then KeyState(LB_VK_CAPITAL) = 1
    Dim LayoutPtr As Any Ptr = Cast(Any Ptr, LayoutHandle)
    Dim ScanCode As ULong = LbMapVirtualKeyEx(VirtualKey, LB_MAPVK_VK_TO_VSC, LayoutPtr)
    Dim CharBuffer(0 To 7) As UShort
    ' флаг 4 - не менять состояние клавиатуры (Windows 10 1607+, раньше
    ' не учитывается)
    Dim CharCount As Long = LbToUnicodeEx(VirtualKey, ScanCode, @KeyState(0), @CharBuffer(0), 8, 4, LayoutPtr)
    If CharCount = 1 Then Return CharBuffer(0)
    If CharCount < 0 Then
        ' мёртвая клавиша: второй вызов убирает её из состояния
        LbToUnicodeEx(VirtualKey, ScanCode, @KeyState(0), @CharBuffer(0), 8, 4, LayoutPtr)
    End If
    Return 0
End Function

' --- смена раскладки текста ---

' Сколько букв текста набирается в раскладке LayoutIdx
Private Function LayoutLetterScore(TextChars() As UShort, ByVal CharCount As Long, ByVal LayoutIdx As Long) As Long
    Dim LayoutPtr As Any Ptr = Cast(Any Ptr, LayoutList(LayoutIdx).LayoutHandle)
    Dim Score As Long, CharIdx As Long
    For CharIdx = 0 To CharCount - 1
        If LbIsCharAlpha(TextChars(CharIdx)) Then
            If LbVkKeyScanEx(TextChars(CharIdx), LayoutPtr) <> -1 Then Score += 1
        End If
    Next
    Return Score
End Function

' Исходная раскладка текста: где набирается больше букв; при равенстве -
' PreferredIdx (раскладка окна)
Function ConvertSourceLayout(TextChars() As UShort, ByVal CharCount As Long, ByVal PreferredIdx As Long) As Long
    Dim BestIdx As Long = PreferredIdx
    If BestIdx < 0 Or BestIdx >= LayoutCount Then BestIdx = 0
    Dim BestScore As Long = LayoutLetterScore(TextChars(), CharCount, BestIdx)
    Dim LayoutIdx As Long
    For LayoutIdx = 0 To LayoutCount - 1
        Dim Score As Long = LayoutLetterScore(TextChars(), CharCount, LayoutIdx)
        If Score > BestScore Then
            BestScore = Score
            BestIdx = LayoutIdx
        End If
    Next
    Return BestIdx
End Function

' Текст, набранный в раскладке SourceIdx, - каким он был бы в TargetIdx.
' Символы, которых нет в исходной раскладке, остаются как есть.
Sub ConvertLayoutText(TextChars() As UShort, ByVal CharCount As Long, ByVal SourceIdx As Long, ByVal TargetIdx As Long)
    Dim SourcePtr As Any Ptr = Cast(Any Ptr, LayoutList(SourceIdx).LayoutHandle)
    Dim TargetHandle As UInteger = LayoutList(TargetIdx).LayoutHandle
    Dim CharIdx As Long
    For CharIdx = 0 To CharCount - 1
        Dim CharCode As UShort = TextChars(CharIdx)
        If CharCode < 32 Then Continue For
        Dim KeyInfo As Short = LbVkKeyScanEx(CharCode, SourcePtr)
        If KeyInfo = -1 Then Continue For
        Dim ShiftState As Long = (KeyInfo Shr 8) And &hFF
        ' символы с Ctrl или Alt (AltGr) не переносятся
        If (ShiftState And 6) <> 0 Then Continue For
        Dim NewChar As UShort = KeyCharInLayout(KeyInfo And &hFF, ShiftState And 1, 0, TargetHandle)
        If NewChar >= 32 Then TextChars(CharIdx) = NewChar
    Next
End Sub

' --- регистр ---

Sub InvertTextCase(TextChars() As UShort, ByVal CharCount As Long)
    Dim CharIdx As Long
    For CharIdx = 0 To CharCount - 1
        If LbIsCharAlpha(TextChars(CharIdx)) Then
            If LbIsCharLower(TextChars(CharIdx)) Then
                LbCharUpperBuff(@TextChars(CharIdx), 1)
            Else
                LbCharLowerBuff(@TextChars(CharIdx), 1)
            End If
        End If
    Next
End Sub

' --- транслитерация ---

' Латиница для а..я (U+0430..U+044F) и ё (U+0451), как в Translit.ahk
Dim Shared TranslitLower(0 To 32) As ZString * 4 = { _
    "a", "b", "v", "g", "d", "e", "zh", "z", "i", "j", "k", "l", "m", "n", "o", "p", _
    "r", "s", "t", "u", "f", "kh", "ts", "ch", "sh", "shh", """", "y", "'", "eh", "yu", "ya", _
    "yo"}

' Кириллица в латиницу; результат - в TextChars, возвращает новую длину
Function TranslitText(TextChars() As UShort, ByVal CharCount As Long) As Long
    If CharCount <= 0 Then Return 0
    ' самая длинная замена - 3 буквы
    Dim ResultChars(0 To CharCount * 3 - 1) As UShort
    Dim ResultCount As Long, CharIdx As Long
    For CharIdx = 0 To CharCount - 1
        Dim CharCode As UShort = TextChars(CharIdx)
        Dim TableIdx As Long = -1
        Dim IsUpper As Long
        Select Case CharCode
        Case &h430 To &h44F
            TableIdx = CharCode - &h430
        Case &h410 To &h42F
            TableIdx = CharCode - &h410
            IsUpper = 1
        Case &h451
            TableIdx = 32
        Case &h401
            TableIdx = 32
            IsUpper = 1
        End Select
        If TableIdx < 0 Then
            ResultChars(ResultCount) = CharCode
            ResultCount += 1
            Continue For
        End If
        Dim Latin As String = TranslitLower(TableIdx)
        ' заглавная - первая буква замены заглавная: Ж - Zh
        If IsUpper Then Latin = UCase(Left(Latin, 1)) & Mid(Latin, 2)
        Dim LatinIdx As Long
        For LatinIdx = 1 To Len(Latin)
            ResultChars(ResultCount) = Asc(Latin, LatinIdx)
            ResultCount += 1
        Next
    Next
    ReDim TextChars(0 To ResultCount - 1)
    For CharIdx = 0 To ResultCount - 1
        TextChars(CharIdx) = ResultChars(CharIdx)
    Next
    Return ResultCount
End Function

' --- буфер набранного слова ---

Const WORD_BUFFER_SIZE = 128

Type TypedKey
    VirtualKey As ULong
    WithShift As Long
    CapsOn As Long
    LayoutHandle As UInteger   ' раскладка окна в момент нажатия
    AfterBackspace As Long     ' нажата сразу после Backspace (слово правили)
End Type

Dim Shared WordKeys(0 To WORD_BUFFER_SIZE - 1) As TypedKey
Dim Shared WordKeyCount As Long
Dim Shared WordWindow As Any Ptr
' после Break: в какую раскладку слово набрано и сколько символов оно
' заняло; следующий Break берёт следующую раскладку
Dim Shared WordCycleActive As Long
Dim Shared WordCycleLayoutIdx As Long
Dim Shared WordCycleShownChars As Long
' с какой клавиши буфера начинается перенабранный кусок (одно слово или
' несколько - при удержании Break)
Dim Shared WordCycleStart As Long
' после автопереключения: в какую раскладку Break возвращает слово (-1 -
' обычный круг)
Dim Shared WordCycleUndoIdx As Long = -1
' в буфер попал пробел - главная программа проверяет слово перед ним
Dim Shared WordSpaceFed As Long
' в буфер попала клавиша слова (не пробел) - проверка начала слова
Dim Shared WordLetterFed As Long
' был Backspace - следующая клавиша помечается AfterBackspace
Dim Shared WordBackspaced As Long

Sub WordBufferReset()
    WordKeyCount = 0
    WordWindow = 0
    WordCycleActive = 0
    WordSpaceFed = 0
    WordLetterFed = 0
    WordBackspaced = 0
End Sub

' Нажатие из хука. Проглоченные и программные нажатия не считаются.
Sub WordBufferFeed(ByRef KeyEvent As KbEvent)
    If KeyEvent.IsKeyUp Or KeyEvent.IsInjected Or KeyEvent.IsSwallowed Then Exit Sub
    Dim VirtualKey As ULong = KeyEvent.VirtualKey
    Select Case VirtualKey
    Case LB_VK_SHIFT, LB_VK_CONTROL, LB_VK_MENU, LB_VK_CAPITAL, LB_VK_LWIN, LB_VK_RWIN, &hA0 To &hA5
        Exit Sub
    End Select
    If (KeyEvent.Modifiers And (KB_MOD_CTRL Or KB_MOD_ALT Or KB_MOD_WIN)) <> 0 Then
        WordBufferReset()
        Exit Sub
    End If
    Dim ForegroundWindow As Any Ptr = LbGetForegroundWindow()
    If WordKeyCount > 0 And ForegroundWindow <> WordWindow Then WordBufferReset()

    If VirtualKey = LB_VK_BACK Then
        If WordKeyCount > 0 Then WordKeyCount -= 1
        WordCycleActive = 0
        WordBackspaced = 1
        Exit Sub
    End If
    ' символ клавиши в раскладке окна: нет символа (стрелки, F1) или
    ' управляющий (Enter, Tab, Esc) - слово закончено
    Dim LayoutHandle As Any Ptr = LbGetKeyboardLayout(LbGetWindowThreadProcessId(ForegroundWindow, 0))
    Dim KeyChar As ULong = LbMapVirtualKeyEx(VirtualKey, LB_MAPVK_VK_TO_CHAR, LayoutHandle) And &hFFFF
    If KeyChar < 32 Then
        WordBufferReset()
        Exit Sub
    End If
    If WordKeyCount = WORD_BUFFER_SIZE Then
        ' место кончилось - старое начало не нужно
        Dim ShiftIdx As Long
        For ShiftIdx = 1 To WORD_BUFFER_SIZE - 1
            WordKeys(ShiftIdx - 1) = WordKeys(ShiftIdx)
        Next
        WordKeyCount -= 1
    End If
    With WordKeys(WordKeyCount)
        .VirtualKey = VirtualKey
        .WithShift = IIf((KeyEvent.Modifiers And KB_MOD_SHIFT) <> 0, 1, 0)
        .CapsOn = KeyEvent.CapsOn
        .LayoutHandle = Cast(UInteger, LayoutHandle)
        .AfterBackspace = WordBackspaced
    End With
    WordKeyCount += 1
    WordWindow = ForegroundWindow
    WordCycleActive = 0
    WordBackspaced = 0
    If VirtualKey = LB_VK_SPACE Then WordSpaceFed = 1 Else WordLetterFed = 1
End Sub

' Клавиши буфера StartIdx..EndIdx для повторного набора нажатиями в
' раскладке LayoutHandle (SendKeysWithShift - после смены раскладки).
' Shift - как при наборе; у букв ещё учитывается, что Caps Lock мог
' смениться с тех пор. Возвращает число клавиш.
Function WordKeysFor(ByVal StartIdx As Long, ByVal EndIdx As Long, ByVal LayoutHandle As UInteger, _
        VirtualKeys() As UShort, ShiftFlags() As Long) As Long
    If EndIdx < StartIdx Then Return 0
    ReDim VirtualKeys(0 To EndIdx - StartIdx)
    ReDim ShiftFlags(0 To EndIdx - StartIdx)
    Dim KeyIdx As Long
    For KeyIdx = StartIdx To EndIdx
        With WordKeys(KeyIdx)
            VirtualKeys(KeyIdx - StartIdx) = .VirtualKey
            Dim NeedShift As Long = .WithShift
            If LbIsCharAlpha(KeyCharInLayout(.VirtualKey, 0, 0, LayoutHandle)) And .CapsOn <> KbCapsOn Then
                NeedShift = 1 - NeedShift
            End If
            ShiftFlags(KeyIdx - StartIdx) = NeedShift
        End With
    Next
    Return EndIdx - StartIdx + 1
End Function

' Где начинается последнее слово буфера: пробелы в конце остаются за
' словом. -1 - слова нет.
Function WordLastStart(ByRef TrailingSpaces As Long) As Long
    Dim KeyIdx As Long = WordKeyCount - 1
    TrailingSpaces = 0
    While KeyIdx >= 0 AndAlso WordKeys(KeyIdx).VirtualKey = LB_VK_SPACE
        TrailingSpaces += 1
        KeyIdx -= 1
    Wend
    If KeyIdx < 0 Then Return -1
    While KeyIdx >= 0 AndAlso WordKeys(KeyIdx).VirtualKey <> LB_VK_SPACE
        KeyIdx -= 1
    Wend
    Return KeyIdx + 1
End Function

' Начало слова перед позицией буфера Position (пробелы между ними
' пропускаются). -1 - слова там нет.
Function WordStartBefore(ByVal Position As Long) As Long
    Dim KeyIdx As Long = Position - 1
    While KeyIdx >= 0 AndAlso WordKeys(KeyIdx).VirtualKey = LB_VK_SPACE
        KeyIdx -= 1
    Wend
    If KeyIdx < 0 Then Return -1
    While KeyIdx >= 0 AndAlso WordKeys(KeyIdx).VirtualKey <> LB_VK_SPACE
        KeyIdx -= 1
    Wend
    Return KeyIdx + 1
End Function
