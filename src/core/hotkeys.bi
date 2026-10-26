' ---------------------------------------------------------------------------
'  hotkeys.bi - горячие клавиши: запись словами, разбор, проверка в хуке.
'
'  Сочетание записывается как в окне настроек Punto Switcher и в ini:
'  "Shift + Break", "Ctrl + Alt + F12". Модификаторы - Ctrl, Alt, Shift,
'  Win (левый и правый не различаются), клавиша - одна, не модификатор.
'
'  HotkeyFilter вызывается в обработчике хука (kbhook.bi): совпавшее
'  нажатие глотается вместе с отпусканием, а окну программы уходит
'  сообщение с номером действия. Ctrl+Break Windows присылает как
'  VK_CANCEL - он приводится к VK_PAUSE, иначе Ctrl + Break не совпадёт.
'
'  Режим записи (окно «Назначить»): следующее нажатие не-модификатора
'  глотается и запоминается в HotkeyCapturedKey / HotkeyCapturedMods.
'
'  Часть LangBarFB (https://github.com/diakin/LangBarFB), лицензия LGPL-3.0
'  (COPYING.LESSER и COPYING в корне репозитория).
' ---------------------------------------------------------------------------

#pragma once

#include once "winapi.bi"
#include once "kbhook.bi"
#include once "config.bi"

Type HotkeyEntry
    VirtualKey As ULong      ' 0 - не назначено
    Modifiers As ULong       ' KB_MOD_...
End Type

Dim Shared HotkeyTable(0 To HOTKEY_ACTION_COUNT - 1) As HotkeyEntry
' 0 - сочетания не действуют (открыто окно настроек)
Dim Shared HotkeysEnabled As Long = 1
Dim Shared HotkeyNotifyWindow As Any Ptr
Dim Shared HotkeyActionMessage As ULong    ' WParam - номер действия
Dim Shared HotkeyCaptureMessage As ULong
Dim Shared HotkeyCaptureMode As Long
Dim Shared HotkeyCapturedKey As ULong
Dim Shared HotkeyCapturedMods As ULong
' клавиша, нажатие которой проглочено: глотаются и её повторы, и отпускание
Dim Shared HotkeyHeldKey As ULong

' --- имена клавиш ---
Const HOTKEY_NAME_COUNT = 34
Dim Shared HotkeyNameKeys(0 To HOTKEY_NAME_COUNT - 1) As ULong = { _
    &h13, &h91, &h14, &h90, &h2C, &h1B, &h09, &h0D, &h08, &h20, _
    &h2D, &h2E, &h24, &h23, &h21, &h22, &h25, &h26, &h27, &h28, _
    &h5D, &h6A, &h6B, &h6D, &h6E, &h6F, &hC0, &hBD, &hBB, &hDB, _
    &hDD, &hDC, &hBA, &hDE}
