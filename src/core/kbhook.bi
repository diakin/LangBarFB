' ---------------------------------------------------------------------------
'  kbhook.bi - низкоуровневый хук клавиатуры (WH_KEYBOARD_LL).
'
'  Windows вызывает обработчик в потоке, который поставил хук, во время
'  выборки сообщений этого потока (у LangBarFB - цикл ShowModal формы
'  RqLcl). Если обработчик работает дольше LowLevelHooksTimeout, система
'  пропускает его, а после нескольких таких случаев молча снимает хук.
'  Поэтому обработчик только кладёт нажатие в кольцевой буфер и посылает
'  окну сообщение; разбор идёт потом, в KbHookTakeEvent.
'
'  Решить, проглотить ли нажатие, можно только сразу, в обработчике:
'  это делает KbKeyFilter (горячие клавиши, hotkeys.bi) - быстрая
'  проверка по таблице, без вызовов, которые могут ждать.
'  Хук мыши (WH_MOUSE_LL) только сообщает о нажатии кнопки: после щелчка
'  каретка могла уйти, и набранное слово для Break сбрасывается.
'
'  Часть LangBarFB (https://github.com/diakin/LangBarFB), лицензия LGPL-3.0
'  (COPYING.LESSER и COPYING в корне репозитория).
' ---------------------------------------------------------------------------

#pragma once

#include once "winapi.bi"

' модификаторы, нажатые в момент события (KbEvent.Modifiers)
Const KB_MOD_SHIFT = 1
Const KB_MOD_CTRL = 2
Const KB_MOD_ALT = 4
Const KB_MOD_WIN = 8

Type KbEvent
    VirtualKey As ULong
    ScanCode As ULong
    KeyFlags As ULong
    EventTime As ULong
    IsKeyUp As Long
    IsInjected As Long
    Modifiers As ULong       ' KB_MOD_...
    CapsOn As Long           ' Caps Lock включён
    IsSwallowed As Long      ' нажатие проглочено фильтром, окно его не получило
    HeldMask As ULong        ' модификаторы, нажатые до события (KbHeldBit)
End Type

' Фильтр: 1 - проглотить нажатие. Вызывается внутри обработчика хука.
Type KbFilterFn As Function(ByRef KeyEvent As KbEvent) As Long

Const KB_QUEUE_SIZE = 256

Dim Shared KbHookHandle As Any Ptr
Dim Shared KbNotifyWindow As Any Ptr
Dim Shared KbNotifyMessage As ULong
Dim Shared KbQueue(0 To KB_QUEUE_SIZE - 1) As KbEvent
Dim Shared KbQueueHead As Long
Dim Shared KbQueueTail As Long
Dim Shared KbLostEvents As Long
' время в обработчике, микросекунды: наибольшее и сумма
Dim Shared KbMaxHookMicros As Long
Dim Shared KbTotalHookMicros As LongInt
Dim Shared KbHookCalls As LongInt
Dim Shared KbCounterFreq As LongInt
Dim Shared KbKeyFilter As KbFilterFn
' Caps Lock ведётся по нажатиям: состояние чужого окна иначе не узнать
Dim Shared KbCapsOn As Long
Dim Shared KbCapsHeld As Long
Dim Shared KbMouseHookHandle As Any Ptr
Dim Shared KbMouseNotifyMessage As ULong
' число нажатий кнопок мыши: по нему фильтр видит щелчок между событиями
Dim Shared KbMouseClicks As ULong
' где нажали кнопку мыши последний раз (экранные координаты)
Dim Shared KbLastClickPos As LbPoint

' Нажатые модификаторы по событиям хука - по биту на клавишу: LShift,
' RShift, LCtrl, RCtrl, LAlt, RAlt (vk A0..A5), LWin, RWin. GetAsyncKeyState
' внутри хука для только что нажатой клавиши ненадёжен (MSDN,
' LowLevelKeyboardProc), а здесь состояние - до текущего события.
Dim Shared KbHeldMask As ULong
' клавиши, которые пользователь держит, а программа «отпустила» для
' Windows (SendReleaseModifiers): GetAsyncKeyState их не видит, но для
' сочетаний они нажаты
Dim Shared KbReleasedByUs As ULong

' Код клавиши по номеру бита маски
Function KbHeldBitKey(ByVal BitIdx As Long) As Long
    If BitIdx < 6 Then Return &hA0 + BitIdx
    Return &h5B + BitIdx - 6
End Function

