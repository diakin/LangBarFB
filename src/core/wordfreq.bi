' ---------------------------------------------------------------------------
'  wordfreq.bi - частотные словари для порядка вариантов исправления опечатки.
'
'  dict\<код раскладки>\freq.txt - слова в нижнем регистре, по одному в
'  строке, самые частые первыми (номер строки - ранг; строки с «#» -
'  описание). Списки из FrequencyWords (субтитры OpenSubtitles 2018,
'  CC BY-SA 4.0, dict\README.md). Файла нет - частота не учитывается.
'
'  Частота добавляется к цене правок (fixrank.bi): FREQ_COST_PER_DECADE
'  десятых за каждый порядок ранга (ранг 70 - 0,3; 1700 - 0,6;
'  47000 - 0,9), слова нет в списке - FREQ_ABSENT_COST. Так «сечас» -
'  «сейчас» (0,8 + 0,3) идёт заметно впереди «сеча» (0,9 + 1,1).
'
'  Слова всех раскладок лежат в одной хеш-таблице, ключ - номер раскладки
'  и буквы слова в UTF-16.
'
'  Часть LangBarFB (https://github.com/diakin/LangBarFB), лицензия LGPL-3.0
'  (COPYING.LESSER и COPYING в корне репозитория).
' ---------------------------------------------------------------------------

Const FREQ_FILE_NAME = "freq.txt"
Const FREQ_TABLE_SIZE = 262144      ' степень двойки
Const FREQ_MAX_FILL = 180000        ' не больше 70% таблицы
Const FREQ_COST_PER_DECADE = 2
Const FREQ_ABSENT_COST = 11
Const FREQ_MAX_WORD = 64

Dim Shared FreqKeys() As String
Dim Shared FreqRanks() As Long
Dim Shared FreqFill As Long
' число слов частотного словаря раскладки; 0 - словаря нет
Dim Shared FreqWordCount(0 To MAX_LAYOUTS - 1) As Long

' Ключ: номер раскладки и буквы слова в нижнем регистре (по 2 байта)
Private Function FreqKeyOf(ByVal LayoutIdx As Long, TextChars() As UShort, _
        ByVal StartIdx As Long, ByVal CharCount As Long) As String
    Dim LowChars(0 To FREQ_MAX_WORD - 1) As UShort
    Dim CharIdx As Long
    For CharIdx = 0 To CharCount - 1
        LowChars(CharIdx) = TextChars(StartIdx + CharIdx)
    Next
    LbCharLowerBuff(@LowChars(0), CharCount)
    Dim KeyText As String = String(1 + CharCount * 2, 0)
    KeyText[0] = 65 + LayoutIdx
    For CharIdx = 0 To CharCount - 1
        KeyText[1 + CharIdx * 2] = LowChars(CharIdx) And &hFF
        KeyText[2 + CharIdx * 2] = LowChars(CharIdx) Shr 8
    Next
    Return KeyText
End Function

' Ячейка таблицы с ключом KeyText или первая пустая после неё (FNV-1a)
Private Function FreqSlot(ByRef KeyText As String) As Long
    Dim HashValue As ULong = 2166136261UL
    Dim ByteIdx As Long
    For ByteIdx = 0 To Len(KeyText) - 1
        HashValue = (HashValue Xor KeyText[ByteIdx]) * 16777619UL
    Next
    Dim SlotIdx As Long = HashValue And (FREQ_TABLE_SIZE - 1)
    While Len(FreqKeys(SlotIdx)) > 0 AndAlso FreqKeys(SlotIdx) <> KeyText
        SlotIdx = (SlotIdx + 1) And (FREQ_TABLE_SIZE - 1)
    Wend
    Return SlotIdx
End Function

Sub FreqUnload()
    Erase FreqKeys
    Erase FreqRanks
    FreqFill = 0
    Dim LayoutIdx As Long
    For LayoutIdx = 0 To MAX_LAYOUTS - 1
        FreqWordCount(LayoutIdx) = 0
    Next
End Sub

' Читает dict\<код>\freq.txt раскладки LayoutIdx. Возвращает число слов.
Function FreqLoadLayout(ByVal LayoutIdx As Long, ByRef FolderPath As String) As Long
    If LayoutIdx < 0 Or LayoutIdx >= MAX_LAYOUTS Then Return 0
    FreqWordCount(LayoutIdx) = 0
    Dim TextChars() As UShort
    Dim CharCount As Long = SpellReadTextFile(FolderPath & "\" & FREQ_FILE_NAME, TextChars())
    If CharCount <= 0 Then Return 0
    If UBound(FreqKeys) < 0 Then
        ReDim FreqKeys(0 To FREQ_TABLE_SIZE - 1)
        ReDim FreqRanks(0 To FREQ_TABLE_SIZE - 1)
    End If
    Dim WordRank As Long, LineStart As Long, CharIdx As Long
    For CharIdx = 0 To CharCount
        If CharIdx < CharCount AndAlso TextChars(CharIdx) <> 10 Then Continue For
        ' слово - от начала строки до пробела, табуляции или CR
        Dim WordStart As Long = LineStart, WordEnd As Long = LineStart
        LineStart = CharIdx + 1
        While WordEnd < CharIdx AndAlso TextChars(WordEnd) > 32
            WordEnd += 1
        Wend
        If WordEnd = WordStart OrElse TextChars(WordStart) = Asc("#") Then Continue For
        WordRank += 1
        If WordEnd - WordStart > FREQ_MAX_WORD Then Continue For
        If FreqFill >= FREQ_MAX_FILL Then Exit For
        Dim KeyText As String = FreqKeyOf(LayoutIdx, TextChars(), WordStart, WordEnd - WordStart)
        Dim SlotIdx As Long = FreqSlot(KeyText)
        ' повтор слова - остаётся первый, более частый
        If Len(FreqKeys(SlotIdx)) = 0 Then
            FreqKeys(SlotIdx) = KeyText
            FreqRanks(SlotIdx) = WordRank
            FreqFill += 1
            FreqWordCount(LayoutIdx) += 1
        End If
    Next
    Return FreqWordCount(LayoutIdx)
End Function

' Ранг слова в частотном словаре раскладки: 1 - самое частое; -1 - слова
' нет в списке; 0 - у раскладки нет частотного словаря
Function FreqRank(ByVal LayoutIdx As Long, TextChars() As UShort, _
        ByVal StartIdx As Long, ByVal CharCount As Long) As Long
    If LayoutIdx < 0 OrElse LayoutIdx >= MAX_LAYOUTS OrElse FreqWordCount(LayoutIdx) = 0 Then Return 0
    If CharCount <= 0 Or CharCount > FREQ_MAX_WORD Then Return -1
    Dim SlotIdx As Long = FreqSlot(FreqKeyOf(LayoutIdx, TextChars(), StartIdx, CharCount))
    If Len(FreqKeys(SlotIdx)) = 0 Then Return -1
    Return FreqRanks(SlotIdx)
End Function

' Добавка к цене варианта за редкость слова (в десятых); 0 - частотного
' словаря нет
Function FreqCost(ByVal LayoutIdx As Long, TextChars() As UShort, _
        ByVal StartIdx As Long, ByVal CharCount As Long) As Long
    Dim WordRank As Long = FreqRank(LayoutIdx, TextChars(), StartIdx, CharCount)
    If WordRank = 0 Then Return 0
    If WordRank < 0 Then Return FREQ_ABSENT_COST
    Return Int(FREQ_COST_PER_DECADE * Log(WordRank) / Log(10) + 0.0001)
End Function
