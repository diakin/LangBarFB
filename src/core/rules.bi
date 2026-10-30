' ---------------------------------------------------------------------------
'  rules.bi - правила переключения (как «Правила» Punto Switcher).
'
'  Правило - сочетание букв, условие (слово целиком, начало, конец, любая
'  часть слова), учитывать ли регистр и действие: не переключать или
'  переключать. Правила проверяются по порядку, действует первое
'  совпавшее (autoswitch.bi). Слово сравнивается с сочетанием в каждой
'  раскладке: «ghbdtn» и «привет» - одно и то же набранное слово.
'
'  Сравнение идёт в кодировке Windows (CP1251 у русской Windows): буквы
'  языков вне неё (умляуты и т. п.) в сочетании не сохраняются.
'
'  Если автопереключение отменили Break столько раз подряд, сколько
'  указано в настройках, программа предлагает добавить правило «не
'  переключать» для последнего отменённого слова.
'
'  Часть LangBarFB (https://github.com/diakin/LangBarFB), лицензия LGPL-3.0
'  (COPYING.LESSER и COPYING в корне репозитория).
' ---------------------------------------------------------------------------

#pragma once

#include once "winapi.bi"
#include once "config.bi"

Const RULE_MB_SETFOREGROUND = &h10000
Const RULE_MB_TOPMOST = &h40000

' отмены автопереключения подряд и слово, для которого предложить правило
Dim Shared RuleUndoStreak As Long
Dim Shared RuleLastUndone As Long = 1
Dim Shared RuleOfferText As String

' Строка в нижнем регистре (через UTF-16: CharLowerBuffW знает кириллицу)
Function RuleLower(ByRef SourceText As String) As String
    If SourceText = "" Then Return ""
    Dim WideChars(0 To Len(SourceText)) As UShort
    Dim CharCount As Long = LbMultiByteToWideChar(LB_CP_ACP, 0, StrPtr(SourceText), Len(SourceText), _
        Cast(WString Ptr, @WideChars(0)), Len(SourceText) + 1)
    If CharCount <= 0 Then Return SourceText
    LbCharLowerBuff(@WideChars(0), CharCount)
    Dim LowerText As String = String(CharCount * 2, 0)
    Dim ByteCount As Long = LbWideCharToMultiByte(LB_CP_ACP, 0, Cast(WString Ptr, @WideChars(0)), CharCount, _
        StrPtr(LowerText), Len(LowerText), 0, 0)
    Return Left(LowerText, ByteCount)
End Function

' Сочетание правила в слове WordText (WordLower - оно же в нижнем регистре)
Function RuleMatches(ByRef CheckRule As SwitchRule, ByRef WordText As String, ByRef WordLower As String) As Long
    If CheckRule.RuleText = "" Or WordText = "" Then Return 0
    Dim RuleText As String, SubjectText As String
    If CheckRule.MatchCase Then
        RuleText = CheckRule.RuleText
        SubjectText = WordText
    Else
        RuleText = RuleLower(CheckRule.RuleText)
        SubjectText = WordLower
    End If
    Select Case CheckRule.Condition
    Case RULE_WHOLE
        Return IIf(SubjectText = RuleText, 1, 0)
    Case RULE_START
        Return IIf(Left(SubjectText, Len(RuleText)) = RuleText, 1, 0)
    Case RULE_END
        Return IIf(Right(SubjectText, Len(RuleText)) = RuleText, 1, 0)
    Case Else
        Return IIf(InStr(SubjectText, RuleText) > 0, 1, 0)
    End Select
End Function

' Начало слова PrefixText ещё может совпасть с правилом «слово целиком»
' или «начало слова» (проверка на третьей букве)
Function RuleMayMatchStart(ByRef CheckRule As SwitchRule, ByRef PrefixText As String, ByRef PrefixLower As String) As Long
    If CheckRule.RuleText = "" Or PrefixText = "" Then Return 0
    If CheckRule.Condition <> RULE_WHOLE And CheckRule.Condition <> RULE_START Then Return 0
    Dim RuleText As String, SubjectText As String
    If CheckRule.MatchCase Then
        RuleText = CheckRule.RuleText
        SubjectText = PrefixText
    Else
        RuleText = RuleLower(CheckRule.RuleText)
        SubjectText = PrefixLower
    End If
    If Len(RuleText) >= Len(SubjectText) Then Return IIf(Left(RuleText, Len(SubjectText)) = SubjectText, 1, 0)
    ' сочетание короче начала: «слово целиком» уже не совпадёт
    If CheckRule.Condition = RULE_WHOLE Then Return 0
    Return IIf(Left(SubjectText, Len(RuleText)) = RuleText, 1, 0)
End Function

' Правило словами для окна отладки (оно не переводится)
Function RuleDescribe(ByRef CheckRule As SwitchRule) As String
    Return "«" & CheckRule.RuleText & "», " & LCase(RuleConditionNames(CheckRule.Condition)) & ", " _
        & LCase(RuleActionNames(CheckRule.Action))
End Function

' Автопереключение сработало: если прежнее не отменили, счёт отмен подряд
' начинается заново
Sub RuleNoteAutoSwitch()
    If RuleLastUndone = 0 Then RuleUndoStreak = 0
    RuleLastUndone = 0
End Sub

' Автопереключение отменили Break; WordText - слово, каким его вернули
Sub RuleNoteUndo(ByRef WordText As String)
    RuleLastUndone = 1
    RuleUndoStreak += 1
    If Settings.SuggestRule = 0 Or WordText = "" Then Exit Sub
    If RuleUndoStreak < Settings.SuggestCount Then Exit Sub
    RuleUndoStreak = 0
    RuleOfferText = WordText
End Sub

' Правило «не переключать» для слова (слово целиком, без учёта регистра);
' 0 - такое уже есть или правил слишком много
Function RuleAddKeep(ByRef WordText As String) As Long
    Dim RuleIdx As Long
    Dim WordLower As String = RuleLower(WordText)
    For RuleIdx = 0 To Settings.RuleCount - 1
        With Settings.Rule(RuleIdx)
            If .Condition = RULE_WHOLE And .Action = RULE_KEEP And RuleLower(.RuleText) = WordLower Then Return 0
        End With
    Next
    If Settings.RuleCount >= MAX_RULES Then Return 0
    With Settings.Rule(Settings.RuleCount)
        .RuleText = WordText
        .Condition = RULE_WHOLE
        .MatchCase = 0
        .Action = RULE_KEEP
    End With
    Settings.RuleCount += 1
    ConfigSave()
    Return 1
End Function

' Предложить правило, если набралось отмен (после действия, не внутри него).
' Возвращает 1 - правило добавлено.
Function RuleOfferRun() As Long
    If RuleOfferText = "" Then Return 0
    Dim WordText As String = RuleOfferText
    RuleOfferText = ""
    If LbMessageBox(0, Tr("Автопереключение отменено несколько раз подряд.") & Chr(13, 10) _
            & Tr("Добавить правило «Не переключать» для слова") & " «" & WordText & "»?", "LangBarFB", _
            LB_MB_YESNO Or LB_MB_ICONQUESTION Or RULE_MB_SETFOREGROUND Or RULE_MB_TOPMOST) <> LB_IDYES Then Return 0
    Return RuleAddKeep(WordText)
End Function
