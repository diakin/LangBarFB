' ---------------------------------------------------------------------------
'  fixrank.bi - порядок вариантов исправления опечатки.
'
'  Hunspell выдаёт варианты в том порядке, в каком нашёл их правками слова
'  (перестановка, лишняя буква, пропущенная, замена), без оценки похожести:
'  для «превет» первым идёт «преет», «привет» - пятым. Здесь каждый вариант
'  получает цену правок (расстояние Дамерау - Левенштейна с весами), и
'  варианты сортируются по ней; при равной цене остаётся порядок Hunspell.
'
'  Веса (в десятых): замена буквы 10, замена похожей по звуку (е/и, а/о,
'  с/з...) 4, соседней клавиши 6; пропущенная буква 8, в конце слова 10,
'  удвоенная 3; лишняя буква 9, удвоенная 3; перестановка соседних 5.
'  Правка первой буквы - ещё 7 (кроме похожей по звуку замены), вариант
'  из двух слов - ещё 20. Веса подобраны на наборе русских опечаток со
'  словарём ru-RU.
'
'  Автоисправление берёт вариант, только если он дешевле FIXRANK_AUTO_MAX
'  и дешевле второго хотя бы на FIXRANK_AUTO_GAP.
'
'  Часть LangBarFB (https://github.com/diakin/LangBarFB), лицензия LGPL-3.0
'  (COPYING.LESSER и COPYING в корне репозитория).
' ---------------------------------------------------------------------------

#pragma once

#include once "winapi.bi"

Const FIXRANK_SUB = 10
Const FIXRANK_SUB_SIMILAR = 4
Const FIXRANK_SUB_KEY = 6
Const FIXRANK_INS = 8
Const FIXRANK_INS_END = 10
Const FIXRANK_INS_DOUBLE = 3
Const FIXRANK_DEL = 9
Const FIXRANK_DEL_DOUBLE = 3
Const FIXRANK_SWAP = 5
Const FIXRANK_FIRST = 7
Const FIXRANK_SPLIT = 20
Const FIXRANK_AUTO_MAX = 10
Const FIXRANK_AUTO_GAP = 3
Const FIXRANK_MAX_LEN = 64

' группы похожих по звуку букв (UTF-16), 0 - конец группы
Dim Shared FixRankGroups(0 To 43) As UShort = { _
    &h435, &h438, &h44D, &h451, 0, &h430, &h43E, 0, &h438, &h44B, 0, &h435, _
    &h451, 0, &h44C, &h44A, 0, &h448, &h449, 0, &h44F, &h430, 0, &h44E, _
    &h443, 0, &h435, &h439, 0, &h441, &h437, 0, &h434, &h442, 0, &h433, _
    &h43A, 0, &h432, &h444, 0, &h436, &h448, 0}

' коды клавиш (VK) по рядам клавиатуры, 0 - пусто; сдвиг ряда - в четвертях
' клавиши: Q на половину правее 1, A на четверть правее Q, Z на половину правее A
Dim Shared FixRankKeys(0 To 3, 0 To 12) As UByte = { _
    {&hC0, &h31, &h32, &h33, &h34, &h35, &h36, &h37, &h38, &h39, &h30, &hBD, &hBB}, _
    {&h51, &h57, &h45, &h52, &h54, &h59, &h55, &h49, &h4F, &h50, &hDB, &hDD, &h0}, _
    {&h41, &h53, &h44, &h46, &h47, &h48, &h4A, &h4B, &h4C, &hBA, &hDE, &h0, &h0}, _
    {&h5A, &h58, &h43, &h56, &h42, &h4E, &h4D, &hBC, &hBE, &hBF, &h0, &h0, &h0}}
Dim Shared FixRankRowShift(0 To 3) As Long = {0, 2, 3, 5}

' Буквы похожи по звуку (в одной группе)
Private Function FixRankSimilar(ByVal FirstChar As UShort, ByVal SecondChar As UShort) As Long
    Dim GroupStart As Long, ItemIdx As Long
    Dim HasFirst As Long, HasSecond As Long
    For ItemIdx = 0 To UBound(FixRankGroups)
        If FixRankGroups(ItemIdx) = 0 Then
            If HasFirst And HasSecond Then Return 1
            HasFirst = 0 : HasSecond = 0
        Else
            If FixRankGroups(ItemIdx) = FirstChar Then HasFirst = 1
            If FixRankGroups(ItemIdx) = SecondChar Then HasSecond = 1
        End If
    Next
    Return 0
End Function

' Место клавиши буквы в раскладке: ряд и колонка в четвертях; 0 - не нашлась
Private Function FixRankKeyPlace(ByVal CharCode As UShort, ByVal LayoutHandle As UInteger, _
        ByRef RowIdx As Long, ByRef ColumnQuarters As Long) As Long
    Dim KeyInfo As Short = LbVkKeyScanEx(CharCode, Cast(Any Ptr, LayoutHandle))
    If KeyInfo = -1 Then Return 0
    Dim VirtualKey As Long = KeyInfo And &hFF
    Dim ScanRow As Long, ColumnIdx As Long
    For ScanRow = 0 To 3
        For ColumnIdx = 0 To 12
            If FixRankKeys(ScanRow, ColumnIdx) = VirtualKey Then
                RowIdx = ScanRow
                ColumnQuarters = ColumnIdx * 4 + FixRankRowShift(ScanRow)
                Return 1
            End If
        Next
    Next
    Return 0
End Function