Function KbHeldBit(ByVal VirtualKey As ULong) As ULong
    Select Case VirtualKey
    Case &hA0 To &hA5
        Return 1 Shl (VirtualKey - &hA0)
    Case &h5B
        Return &h40
    Case &h5C
        Return &h80
    End Select
    Return 0
End Function

' Модификаторы KB_MOD_... по маске нажатых клавиш
Function KbModifiersOfMask(ByVal HeldMask As ULong) As ULong
    Dim Modifiers As ULong
    If HeldMask And &h03 Then Modifiers Or= KB_MOD_SHIFT
    If HeldMask And &h0C Then Modifiers Or= KB_MOD_CTRL
    If HeldMask And &h30 Then Modifiers Or= KB_MOD_ALT
    If HeldMask And &hC0 Then Modifiers Or= KB_MOD_WIN
    Return Modifiers
End Function

' Отпускание могло пройти мимо хука (блокировка Win+L, окно UAC): бит
' клавиши, которая по GetAsyncKeyState уже отпущена, снимается. Клавиша
' текущего события (ExceptBit) не проверяется.
Private Sub KbDropReleasedKeys(ByVal ExceptBit As ULong)
    If KbHeldMask = 0 Then Exit Sub
    Dim BitIdx As Long
    For BitIdx = 0 To 7
        Dim KeyBit As ULong = 1 Shl BitIdx
        If (KbHeldMask And KeyBit) <> 0 And KeyBit <> ExceptBit And (KbReleasedByUs And KeyBit) = 0 Then
            Dim VirtualKey As Long = KbHeldBitKey(BitIdx)
            If (LbGetAsyncKeyState(VirtualKey) And &h8000) = 0 Then KbHeldMask And= Not KeyBit
        End If
    Next
End Sub

Private Function KbIsKeyDown(ByVal VirtualKey As Long) As Long
    Return IIf((LbGetAsyncKeyState(VirtualKey) And &h8000) <> 0, 1, 0)
End Function

' Модификаторы, нажатые сейчас (до текущего события)
Function KbCurrentModifiers() As ULong
    Dim Modifiers As ULong
    If KbIsKeyDown(LB_VK_SHIFT) Then Modifiers Or= KB_MOD_SHIFT
    If KbIsKeyDown(LB_VK_CONTROL) Then Modifiers Or= KB_MOD_CTRL
    If KbIsKeyDown(LB_VK_MENU) Then Modifiers Or= KB_MOD_ALT
    If KbIsKeyDown(LB_VK_LWIN) Or KbIsKeyDown(LB_VK_RWIN) Then Modifiers Or= KB_MOD_WIN
    Return Modifiers
End Function

Private Function KbHookProc stdcall (ByVal HookCode As Long, _
        ByVal WParam As UInteger, ByVal LParam As Integer) As Integer
    If HookCode = LB_HC_ACTION Then
        Dim StartCount As LongInt, EndCount As LongInt
        LbQueryPerformanceCounter(StartCount)
        Dim HookData As LbKbdLLHookStruct Ptr = Cast(LbKbdLLHookStruct Ptr, LParam)
        Dim KeyEvent As KbEvent
        With KeyEvent
            .VirtualKey = HookData->vkCode
            .ScanCode = HookData->scanCode
            .KeyFlags = HookData->flags
            .EventTime = HookData->time
            .IsKeyUp = IIf((HookData->flags And LB_LLKHF_UP) <> 0, 1, 0)
            .IsInjected = IIf((HookData->flags And LB_LLKHF_INJECTED) <> 0, 1, 0)
        End With
        KeyEvent.CapsOn = KbCapsOn
        Dim HeldBit As ULong = KbHeldBit(KeyEvent.VirtualKey)
        KbDropReleasedKeys(HeldBit)
        KeyEvent.HeldMask = KbHeldMask
        KeyEvent.Modifiers = KbModifiersOfMask(KbHeldMask)
        ' маска - только то, что держит пользователь: программные нажатия
        ' и отпускания её не меняют
        If HeldBit <> 0 And KeyEvent.IsInjected = 0 Then
            If KeyEvent.IsKeyUp Then
                KbHeldMask And= Not HeldBit
                KbReleasedByUs And= Not HeldBit
            Else
                KbHeldMask Or= HeldBit
            End If
        End If
        If KbKeyFilter <> 0 Then KeyEvent.IsSwallowed = KbKeyFilter(KeyEvent)
        ' Caps Lock переключается, только если нажатие дошло до Windows
        If KeyEvent.VirtualKey = LB_VK_CAPITAL And KeyEvent.IsSwallowed = 0 Then
            ' повтор при удержании Caps Lock не переключает
            If KeyEvent.IsKeyUp Then
                KbCapsHeld = 0
            ElseIf KbCapsHeld = 0 Then
                KbCapsHeld = 1
                KbCapsOn Xor= 1
            End If
        End If

        Dim NextHead As Long = (KbQueueHead + 1) Mod KB_QUEUE_SIZE
        If NextHead = KbQueueTail Then
            KbLostEvents += 1
        Else
            KbQueue(KbQueueHead) = KeyEvent
            KbQueueHead = NextHead
            If KbNotifyWindow <> 0 Then LbPostMessage(KbNotifyWindow, KbNotifyMessage, 0, 0)
        End If
        LbQueryPerformanceCounter(EndCount)
        If KbCounterFreq > 0 Then
            Dim SpentMicros As Long = CLng((EndCount - StartCount) * 1000000 \ KbCounterFreq)
            If SpentMicros > KbMaxHookMicros Then KbMaxHookMicros = SpentMicros
            KbTotalHookMicros += SpentMicros
        End If
        KbHookCalls += 1
        ' проглоченное нажатие дальше не идёт: ни другим хукам, ни окну
        If KeyEvent.IsSwallowed Then Return 1
    End If
    Return LbCallNextHookEx(KbHookHandle, HookCode, WParam, LParam)
