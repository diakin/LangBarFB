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
            .Modifiers = KbCurrentModifiers()
        End With
        If KeyEvent.VirtualKey = LB_VK_CAPITAL And KeyEvent.IsInjected = 0 Then
            ' повтор при удержании Caps Lock не переключает
            If KeyEvent.IsKeyUp Then
                KbCapsHeld = 0
            ElseIf KbCapsHeld = 0 Then
                KbCapsHeld = 1
                KbCapsOn Xor= 1
            End If
        End If
        KeyEvent.CapsOn = KbCapsOn
        If KbKeyFilter <> 0 Then KeyEvent.IsSwallowed = KbKeyFilter(KeyEvent)

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
