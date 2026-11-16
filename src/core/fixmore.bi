' ---------------------------------------------------------------------------
'  fixmore.bi - варианты исправления опечатки, которых нет у Hunspell.
'
'  Hunspell ищет слова, отличающиеся от набранного одной правкой, а дальше
'  - по похожести n-грамм. Опечатка из двух правок у него теряется: для
'  «очепятка» (ч и п переставлены через букву, я вместо а) он даёт только
'  «пяточка». Здесь перебираются слова в одну и в две правки, но не
'  любые, а частые при наборе:
'  - замена буквы похожей по звуку (группы из fixrank.bi);
'  - замена буквы соседней клавишей (только первой правкой - их много);
'  - лишняя буква, удвоенная буква;
'  - перестановка соседних букв и букв через одну.
'  Каждое получившееся слово проверяется по словарю (HunspellSpell);
'  найденные добавляются к вариантам Hunspell, а порядок потом задаёт цена
'  правок (fixrank.bi).
'
'  Проверок не больше FIXMORE_MAX_CHECKS: для слова из 8 букв их около
'  3-4 тысяч, это единицы миллисекунд. Поиск идёт в главном потоке, пока
'  хук ждёт, поэтому предел нужен для длинных слов.
'
'  Часть LangBarFB (https://github.com/diakin/LangBarFB), лицензия LGPL-3.0
'  (COPYING.LESSER и COPYING в корне репозитория).
' ---------------------------------------------------------------------------

#pragma once

#include once "winapi.bi"
#include once "spell.bi"
#include once "convert.bi"
#include once "fixrank.bi"

Const FIXMORE_MAX_FOUND = 20
Const FIXMORE_MAX_CHECKS = 8000
Const FIXMORE_MAX_NEAR = 8

' состояние одного поиска
Dim Shared FixMoreDict As Any Ptr
Dim Shared FixMoreCaseMode As Long          ' 0 - строчные, 1 - первая заглавная, 2 - все заглавные
Dim Shared FixMoreChecks As Long
' 1 - проверяются слова в одну правку, 2 - в две
Dim Shared FixMorePass As Long
Dim Shared FixMoreTyped(0 To SPELL_MAX_WORD) As UShort
Dim Shared FixMoreTypedLength As Long
' буквы соседних клавиш для каждой позиции набранного слова
Dim Shared FixMoreNear(0 To SPELL_MAX_WORD - 1, 0 To FIXMORE_MAX_NEAR - 1) As UShort
Dim Shared FixMoreNearCount(0 To SPELL_MAX_WORD - 1) As Long
' найденные слова (уже в регистре набранного)
Dim Shared FixMoreFoundChars(0 To FIXMORE_MAX_FOUND - 1, 0 To SPELL_MAX_WORD - 1) As UShort
Dim Shared FixMoreFoundLength(0 To FIXMORE_MAX_FOUND - 1) As Long
Dim Shared FixMoreFoundCount As Long

' Буквы клавиш рядом с клавишей буквы CharCode в раскладке LayoutHandle
Private Function FixMoreNearChars(ByVal CharCode As UShort, ByVal LayoutHandle As UInteger, _
        NearChars() As UShort, ByVal PosIdx As Long) As Long
    Dim CharRow As Long, CharColumn As Long
    If FixRankKeyPlace(CharCode, LayoutHandle, CharRow, CharColumn) = 0 Then Return 0
    Dim NearCount As Long, ScanRow As Long, ColumnIdx As Long
    For ScanRow = CharRow - 1 To CharRow + 1
        If ScanRow < 0 Or ScanRow > 3 Then Continue For
        For ColumnIdx = 0 To 12
            Dim VirtualKey As Long = FixRankKeys(ScanRow, ColumnIdx)
            If VirtualKey = 0 Then Continue For
            Dim KeyColumn As Long = ColumnIdx * 4 + FixRankRowShift(ScanRow)
            If Abs(KeyColumn - CharColumn) > 4 Then Continue For
            Dim NearChar As UShort = KeyCharInLayout(VirtualKey, 0, 0, LayoutHandle)
            If NearChar = 0 OrElse NearChar = CharCode OrElse LbIsCharAlpha(NearChar) = 0 Then Continue For
            If NearCount < FIXMORE_MAX_NEAR Then
                NearChars(PosIdx, NearCount) = NearChar
                NearCount += 1
            End If
        Next
    Next
    Return NearCount
