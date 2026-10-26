' ---------------------------------------------------------------------------
'  wordstart.bi - таблица начал слов: какими тремя буквами могут
'  начинаться слова языка. Строится при загрузке словаря из основ .dic
'  (начало слова почти всегда - начало основы) и приставок PFX из .aff.
'
'  По ней автопереключение (autoswitch.bi) решает уже на третьей букве:
'  если в раскладке набора слов с таким началом нет, а в другой есть -
'  раскладка неверная. Так работает «Обработка текста с 3-х символов»
'  LangBarXX, только вместо подсказок Hunspell - таблица.
'
'  Ключ - три буквы в нижнем регистре, по 16 бит. Основа короче трёх букв
'  с флагами окончаний даёт ключ с нулями в конце: любое слово на «go»
'  считается возможным. Такая же основа без флагов («в», «to») - готовое
'  слово, в таблицу не идёт: иначе любое слово на «в» было бы «возможным».
' ---------------------------------------------------------------------------

#pragma once

#include once "crt/stdlib.bi"
#include once "winapi.bi"
#include once "layouts.bi"

Type StartTable
    KeyList As ULongInt Ptr
    KeyCount As Long
    Capacity As Long
    Sorted As Long
End Type

Dim Shared StartTables(0 To MAX_LAYOUTS - 1) As StartTable

Private Function StartKeyOf(ByVal FirstChar As UShort, ByVal SecondChar As UShort, ByVal ThirdChar As UShort) As ULongInt
    Return (CULngInt(FirstChar) Shl 32) Or (CULngInt(SecondChar) Shl 16) Or CULngInt(ThirdChar)
End Function

Private Function StartCompare cdecl (ByVal FirstPtr As Const Any Ptr, ByVal SecondPtr As Const Any Ptr) As Long
    Dim FirstKey As ULongInt = *Cast(ULongInt Ptr, FirstPtr)
    Dim SecondKey As ULongInt = *Cast(ULongInt Ptr, SecondPtr)
    If FirstKey < SecondKey Then Return -1
    If FirstKey > SecondKey Then Return 1
    Return 0
End Function

Sub StartsClear(ByVal LayoutIdx As Long)
    With StartTables(LayoutIdx)
        If .KeyList <> 0 Then Deallocate(.KeyList)
        .KeyList = 0
        .KeyCount = 0
        .Capacity = 0
        .Sorted = 0
    End With
End Sub

Private Sub StartsPut(ByVal LayoutIdx As Long, ByVal StartKey As ULongInt)
    With StartTables(LayoutIdx)
        If .KeyCount = .Capacity Then
            .Capacity = IIf(.Capacity = 0, 4096, .Capacity * 2)
            .KeyList = Reallocate(.KeyList, .Capacity * SizeOf(ULongInt))
        End If
        .KeyList[.KeyCount] = StartKey
        .KeyCount += 1
        .Sorted = 0
    End With
End Sub

' Сортировка и удаление повторов (после загрузки и добавлений)
Private Sub StartsSort(ByVal LayoutIdx As Long)
    With StartTables(LayoutIdx)
        If .Sorted Or .KeyCount = 0 Then Exit Sub
        qsort(.KeyList, .KeyCount, SizeOf(ULongInt), @StartCompare)
        Dim ReadIdx As Long, WriteIdx As Long = 1
        For ReadIdx = 1 To .KeyCount - 1
            If .KeyList[ReadIdx] <> .KeyList[WriteIdx - 1] Then
                .KeyList[WriteIdx] = .KeyList[ReadIdx]
                WriteIdx += 1
            End If
        Next
        .KeyCount = WriteIdx
        .Sorted = 1
    End With
End Sub

' Начало слова TextChars(StartIdx..) длиной CharCount: первые три буквы
' в нижнем регистре. 0 - букв меньше одной.
Private Function StartKeyOfText(TextChars() As UShort, ByVal StartIdx As Long, ByVal CharCount As Long) As ULongInt
    Dim Letters(0 To 2) As UShort
    Dim CharIdx As Long
    For CharIdx = 0 To 2
        If CharIdx < CharCount Then Letters(CharIdx) = TextChars(StartIdx + CharIdx)
    Next
    LbCharLowerBuff(@Letters(0), 3)
    Return StartKeyOf(Letters(0), Letters(1), Letters(2))
End Function

' Слово (основа или слово из списка) - в таблицу начал
Sub StartsAddWord(ByVal LayoutIdx As Long, TextChars() As UShort, ByVal StartIdx As Long, ByVal CharCount As Long)
    If LayoutIdx < 0 Or LayoutIdx >= MAX_LAYOUTS Or CharCount < 3 Then Exit Sub
    StartsPut(LayoutIdx, StartKeyOfText(TextChars(), StartIdx, CharCount))
End Sub

