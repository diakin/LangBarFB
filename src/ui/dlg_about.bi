' ---------------------------------------------------------------------------
'  dlg_about.bi - окно «О программе»: версия, дата сборки, разрядность,
'  откуда программа и ссылка на репозиторий.
' ---------------------------------------------------------------------------

#pragma once

#include once "rqlcl.bi"
#include once "../core/winapi.bi"
#include once "../core/lang.bi"

Const APP_VERSION = "0.7"
Const APP_HOME_URL = "https://github.com/diakin/LangBarFB"
Const APP_BASE_URL = "https://github.com/Krot66/LangBarXX"

Dim Shared AboutForm As QFORM
Dim Shared AboutTitle As QLABEL
Dim Shared AboutVersion As QLABEL
Dim Shared AboutText As QLABEL
Dim Shared AboutLink As QLABEL
Dim Shared AboutBaseLink As QLABEL
Dim Shared AboutOkButton As QBUTTON
Dim Shared AboutOpen As Long

Private Sub OnAboutLinkClick()
    LbShellExecute(0, "open", APP_HOME_URL, 0, 0, LB_SW_SHOWNORMAL)
End Sub

Private Sub OnAboutBaseLinkClick()
    LbShellExecute(0, "open", APP_BASE_URL, 0, 0, LB_SW_SHOWNORMAL)
End Sub

Private Sub OnAboutOkClick()
    AboutForm.Close
End Sub

Private Sub OnAboutShow()
    LbSetForegroundWindow(Cast(Any Ptr, AboutForm.Handle))
End Sub

Sub AboutCreate()
    AboutForm.Caption = Tr("О LangBarFB")
    AboutForm.BorderStyle = 3
    AboutForm.ClientWidth = 380
    AboutForm.ClientHeight = 204
    AboutForm.OnShow = @OnAboutShow

    AboutTitle.Parent = AboutForm
    AboutTitle.Left = 16 : AboutTitle.Top = 14
    AboutTitle.Font.Size = 14
    AboutTitle.Caption = "LangBarFB"

    #ifdef __FB_64BIT__
        Const ABOUT_BITS = "64"
    #else
        Const ABOUT_BITS = "32"
    #endif
    AboutVersion.Parent = AboutForm
    AboutVersion.Left = 16 : AboutVersion.Top = 48
    AboutVersion.Caption = Tr("Версия ") & APP_VERSION & ", " & ABOUT_BITS & Tr(" бит, сборка ") & __DATE_ISO__

    AboutText.Parent = AboutForm
    AboutText.Left = 16 : AboutText.Top = 74
    ' AutoSize метки LCL растягивает её по тексту в одну строку - перенос
    ' не срабатывает; поэтому размер задан, а строки разбиты явно
    AboutText.AutoSize = 0
    AboutText.Width = 348 : AboutText.Height = 34
    AboutText.WordWrap = 1
    AboutText.Caption = Tr("Переключатель раскладки клавиатуры на FreeBASIC.") & Chr(13, 10) _
        & Tr("Основан на LangBarXX (AutoHotkey, автор Krot66):")

    AboutBaseLink.Parent = AboutForm
    AboutBaseLink.Left = 16 : AboutBaseLink.Top = 110
    AboutBaseLink.Font.Color = &hCC6600
    AboutBaseLink.Cursor = -21
    AboutBaseLink.Caption = APP_BASE_URL
    AboutBaseLink.OnClick = @OnAboutBaseLinkClick

    AboutLink.Parent = AboutForm
    AboutLink.Left = 16 : AboutLink.Top = 138
    AboutLink.Font.Color = &hCC6600
    AboutLink.Cursor = -21
    AboutLink.Caption = APP_HOME_URL
    AboutLink.OnClick = @OnAboutLinkClick

    AboutOkButton.Parent = AboutForm
    AboutOkButton.Left = 288 : AboutOkButton.Top = 168
    AboutOkButton.Width = 76 : AboutOkButton.Height = 25
    AboutOkButton.Caption = "OK"
    AboutOkButton.Default = 1
    AboutOkButton.Cancel = 1
    AboutOkButton.OnClick = @OnAboutOkClick
End Sub

Sub AboutShow()
    If AboutOpen Then
        LbSetForegroundWindow(Cast(Any Ptr, AboutForm.Handle))
        Exit Sub
    End If
    AboutOpen = 1
    AboutForm.Center
    AboutForm.ShowModal
    AboutOpen = 0
End Sub