End Function

' Слово WordChars(0..WordLength-1) (строчными) - в регистре набранного,
' проверка по словарю; есть - в список найденных
Private Sub FixMoreTry(WordChars() As UShort, ByVal WordLength As Long)
    If WordLength <= 0 Or WordLength > SPELL_MAX_WORD Then Exit Sub
    If FixMoreChecks >= FIXMORE_MAX_CHECKS Or FixMoreFoundCount >= FIXMORE_MAX_FOUND Then Exit Sub
    Dim CheckBuffer(0 To SPELL_MAX_WORD) As UShort
    Dim CharIdx As Long
    For CharIdx = 0 To WordLength - 1
        CheckBuffer(CharIdx) = WordChars(CharIdx)
    Next
    CheckBuffer(WordLength) = 0
    If FixMoreCaseMode = 1 Then LbCharUpperBuff(@CheckBuffer(0), 1)
    If FixMoreCaseMode = 2 Then LbCharUpperBuff(@CheckBuffer(0), WordLength)
    ' само набранное слово (например, перестановка одинаковых букв) не нужно
    If WordLength = FixMoreTypedLength Then
        Dim SameWord As Long = 1
        For CharIdx = 0 To WordLength - 1
            If CheckBuffer(CharIdx) <> FixMoreTyped(CharIdx) Then SameWord = 0 : Exit For
        Next
        If SameWord Then Exit Sub
    End If
    ' уже найдено
    Dim FoundIdx As Long
    For FoundIdx = 0 To FixMoreFoundCount - 1
        If FixMoreFoundLength(FoundIdx) = WordLength Then
            Dim SameFound As Long = 1
            For CharIdx = 0 To WordLength - 1
                If FixMoreFoundChars(FoundIdx, CharIdx) <> CheckBuffer(CharIdx) Then SameFound = 0 : Exit For
            Next
            If SameFound Then Exit Sub
        End If
    Next
    FixMoreChecks += 1
    If (HunspellSpell(FixMoreDict, Cast(WString Ptr, @CheckBuffer(0))) And &hFF) = 0 Then Exit Sub
    For CharIdx = 0 To WordLength - 1
        FixMoreFoundChars(FixMoreFoundCount, CharIdx) = CheckBuffer(CharIdx)
    Next
    FixMoreFoundLength(FixMoreFoundCount) = WordLength
    FixMoreFoundCount += 1
End Sub

Declare Sub FixMoreEdits(SourceChars() As UShort, ByVal SourceLength As Long, ByVal EditLevel As Long)

' Слово после правки. Сначала (FixMorePass 1) проверяются все слова в одну
' правку, потом (FixMorePass 2) - в две: если проверок не хватит на длинное
' слово, слова в одну правку уже проверены.
Private Sub FixMoreStep(WordChars() As UShort, ByVal WordLength As Long, ByVal EditLevel As Long)
    If EditLevel = 2 Then
        FixMoreTry(WordChars(), WordLength)
    ElseIf FixMorePass = 1 Then
        FixMoreTry(WordChars(), WordLength)
    Else
        FixMoreEdits(WordChars(), WordLength, 2)
    End If
End Sub

