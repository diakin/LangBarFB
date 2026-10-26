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
Dim Shared AboutBaseText As QLABEL
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
    AboutForm.ClientHeight = 222
    AboutForm.OnShow = @OnAboutShow

    AboutTitle.Parent = AboutForm
    AboutTitle.Left = 16 : AboutTitle.Top = 14
    AboutTitle.Font.Size = 14
    AboutTitle.Caption = "LangBarFB"

    AboutVersion.Parent = AboutForm
    AboutVersion.Left = 16 : AboutVersion.Top = 48
    AboutVersion.Caption = Tr("Версия ") & APP_VERSION & Tr(", сборка ") & __DATE_ISO__

    ' строки - отдельными метками: перенос в метке LCL с AutoSize не работает
    AboutText.Parent = AboutForm
    AboutText.Left = 16 : AboutText.Top = 76
    AboutText.Caption = Tr("Переключатель раскладки клавиатуры на FreeBASIC.")

    AboutLink.Parent = AboutForm
    AboutLink.Left = 16 : AboutLink.Top = 96
    AboutLink.Font.Color = &hCC6600
    AboutLink.Cursor = -21
    AboutLink.Caption = APP_HOME_URL
    AboutLink.OnClick = @OnAboutLinkClick

    AboutBaseText.Parent = AboutForm
    AboutBaseText.Left = 16 : AboutBaseText.Top = 130
    AboutBaseText.Caption = Tr("Основан на LangBarXX (AutoHotkey, автор Krot66):")

    AboutBaseLink.Parent = AboutForm
    AboutBaseLink.Left = 16 : AboutBaseLink.Top = 150
    AboutBaseLink.Font.Color = &hCC6600
    AboutBaseLink.Cursor = -21
    AboutBaseLink.Caption = APP_BASE_URL
    AboutBaseLink.OnClick = @OnAboutBaseLinkClick

    AboutOkButton.Parent = AboutForm
    AboutOkButton.Left = 288 : AboutOkButton.Top = 186
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