' Есть ли слова, начинающиеся с этих трёх букв. -1 - таблицы нет.
Function StartKnown(ByVal LayoutIdx As Long, TextChars() As UShort, ByVal StartIdx As Long) As Long
    If LayoutIdx < 0 Or LayoutIdx >= MAX_LAYOUTS Then Return -1
    StartsSort(LayoutIdx)
    With StartTables(LayoutIdx)
        If .KeyCount = 0 Then Return -1
        Dim FullKey As ULongInt = StartKeyOfText(TextChars(), StartIdx, 3)
        ' сама тройка, основа из двух букв, основа из одной
        Dim Candidates(0 To 2) As ULongInt
        Candidates(0) = FullKey
        Candidates(1) = FullKey And &hFFFFFFFF0000ull
        Candidates(2) = FullKey And &hFFFF00000000ull
        Dim CandIdx As Long
        For CandIdx = 0 To 2
            Dim LowIdx As Long = 0, HighIdx As Long = .KeyCount - 1
            While LowIdx <= HighIdx
                Dim MiddleIdx As Long = (LowIdx + HighIdx) \ 2
                If .KeyList[MiddleIdx] = Candidates(CandIdx) Then Return 1
                If .KeyList[MiddleIdx] < Candidates(CandIdx) Then LowIdx = MiddleIdx + 1 Else HighIdx = MiddleIdx - 1
            Wend
        Next
    End With
    Return 0
End Function

' --- построение из словаря ---

' Кодовая страница по строке SET файла .aff
Private Function StartCodePage(ByRef CharsetName As String) As ULong
    Select Case UCase(CharsetName)
    Case "UTF-8"
        Return 65001
    Case "ISO8859-1"
        Return 28591
    Case "ISO8859-2"
        Return 28592
    Case "ISO8859-5"
        Return 28595
    Case "ISO8859-7"
        Return 28597
    Case "ISO8859-15"
        Return 28605
    Case "KOI8-R"
        Return 20866
    Case "KOI8-U"
        Return 21866
    Case "MICROSOFT-CP1251", "CP1251"
        Return 1251
    End Select
    Return 65001
End Function

Private Function StartDecode(ByRef FileBytes As String, ByVal CodePage As ULong, TextChars() As UShort) As Long
    If Len(FileBytes) = 0 Then Return 0
    Dim CharCount As Long = LbMultiByteToWideChar(CodePage, 0, StrPtr(FileBytes), Len(FileBytes), 0, 0)
    If CharCount <= 0 Then Return 0
    ReDim TextChars(0 To CharCount - 1)
    LbMultiByteToWideChar(CodePage, 0, StrPtr(FileBytes), Len(FileBytes), Cast(WString Ptr, @TextChars(0)), CharCount)
    Return CharCount
End Function

