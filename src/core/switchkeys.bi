' ---------------------------------------------------------------------------
'  switchkeys.bi - переключение раскладки с клавиатуры (этап 2 плана).
'
'  - Одиночный Shift или Ctrl (левый и правый отдельно): нажат и отпущен
'    без других клавиш и без щелчка мыши - следующая, предыдущая или
'    заданная раскладка. Сама клавиша не глотается: Shift+буква и
'    Ctrl+C работают как обычно.
'  - Левый Ctrl / Alt / Win + цифра N - раскладка номер N (как
'    Lang_Select у LangBarXX). Цифра глотается.
'  - Caps Lock: выключен, следующая раскладка, исправление последнего
'    слова, регистр выделенного текста. Shift + Caps Lock при этом
'    переключает Caps Lock как обычно (если включено в настройках).
'
'  SwitchFilter вызывается в обработчике хука; сами действия - в главной
'  программе по сообщениям SwitchSoloMessage и SwitchLayoutMessage.
' ---------------------------------------------------------------------------

#pragma once

#include once "winapi.bi"
#include once "kbhook.bi"
#include once "config.bi"
#include once "layouts.bi"
#include once "hotkeys.bi"
#include once "sendkeys.bi"

Dim Shared SwitchSoloMessage As ULong     ' WParam - номер одиночной клавиши
Dim Shared SwitchLayoutMessage As ULong   ' WParam - номер раскладки, -1 - следующая
' таблица для хука - из Settings (SwitchLoadTable)
Dim Shared SwitchSoloOn(0 To SOLO_KEY_COUNT - 1) As Long
Dim Shared SwitchLangSelect As Long
Dim Shared SwitchCapsMode As Long
Dim Shared SwitchShiftCaps As Long
' нажатая одиночная клавиша-кандидат и число щелчков мыши в тот момент
Dim Shared SwitchSoloKey As ULong
Dim Shared SwitchSoloClicks As ULong
' проглоченная клавиша: её повторы и отпускание тоже глотаются
Dim Shared SwitchHeldKey As ULong

Sub SwitchLoadTable()
    Dim KeyIdx As Long
    For KeyIdx = 0 To SOLO_KEY_COUNT - 1
        SwitchSoloOn(KeyIdx) = IIf(Settings.SoloKeyAction(KeyIdx) <> "", 1, 0)
    Next
    SwitchLangSelect = Settings.LangSelect
    SwitchCapsMode = Settings.CapsMode
    SwitchShiftCaps = Settings.ShiftCaps
    SwitchSoloKey = 0
End Sub

Private Function SwitchPost(ByVal Msg As ULong, ByVal WParam As Integer) As Long
    LbPostMessage(HotkeyNotifyWindow, Msg, Cast(UInteger, WParam), 0)
    Return 1
End Function

' 1 - проглотить нажатие
Function SwitchFilter(ByRef KeyEvent As KbEvent) As Long
    If KeyEvent.IsInjected Then Return 0
    Dim VirtualKey As ULong = KeyEvent.VirtualKey

    ' --- одиночные Shift / Ctrl ---
    If KeyEvent.IsKeyUp Then
        If VirtualKey = SwitchSoloKey Then
            SwitchSoloKey = 0
            If KbMouseClicks = SwitchSoloClicks Then SwitchPost(SwitchSoloMessage, VirtualKey - LB_VK_LSHIFT)
        End If
    ElseIf VirtualKey <> SwitchSoloKey Then
        ' нажатие другой клавиши отменяет одиночное; повтор той же - нет
        SwitchSoloKey = 0
        If VirtualKey >= LB_VK_LSHIFT And VirtualKey <= LB_VK_LSHIFT + SOLO_KEY_COUNT - 1 Then
            If SwitchSoloOn(VirtualKey - LB_VK_LSHIFT) And KeyEvent.Modifiers = 0 Then
                SwitchSoloKey = VirtualKey
                SwitchSoloClicks = KbMouseClicks
            End If
        End If
    End If

    ' --- отпускание и повтор проглоченной клавиши ---
    If SwitchHeldKey <> 0 And VirtualKey = SwitchHeldKey Then
        If KeyEvent.IsKeyUp Then SwitchHeldKey = 0
        Return 1
    End If
    If KeyEvent.IsKeyUp Then Return 0

    ' --- левый Ctrl / Alt / Win + цифра ---
    If SwitchLangSelect <> 0 And VirtualKey >= Asc("1") And VirtualKey <= Asc("9") Then
        Dim NeedMods As ULong, LeftKey As Long
        Select Case SwitchLangSelect
        Case 1
            NeedMods = KB_MOD_CTRL : LeftKey = LB_VK_LCONTROL
        Case 2
            NeedMods = KB_MOD_ALT : LeftKey = LB_VK_LMENU
        Case Else
            NeedMods = KB_MOD_WIN : LeftKey = LB_VK_LWIN
        End Select
        Dim LayoutIdx As Long = VirtualKey - Asc("1")
        If KeyEvent.Modifiers = NeedMods And LayoutIdx < LayoutCount AndAlso _
                (LbGetAsyncKeyState(LeftKey) And &h8000) <> 0 Then
            SwitchHeldKey = VirtualKey
            Return SwitchPost(SwitchLayoutMessage, LayoutIdx)
        End If
    End If

    ' --- Caps Lock ---
    If VirtualKey = LB_VK_CAPITAL And SwitchCapsMode <> CAPS_NORMAL Then
        If SwitchShiftCaps And (KeyEvent.Modifiers And KB_MOD_SHIFT) <> 0 Then Return 0
        SwitchHeldKey = VirtualKey
        Select Case SwitchCapsMode
        Case CAPS_SWITCH
            SwitchPost(SwitchLayoutMessage, -1)
        Case CAPS_UNDO_WORD
            SwitchPost(HotkeyActionMessage, ACTION_UNDO_CONVERT)
        Case CAPS_INVERT_CASE
            SwitchPost(HotkeyActionMessage, ACTION_TOGGLE_CASE)
        End Select
        Return 1
    End If
    Return 0
End Function

' Общий фильтр хука: сначала горячие клавиши (и запись сочетания),
' потом переключение
Function KeyFilterAll(ByRef KeyEvent As KbEvent) As Long
    If HotkeyCaptureMode Then
        SwitchSoloKey = 0
        Return HotkeyFilter(KeyEvent)
    End If
    If HotkeyFilter(KeyEvent) Then
        SwitchSoloKey = 0
        Return 1
    End If
    Return SwitchFilter(KeyEvent)
End Function

' Caps Lock и Num Lock в нужное положение (при запуске и после настроек)
Sub SwitchFixLockKeys()
    ' Caps Lock - по счёту хука: GetKeyState своего потока может отставать
    If Settings.CapsMode <> CAPS_NORMAL And KbCapsOn <> 0 Then
        SendKeyTap(LB_VK_CAPITAL)
    End If
    If Settings.NumLockOn And (LbGetKeyState(LB_VK_NUMLOCK) And 1) = 0 Then
        SendKeyTap(LB_VK_NUMLOCK)
    End If
End Sub

Sub SwitchStart(ByVal SoloMessage As ULong, ByVal LayoutMessage As ULong)
    SwitchSoloMessage = SoloMessage
    SwitchLayoutMessage = LayoutMessage
    SwitchLoadTable()
    KbKeyFilter = @KeyFilterAll
    SwitchFixLockKeys()
End Sub