Dim Shared HotkeyNameTexts(0 To HOTKEY_NAME_COUNT - 1) As ZString * 16 = { _
    "Break", "Scroll Lock", "Caps Lock", "Num Lock", "Print Screen", "Esc", "Tab", "Enter", "Backspace", "Space", _
    "Insert", "Delete", "Home", "End", "Page Up", "Page Down", "Left", "Up", "Right", "Down", _
    "Apps", "Num *", "Num +", "Num -", "Num .", "Num /", "`", "-", "=", "[", _
    "]", "\", ";", "'"}

Function HotkeyKeyName(ByVal VirtualKey As ULong) As String
    Select Case VirtualKey
    Case &h30 To &h39, &h41 To &h5A
        Return Chr(VirtualKey)
    Case &h60 To &h69
        Return "Num " & (VirtualKey - &h60)
    Case &h70 To &h87
        Return "F" & (VirtualKey - &h6F)
    Case &hBC
        Return ","
    Case &hBE
        Return "."
    Case &hBF
        Return "/"
    End Select
    Dim NameIdx As Long
    For NameIdx = 0 To HOTKEY_NAME_COUNT - 1
        If HotkeyNameKeys(NameIdx) = VirtualKey Then Return HotkeyNameTexts(NameIdx)
    Next
    Return "vk" & Right("0" & Hex(VirtualKey), 2)
End Function

' Код клавиши по имени; 0 - имя не известно
Function HotkeyKeyFromName(ByRef KeyName As String) As ULong
    Dim UpperName As String = UCase(Trim(KeyName))
    If UpperName = "" Then Return 0
    If Len(UpperName) = 1 Then
        Select Case Asc(UpperName)
        Case &h30 To &h39, &h41 To &h5A
            Return Asc(UpperName)
        Case Asc(",")
            Return &hBC
        Case Asc(".")
            Return &hBE
        Case Asc("/")
            Return &hBF
        End Select
    End If
    If Left(UpperName, 1) = "F" And Len(UpperName) <= 3 Then
        Dim FunctionNum As Long = ValInt(Mid(UpperName, 2))
        If FunctionNum >= 1 And FunctionNum <= 24 Then Return &h6F + FunctionNum
    End If
    If Left(UpperName, 4) = "NUM " And Len(UpperName) = 5 Then
        Dim DigitChar As Long = Asc(UpperName, 5)
        If DigitChar >= Asc("0") And DigitChar <= Asc("9") Then Return &h60 + DigitChar - Asc("0")
    End If
    If Left(UpperName, 2) = "VK" And Len(UpperName) = 4 Then Return ValUInt("&h" & Mid(UpperName, 3))
    ' имена Punto Switcher и AutoHotkey
    Select Case UpperName
    Case "PAUSE": Return &h13
    Case "SCROLLLOCK": Return &h91
    Case "ESCAPE": Return &h1B
    Case "DEL": Return &h2E
    Case "INS": Return &h2D
    End Select
    Dim NameIdx As Long
    For NameIdx = 0 To HOTKEY_NAME_COUNT - 1
        If UCase(HotkeyNameTexts(NameIdx)) = UpperName Then Return HotkeyNameKeys(NameIdx)
    Next
    Return 0
End Function

Function HotkeyIsModifierKey(ByVal VirtualKey As ULong) As Long
    Select Case VirtualKey
    Case &h10, &h11, &h12, &h5B, &h5C, &hA0 To &hA5
        Return 1
    End Select
    Return 0
End Function

Function HotkeyFormat(ByVal VirtualKey As ULong, ByVal Modifiers As ULong) As String
    If VirtualKey = 0 Then Return ""
    Dim Result As String
    If Modifiers And KB_MOD_CTRL Then Result &= "Ctrl + "
    If Modifiers And KB_MOD_ALT Then Result &= "Alt + "
    If Modifiers And KB_MOD_SHIFT Then Result &= "Shift + "
    If Modifiers And KB_MOD_WIN Then Result &= "Win + "
    Return Result & HotkeyKeyName(VirtualKey)
End Function

' Разбор записи "Ctrl + Alt + F12". 0 - запись пустая или неверная.
' Клавиша "+" пишется как "Num +".
Function HotkeyParse(ByRef HotkeyText As String, ByRef VirtualKey As ULong, ByRef Modifiers As ULong) As Long
    VirtualKey = 0
    Modifiers = 0
    Dim RestText As String = Trim(HotkeyText)
    Do While RestText <> ""
        Dim PlusPos As Long = InStr(RestText, "+")
        ' "Num +" - клавиша, а не разделитель
        If PlusPos > 0 And UCase(Trim(RestText)) = "NUM +" Then PlusPos = 0
        Dim PartText As String
        If PlusPos > 0 Then
            PartText = Trim(Left(RestText, PlusPos - 1))
            RestText = Trim(Mid(RestText, PlusPos + 1))
        Else
            PartText = Trim(RestText)
            RestText = ""
        End If
        Select Case UCase(PartText)
        Case "CTRL", "CONTROL"
            Modifiers Or= KB_MOD_CTRL
        Case "ALT"
            Modifiers Or= KB_MOD_ALT
        Case "SHIFT"
            Modifiers Or= KB_MOD_SHIFT
        Case "WIN"
            Modifiers Or= KB_MOD_WIN
        Case Else
            ' клавиша - последней частью
            If RestText <> "" Then Return 0
            VirtualKey = HotkeyKeyFromName(PartText)
        End Select
    Loop
    Return IIf(VirtualKey <> 0, 1, 0)
End Function

' Таблица для хука - из Settings.Hotkey
Sub HotkeysLoadTable()
    Dim ActionIdx As Long
    For ActionIdx = 0 To HOTKEY_ACTION_COUNT - 1
        With HotkeyTable(ActionIdx)
            If HotkeyParse(Settings.Hotkey(ActionIdx), .VirtualKey, .Modifiers) = 0 Then
                .VirtualKey = 0
                .Modifiers = 0
            End If
        End With
    Next
End Sub

' Вызывается в обработчике хука: 1 - проглотить нажатие
Function HotkeyFilter(ByRef KeyEvent As KbEvent) As Long
    If KeyEvent.IsInjected Then Return 0
    Dim VirtualKey As ULong = KeyEvent.VirtualKey
    If VirtualKey = LB_VK_CANCEL Then VirtualKey = LB_VK_PAUSE

    If KeyEvent.IsKeyUp Then
        If HotkeyHeldKey <> 0 And VirtualKey = HotkeyHeldKey Then
            HotkeyHeldKey = 0
            Return 1
        End If
        Return 0
    End If
    If HotkeyIsModifierKey(VirtualKey) Then Return 0
    ' повтор удерживаемой клавиши: действие уже запущено
    If HotkeyHeldKey <> 0 And VirtualKey = HotkeyHeldKey Then Return 1

    If HotkeyCaptureMode Then
        HotkeyCaptureMode = 0
        HotkeyCapturedKey = VirtualKey
        HotkeyCapturedMods = KeyEvent.Modifiers
        HotkeyHeldKey = VirtualKey
        LbPostMessage(HotkeyNotifyWindow, HotkeyCaptureMessage, 0, 0)
        Return 1
    End If
    If HotkeysEnabled = 0 Then Return 0

    Dim ActionIdx As Long
    For ActionIdx = 0 To HOTKEY_ACTION_COUNT - 1
        If HotkeyTable(ActionIdx).VirtualKey = VirtualKey And _
                HotkeyTable(ActionIdx).Modifiers = KeyEvent.Modifiers Then
            HotkeyHeldKey = VirtualKey
            LbPostMessage(HotkeyNotifyWindow, HotkeyActionMessage, ActionIdx, 0)
            Return 1
        End If
    Next
    Return 0
End Function

' Подключает фильтр к хуку. Сообщения уходят окну NotifyWindow.
Sub HotkeysStart(ByVal NotifyWindow As Any Ptr, ByVal ActionMessage As ULong, ByVal CaptureMessage As ULong)
    HotkeyNotifyWindow = NotifyWindow
    HotkeyActionMessage = ActionMessage
    HotkeyCaptureMessage = CaptureMessage
    HotkeysLoadTable()
    KbKeyFilter = @HotkeyFilter
End Sub