' Все частые правки слова SourceChars(0..SourceLength-1); EditLevel 1 -
' первая правка (с заменой на соседнюю клавишу), 2 - вторая
Sub FixMoreEdits(SourceChars() As UShort, ByVal SourceLength As Long, ByVal EditLevel As Long)
    If SourceLength <= 1 Or SourceLength > SPELL_MAX_WORD Then Exit Sub
    Dim WorkChars(0 To SPELL_MAX_WORD) As UShort
    Dim PosIdx As Long, CharIdx As Long, ItemIdx As Long
    For PosIdx = 0 To SourceLength - 1
        If FixMoreChecks >= FIXMORE_MAX_CHECKS Or FixMoreFoundCount >= FIXMORE_MAX_FOUND Then Exit Sub
        Dim SourceChar As UShort = SourceChars(PosIdx)
        For CharIdx = 0 To SourceLength - 1
            WorkChars(CharIdx) = SourceChars(CharIdx)
        Next

        ' замена похожей по звуку: все буквы групп, где есть эта
        Dim GroupStart As Long = 0
        While GroupStart <= UBound(FixRankGroups)
            Dim GroupEnd As Long = GroupStart
            Dim HasChar As Long = 0
            While FixRankGroups(GroupEnd) <> 0
                If FixRankGroups(GroupEnd) = SourceChar Then HasChar = 1
                GroupEnd += 1
            Wend
            If HasChar Then
                For ItemIdx = GroupStart To GroupEnd - 1
                    If FixRankGroups(ItemIdx) = SourceChar Then Continue For
                    WorkChars(PosIdx) = FixRankGroups(ItemIdx)
                    FixMoreStep(WorkChars(), SourceLength, EditLevel)
                Next
                WorkChars(PosIdx) = SourceChar
            End If
            GroupStart = GroupEnd + 1
        Wend

        ' замена соседней клавишей - только первой правкой
        If EditLevel = 1 Then
            For ItemIdx = 0 To FixMoreNearCount(PosIdx) - 1
                WorkChars(PosIdx) = FixMoreNear(PosIdx, ItemIdx)
                FixMoreStep(WorkChars(), SourceLength, EditLevel)
            Next
            WorkChars(PosIdx) = SourceChar
        End If

        ' перестановка с соседней и через одну
        If PosIdx + 1 < SourceLength AndAlso SourceChars(PosIdx + 1) <> SourceChar Then
            WorkChars(PosIdx) = SourceChars(PosIdx + 1)
            WorkChars(PosIdx + 1) = SourceChar
            FixMoreStep(WorkChars(), SourceLength, EditLevel)
            WorkChars(PosIdx) = SourceChar
            WorkChars(PosIdx + 1) = SourceChars(PosIdx + 1)
        End If
        If PosIdx + 2 < SourceLength AndAlso SourceChars(PosIdx + 2) <> SourceChar Then
            WorkChars(PosIdx) = SourceChars(PosIdx + 2)
            WorkChars(PosIdx + 2) = SourceChar
            FixMoreStep(WorkChars(), SourceLength, EditLevel)
            WorkChars(PosIdx) = SourceChar
            WorkChars(PosIdx + 2) = SourceChars(PosIdx + 2)
        End If

        ' лишняя буква
        For CharIdx = PosIdx To SourceLength - 2
            WorkChars(CharIdx) = SourceChars(CharIdx + 1)
        Next
        FixMoreStep(WorkChars(), SourceLength - 1, EditLevel)

        ' удвоенная буква
        If SourceLength < SPELL_MAX_WORD Then
            For CharIdx = PosIdx To SourceLength - 1
                WorkChars(CharIdx + 1) = SourceChars(CharIdx)
            Next
            FixMoreStep(WorkChars(), SourceLength + 1, EditLevel)
        End If
    Next
End Sub