' Клавиши букв рядом (соседние в ряду или в соседнем ряду)
Private Function FixRankNearKeys(ByVal FirstChar As UShort, ByVal SecondChar As UShort, _
        ByVal LayoutHandle As UInteger) As Long
    Dim FirstRow As Long, FirstColumn As Long, SecondRow As Long, SecondColumn As Long
    If FixRankKeyPlace(FirstChar, LayoutHandle, FirstRow, FirstColumn) = 0 Then Return 0
    If FixRankKeyPlace(SecondChar, LayoutHandle, SecondRow, SecondColumn) = 0 Then Return 0
    If Abs(FirstRow - SecondRow) > 1 Then Return 0
    Return IIf(Abs(FirstColumn - SecondColumn) <= 4, 1, 0)
End Function

' Цена правок от набранного слова TypedChars(TypedStart..) до варианта
' CandChars(CandStart..); LayoutHandle - раскладка набора (соседние клавиши)
Function FixRankCost(TypedChars() As UShort, ByVal TypedStart As Long, ByVal TypedLength As Long, _
        CandChars() As UShort, ByVal CandStart As Long, ByVal CandLength As Long, _
        ByVal LayoutHandle As UInteger) As Long
    If TypedLength > FIXRANK_MAX_LEN Or CandLength > FIXRANK_MAX_LEN Then Return 999
    Dim Typed(0 To FIXRANK_MAX_LEN) As UShort, Cand(0 To FIXRANK_MAX_LEN) As UShort
    Dim PosIdx As Long
    For PosIdx = 0 To TypedLength - 1
        Typed(PosIdx + 1) = TypedChars(TypedStart + PosIdx)
    Next
    For PosIdx = 0 To CandLength - 1
        Cand(PosIdx + 1) = CandChars(CandStart + PosIdx)
    Next
    If TypedLength > 0 Then LbCharLowerBuff(@Typed(1), TypedLength)
    If CandLength > 0 Then LbCharLowerBuff(@Cand(1), CandLength)

    Dim Dist(0 To FIXRANK_MAX_LEN, 0 To FIXRANK_MAX_LEN) As Long
    Dim RowIdx As Long, ColIdx As Long
    For RowIdx = 0 To TypedLength
        For ColIdx = 0 To CandLength
            If RowIdx = 0 And ColIdx = 0 Then Continue For
            Dim BestCost As Long = 1000000
            Dim StepCost As Long
            ' лишняя буква в набранном
            If RowIdx > 0 Then
                StepCost = FIXRANK_DEL
                If RowIdx >= 2 AndAlso Typed(RowIdx) = Typed(RowIdx - 1) Then StepCost = FIXRANK_DEL_DOUBLE
                If RowIdx < TypedLength AndAlso Typed(RowIdx) = Typed(RowIdx + 1) Then StepCost = FIXRANK_DEL_DOUBLE
                If RowIdx = 1 Then StepCost += FIXRANK_FIRST
                If Dist(RowIdx - 1, ColIdx) + StepCost < BestCost Then BestCost = Dist(RowIdx - 1, ColIdx) + StepCost
            End If
            ' пропущенная буква
            If ColIdx > 0 Then
                StepCost = FIXRANK_INS
                If ColIdx = CandLength And RowIdx = TypedLength Then StepCost = FIXRANK_INS_END
                If ColIdx >= 2 AndAlso Cand(ColIdx) = Cand(ColIdx - 1) Then StepCost = FIXRANK_INS_DOUBLE
                If ColIdx < CandLength AndAlso Cand(ColIdx) = Cand(ColIdx + 1) Then StepCost = FIXRANK_INS_DOUBLE
                If ColIdx = 1 And RowIdx = 0 Then StepCost += FIXRANK_FIRST
                If Dist(RowIdx, ColIdx - 1) + StepCost < BestCost Then BestCost = Dist(RowIdx, ColIdx - 1) + StepCost
            End If
            ' замена
            If RowIdx > 0 And ColIdx > 0 Then
                Dim TypedChar As UShort = Typed(RowIdx), CandChar As UShort = Cand(ColIdx)
                If TypedChar = CandChar Then
                    StepCost = 0
                ElseIf FixRankSimilar(TypedChar, CandChar) Then
                    StepCost = FIXRANK_SUB_SIMILAR
                Else
                    StepCost = IIf(FixRankNearKeys(TypedChar, CandChar, LayoutHandle), FIXRANK_SUB_KEY, FIXRANK_SUB)
                    If RowIdx = 1 Then StepCost += FIXRANK_FIRST
                End If
                If Dist(RowIdx - 1, ColIdx - 1) + StepCost < BestCost Then BestCost = Dist(RowIdx - 1, ColIdx - 1) + StepCost
            End If
            ' перестановка соседних
            If RowIdx > 1 And ColIdx > 1 Then
                If Typed(RowIdx) = Cand(ColIdx - 1) And Typed(RowIdx - 1) = Cand(ColIdx) _
                        And Typed(RowIdx) <> Typed(RowIdx - 1) Then
                    StepCost = FIXRANK_SWAP
                    If RowIdx = 2 Then StepCost += FIXRANK_FIRST
                    If Dist(RowIdx - 2, ColIdx - 2) + StepCost < BestCost Then BestCost = Dist(RowIdx - 2, ColIdx - 2) + StepCost
                End If
            End If
            Dist(RowIdx, ColIdx) = BestCost
        Next
    Next
    Dim TotalCost As Long = Dist(TypedLength, CandLength)
    ' вариант из двух слов (или через дефис), а набрано одно
    Dim CandSplit As Long, TypedSplit As Long
    For PosIdx = 1 To CandLength
        If Cand(PosIdx) = 32 Or Cand(PosIdx) = 45 Then CandSplit = 1
    Next
    For PosIdx = 1 To TypedLength
        If Typed(PosIdx) = 32 Or Typed(PosIdx) = 45 Then TypedSplit = 1
    Next
    If CandSplit And TypedSplit = 0 Then TotalCost += FIXRANK_SPLIT
    Return TotalCost
End Function