Private Function StartReadFile(ByRef FileName As String, ByRef FileBytes As String) As Long
    Dim FileNum As Long = FreeFile
    If Open(FileName For Binary Access Read As #FileNum) <> 0 Then Return 0
    FileBytes = String(Lof(FileNum), 0)
    If Len(FileBytes) > 0 Then Get #FileNum, , FileBytes
    Close #FileNum
    Return Len(FileBytes)
End Function

' Таблица начал раскладки LayoutIdx из пары .aff/.dic
Sub StartsBuild(ByVal LayoutIdx As Long, ByRef AffPath As String, ByRef DicPath As String)
    StartsClear(LayoutIdx)
    Dim AffBytes As String, DicBytes As String
    If StartReadFile(AffPath, AffBytes) = 0 Or StartReadFile(DicPath, DicBytes) = 0 Then Exit Sub

    ' .aff: кодировка, вид флагов, приставки (флаг и что добавляется)
    Dim CodePage As ULong = 65001
    Dim SingleCharFlags As Long = 1
    Dim PrefixFlags(0 To 63) As String, PrefixTexts(0 To 63) As String
    Dim PrefixCount As Long
    Dim LineStart As Long = 1
    While LineStart <= Len(AffBytes)
        Dim LineEnd As Long = InStr(LineStart, AffBytes, Chr(10))
        If LineEnd = 0 Then LineEnd = Len(AffBytes) + 1
        Dim AffLine As String = Trim(Mid(AffBytes, LineStart, LineEnd - LineStart), Any Chr(9, 13, 32))
        LineStart = LineEnd + 1
        ' поля строки через пробелы и табуляции
        Dim Fields(0 To 4) As String, FieldCount As Long = 0
        Dim CharIdx As Long = 1
        While CharIdx <= Len(AffLine) And FieldCount < 5
            While CharIdx <= Len(AffLine) AndAlso (AffLine[CharIdx - 1] = 32 Or AffLine[CharIdx - 1] = 9)
                CharIdx += 1
            Wend
            Dim FieldStart As Long = CharIdx
            While CharIdx <= Len(AffLine) AndAlso AffLine[CharIdx - 1] <> 32 AndAlso AffLine[CharIdx - 1] <> 9
                CharIdx += 1
            Wend
            If CharIdx > FieldStart Then
                Fields(FieldCount) = Mid(AffLine, FieldStart, CharIdx - FieldStart)
                FieldCount += 1
            End If
        Wend
        If FieldCount >= 2 And Fields(0) = "SET" Then CodePage = StartCodePage(Fields(1))
        If FieldCount >= 2 And Fields(0) = "FLAG" Then
            ' long, num - флаги не по одному знаку: приставки ко всем основам
            If Fields(1) <> "UTF-8" Then SingleCharFlags = 0
        End If
        If FieldCount >= 5 And Fields(0) = "PFX" And PrefixCount < 64 Then
            Dim AddText As String = Fields(3)
            Dim SlashPos As Long = InStr(AddText, "/")
            If SlashPos > 0 Then AddText = Left(AddText, SlashPos - 1)
            If AddText <> "0" And AddText <> "" Then
                PrefixFlags(PrefixCount) = Fields(1)
                PrefixTexts(PrefixCount) = AddText
                PrefixCount += 1
            End If
        End If
    Wend

    Dim DicChars() As UShort
    Dim CharCount As Long = StartDecode(DicBytes, CodePage, DicChars())
    DicBytes = ""
    If CharCount = 0 Then Exit Sub
    ' приставки - в UTF-16
    Dim PrefixChars(0 To 63, 0 To 7) As UShort, PrefixLength(0 To 63) As Long
    Dim PrefixIdx As Long
    For PrefixIdx = 0 To PrefixCount - 1
        Dim OneText() As UShort
        Dim TextLength As Long = StartDecode(PrefixTexts(PrefixIdx), CodePage, OneText())
        If TextLength > 8 Then TextLength = 8
        PrefixLength(PrefixIdx) = TextLength
        Dim LetterIdx As Long
        For LetterIdx = 0 To TextLength - 1
            PrefixChars(PrefixIdx, LetterIdx) = OneText(LetterIdx)
        Next
    Next

    Dim WordBuffer(0 To 15) As UShort
    Dim LineIdx As Long, WordStart As Long = 0, CharPos As Long
    For CharPos = 0 To CharCount
        If CharPos < CharCount AndAlso DicChars(CharPos) <> 10 Then Continue For
        ' строка WordStart..CharPos-1: основа до «/», пробела или табуляции
        Dim StemEnd As Long = WordStart
        While StemEnd < CharPos AndAlso DicChars(StemEnd) <> Asc("/") AndAlso DicChars(StemEnd) > 32
            StemEnd += 1
        Wend
        Dim StemLength As Long = StemEnd - WordStart
        ' первая строка .dic - число слов
        Dim IsStem As Long = IIf(StemLength > 0, 1, 0)
        If IsStem And LineIdx = 0 Then
            If DicChars(WordStart) >= Asc("0") And DicChars(WordStart) <= Asc("9") Then IsStem = 0
        End If
        If IsStem Then
            ' флаги основы: от «/» до пробела
            Dim FlagStart As Long = StemEnd + 1, FlagEnd As Long = StemEnd + 1
            If StemEnd < CharPos AndAlso DicChars(StemEnd) = Asc("/") Then
                While FlagEnd < CharPos AndAlso DicChars(FlagEnd) > 32
                    FlagEnd += 1
                Wend
            Else
                FlagEnd = FlagStart
            End If
            ' короткая основа без флагов - готовое слово из одной-двух букв:
            ' дальше оно не продолжается, начал слов не даёт
            If StemLength >= 3 Or FlagEnd > FlagStart Then
                StartsPut(LayoutIdx, StartKeyOfText(DicChars(), WordStart, StemLength))
            End If
            For PrefixIdx = 0 To PrefixCount - 1
                Dim HasFlag As Long = 0
                If SingleCharFlags = 0 Then
                    HasFlag = IIf(FlagEnd > FlagStart, 1, 0)
                Else
                    Dim FlagChar As UShort = Asc(PrefixFlags(PrefixIdx))
                    Dim FlagIdx As Long
                    For FlagIdx = FlagStart To FlagEnd - 1
                        If DicChars(FlagIdx) = FlagChar Then HasFlag = 1 : Exit For
                    Next
                End If
                If HasFlag = 0 Then Continue For
                ' приставка + начало основы
                Dim BufferLength As Long = 0, LetterIdx As Long
                For LetterIdx = 0 To PrefixLength(PrefixIdx) - 1
                    WordBuffer(BufferLength) = PrefixChars(PrefixIdx, LetterIdx)
                    BufferLength += 1
                Next
                For LetterIdx = 0 To StemLength - 1
                    If BufferLength >= 3 Then Exit For
                    WordBuffer(BufferLength) = DicChars(WordStart + LetterIdx)
                    BufferLength += 1
                Next
                StartsPut(LayoutIdx, StartKeyOfText(WordBuffer(), 0, BufferLength))
            Next
        End If
        WordStart = CharPos + 1
        LineIdx += 1
    Next
    StartsSort(LayoutIdx)
End Sub