' Ищет варианты для слова TextChars(StartIdx..) в словаре раскладки
' LayoutIdx (набрано в LayoutHandle) и дописывает новые к вариантам
' ResultChars/ResultStarts/ResultLengths (SpellSuggest), ResultCount
' растёт. Возвращает число добавленных; ChecksDone - сколько слов проверено.
Function FixMoreSuggest(ByVal LayoutIdx As Long, ByVal LayoutHandle As UInteger, TextChars() As UShort, _
        ByVal StartIdx As Long, ByVal CharCount As Long, ResultChars() As UShort, ResultStarts() As Long, _
        ResultLengths() As Long, ByRef ResultCount As Long, ByRef ChecksDone As Long) As Long
    ChecksDone = 0
    If LayoutIdx < 0 Or LayoutIdx >= MAX_LAYOUTS Then Return 0
    FixMoreDict = SpellDict(LayoutIdx)
    If FixMoreDict = 0 Or HunspellSpell = 0 Or CharCount <= 1 Or CharCount > SPELL_MAX_WORD Then Return 0

    ' набранное слово, его регистр и строчная копия для правок
    Dim LowerChars(0 To SPELL_MAX_WORD) As UShort
    Dim CharIdx As Long, UpperCount As Long
    For CharIdx = 0 To CharCount - 1
        FixMoreTyped(CharIdx) = TextChars(StartIdx + CharIdx)
        LowerChars(CharIdx) = TextChars(StartIdx + CharIdx)
        If LbIsCharUpper(FixMoreTyped(CharIdx)) Then UpperCount += 1
    Next
    FixMoreTypedLength = CharCount
    LbCharLowerBuff(@LowerChars(0), CharCount)
    FixMoreCaseMode = 0
    If UpperCount = CharCount Then
        FixMoreCaseMode = 2
    ElseIf LbIsCharUpper(FixMoreTyped(0)) Then
        FixMoreCaseMode = 1
    End If
    For CharIdx = 0 To CharCount - 1
        FixMoreNearCount(CharIdx) = FixMoreNearChars(LowerChars(CharIdx), LayoutHandle, FixMoreNear(), CharIdx)
    Next

    FixMoreChecks = 0
    FixMoreFoundCount = 0
    FixMorePass = 1
    FixMoreEdits(LowerChars(), CharCount, 1)
    FixMorePass = 2
    FixMoreEdits(LowerChars(), CharCount, 1)
    ChecksDone = FixMoreChecks

    ' к вариантам Hunspell - те, которых у него нет
    Dim TotalChars As Long
    If ResultCount > 0 Then TotalChars = ResultStarts(ResultCount - 1) + ResultLengths(ResultCount - 1)
    Dim NeedCount As Long = ResultCount + FixMoreFoundCount
    If NeedCount > UBound(ResultStarts) + 1 Then
        ReDim Preserve ResultStarts(0 To NeedCount)
        ReDim Preserve ResultLengths(0 To NeedCount)
    End If
    If TotalChars + FixMoreFoundCount * SPELL_MAX_WORD > UBound(ResultChars) + 1 Then
        ReDim Preserve ResultChars(0 To TotalChars + FixMoreFoundCount * SPELL_MAX_WORD)
    End If
    Dim AddedCount As Long, FoundIdx As Long, ItemIdx As Long
    For FoundIdx = 0 To FixMoreFoundCount - 1
        Dim WordLength As Long = FixMoreFoundLength(FoundIdx)
        Dim AlreadyThere As Long = 0
        For ItemIdx = 0 To ResultCount - 1
            If ResultLengths(ItemIdx) <> WordLength Then Continue For
            AlreadyThere = 1
            For CharIdx = 0 To WordLength - 1
                If ResultChars(ResultStarts(ItemIdx) + CharIdx) <> FixMoreFoundChars(FoundIdx, CharIdx) Then
                    AlreadyThere = 0
                    Exit For
                End If
            Next
            If AlreadyThere Then Exit For
        Next
        If AlreadyThere Then Continue For
        For CharIdx = 0 To WordLength - 1
            ResultChars(TotalChars + CharIdx) = FixMoreFoundChars(FoundIdx, CharIdx)
        Next
        ResultStarts(ResultCount) = TotalChars
        ResultLengths(ResultCount) = WordLength
        TotalChars += WordLength
        ResultCount += 1
        AddedCount += 1
    Next
    Return AddedCount
End Function