End Function

' Ставит хук. NotifyWindow получает NotifyMessage после каждого нажатия.
Function KbHookInstall(ByVal NotifyWindow As Any Ptr, ByVal NotifyMessage As ULong) As Long
    If KbHookHandle <> 0 Then Return 1
    KbNotifyWindow = NotifyWindow
    KbNotifyMessage = NotifyMessage
    LbQueryPerformanceFrequency(KbCounterFreq)
    KbCapsOn = LbGetKeyState(LB_VK_CAPITAL) And 1
    KbHookHandle = LbSetWindowsHookEx(LB_WH_KEYBOARD_LL, @KbHookProc, LbGetModuleHandle(0), 0)
    Return IIf(KbHookHandle <> 0, 1, 0)
End Function

Sub KbHookRemove()
    If KbHookHandle <> 0 Then
        LbUnhookWindowsHookEx(KbHookHandle)
        KbHookHandle = 0
    End If
End Sub

Private Function KbMouseHookProc stdcall (ByVal HookCode As Long, _
        ByVal WParam As UInteger, ByVal LParam As Integer) As Integer
    If HookCode = LB_HC_ACTION Then
        Select Case CULng(WParam)
        Case LB_WM_LBUTTONDOWN, LB_WM_RBUTTONDOWN, LB_WM_MBUTTONDOWN
            KbMouseClicks += 1
            ' MSLLHOOKSTRUCT начинается с POINT
            KbLastClickPos = *Cast(LbPoint Ptr, LParam)
            If KbNotifyWindow <> 0 Then LbPostMessage(KbNotifyWindow, KbMouseNotifyMessage, 0, 0)
        End Select
    End If
    Return LbCallNextHookEx(KbMouseHookHandle, HookCode, WParam, LParam)
End Function

' Хук мыши: окну хука клавиатуры приходит NotifyMessage при нажатии кнопки.
' Ставить после KbHookInstall.
Function KbMouseHookInstall(ByVal NotifyMessage As ULong) As Long
    If KbMouseHookHandle <> 0 Then Return 1
    KbMouseNotifyMessage = NotifyMessage
    KbMouseHookHandle = LbSetWindowsHookEx(LB_WH_MOUSE_LL, @KbMouseHookProc, LbGetModuleHandle(0), 0)
    Return IIf(KbMouseHookHandle <> 0, 1, 0)
End Function

Sub KbMouseHookRemove()
    If KbMouseHookHandle <> 0 Then
        LbUnhookWindowsHookEx(KbMouseHookHandle)
        KbMouseHookHandle = 0
    End If
End Sub

' Достаёт следующее нажатие из буфера; 0 - буфер пуст
Function KbHookTakeEvent(ByRef EventOut As KbEvent) As Long
    If KbQueueTail = KbQueueHead Then Return 0
    EventOut = KbQueue(KbQueueTail)
    KbQueueTail = (KbQueueTail + 1) Mod KB_QUEUE_SIZE
    Return 1
End Function

Function KbHookAverageMicros() As Long
    If KbHookCalls = 0 Then Return 0
    Return CLng(KbTotalHookMicros \ KbHookCalls)
End Function
