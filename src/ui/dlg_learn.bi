' ---------------------------------------------------------------------------
'  dlg_learn.bi - вопрос «добавить слово в словарь?» для слова, которое
'  исправили вручную после исправления опечатки (actions.bi, FixLearn).
'
'  Окно не модальное, поверх всех окон, в правом нижнем углу экрана, и
'  при показе не забирает фокус: набор продолжается в своём окне, а
'  вопрос виден, когда посмотришь на экран. «Да» - слово в словари и
'  user_dict.dic, «Нет» - ничего. Если слов несколько, после ответа
'  показывается следующее. Закрытие крестиком откладывает вопрос: он
'  покажется снова вместе со следующим словом.
'
'  Часть LangBarFB (https://github.com/diakin/LangBarFB), лицензия LGPL-3.0
'  (COPYING.LESSER и COPYING в корне репозитория).
' ---------------------------------------------------------------------------

#pragma once

#include once "rqlcl.bi"
#include once "../core/winapi.bi"
#include once "../core/lang.bi"
#include once "../core/actions.bi"

Const LEARN_FORM_WIDTH = 330
Const LEARN_FORM_HEIGHT = 96
' отступ от правого и нижнего края экрана (панель задач снизу)
Const LEARN_MARGIN_RIGHT = 16
Const LEARN_MARGIN_BOTTOM = 72

Dim Shared LearnForm As QFORM
Dim Shared LearnQuestion As QLABEL
Dim Shared LearnReason As QLABEL
Dim Shared LearnYesButton As QBUTTON
Dim Shared LearnNoButton As QBUTTON

Private Sub LearnHide()
    LearnForm.Close
End Sub

' Показать первый вопрос очереди, не забирая фокус
Sub LearnShowNext()
    If FixLearnAskCount = 0 Then
        LearnHide()
        Exit Sub
    End If
    LearnQuestion.Caption = Tr("Добавить в словарь слово «") & FixLearnAskWord() & Tr("»?")
    LearnReason.Caption = Tr("Исправлено вручную: ") & FixLearnAskReason() _
        & IIf(FixLearnAskCount > 1, Tr(" (ещё вопросов: ") & (FixLearnAskCount - 1) & ")", "")
    Dim ScreenWidth As Long = LbGetSystemMetrics(0)
    Dim ScreenHeight As Long = LbGetSystemMetrics(1)
    Dim PosX As Long = ScreenWidth - LearnForm.Width - LEARN_MARGIN_RIGHT
    Dim PosY As Long = ScreenHeight - LearnForm.Height - LEARN_MARGIN_BOTTOM
    Dim WindowHandle As Any Ptr = Cast(Any Ptr, LearnForm.Handle)
    ' Show делает окно активным - фокус сразу возвращается в окно набора
    Dim TypingWindow As Any Ptr = LbGetForegroundWindow()
    If LbIsWindowVisible(WindowHandle) = 0 Then LearnForm.Show
    ' HWND_TOPMOST (-1) - поверх всех окон
    LbSetWindowPos(WindowHandle, Cast(Any Ptr, -1), PosX, PosY, 0, 0, _
        LB_SWP_NOSIZE Or LB_SWP_NOACTIVATE Or LB_SWP_SHOWWINDOW)
    If TypingWindow <> 0 And TypingWindow <> WindowHandle Then LbSetForegroundWindow(TypingWindow)
End Sub

Private Sub OnLearnYesClick()
    FixLearnAskAnswer(1)
    LearnShowNext()
End Sub

Private Sub OnLearnNoClick()
    FixLearnAskAnswer(0)
    LearnShowNext()
End Sub

Sub LearnCreate()
    LearnForm.Caption = "LangBarFB"
    LearnForm.BorderStyle = 3
    LearnForm.ClientWidth = LEARN_FORM_WIDTH
    LearnForm.ClientHeight = LEARN_FORM_HEIGHT

    LearnQuestion.Parent = LearnForm
    LearnQuestion.Left = 12 : LearnQuestion.Top = 12

    LearnReason.Parent = LearnForm
    LearnReason.Left = 12 : LearnReason.Top = 34

    LearnYesButton.Parent = LearnForm
    LearnYesButton.Left = LEARN_FORM_WIDTH - 172 : LearnYesButton.Top = 60
    LearnYesButton.Width = 76 : LearnYesButton.Height = 25
    LearnYesButton.Caption = Tr("Да")
    LearnYesButton.OnClick = @OnLearnYesClick

    LearnNoButton.Parent = LearnForm
    LearnNoButton.Left = LEARN_FORM_WIDTH - 88 : LearnNoButton.Top = 60
    LearnNoButton.Width = 76 : LearnNoButton.Height = 25
    LearnNoButton.Caption = Tr("Нет")
    LearnNoButton.OnClick = @OnLearnNoClick

    FixLearnAskShow = @LearnShowNext
End Sub
