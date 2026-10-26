' ---------------------------------------------------------------------------
'  kbhook.bi - низкоуровневый хук клавиатуры (WH_KEYBOARD_LL).
'
'  Windows вызывает обработчик в потоке, который поставил хук, во время
'  выборки сообщений этого потока (у LangBarFB - цикл ShowModal формы
'  RqLcl). Если обработчик работает дольше LowLevelHooksTimeout, система
'  пропускает его, а после нескольких таких случаев молча снимает хук.
'  Поэтому обработчик только кладёт нажатие в кольцевой буфер и посылает
'  окну сообщение; разбор идёт потом, в KbHookTakeEvent.
' ---------------------------------------------------------------------------

#pragma once

#include once "winapi.bi"

Type KbEvent
    VirtualKey As ULong
    ScanCode As ULong
    KeyFlags As ULong
    EventTime As ULong
    IsKeyUp As Long
    IsInjected As Long
End Type

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

Private Function KbHookProc stdcall (ByVal HookCode As Long, _
        ByVal WParam As UInteger, ByVal LParam As Integer) As Integer
    If HookCode = LB_HC_ACTION Then
        Dim StartCount As LongInt, EndCount As LongInt
        LbQueryPerformanceCounter(StartCount)
        Dim HookData As LbKbdLLHookStruct Ptr = Cast(LbKbdLLHookStruct Ptr, LParam)
        Dim NextHead As Long = (KbQueueHead + 1) Mod KB_QUEUE_SIZE
        If NextHead = KbQueueTail Then
            KbLostEvents += 1
        Else
            With KbQueue(KbQueueHead)
                .VirtualKey = HookData->vkCode
                .ScanCode = HookData->scanCode
                .KeyFlags = HookData->flags
                .EventTime = HookData->time
                .IsKeyUp = IIf((HookData->flags And LB_LLKHF_UP) <> 0, 1, 0)
                .IsInjected = IIf((HookData->flags And LB_LLKHF_INJECTED) <> 0, 1, 0)
            End With
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
    End If
    ' этап 0: нажатия не глотаем, только наблюдаем
    Return LbCallNextHookEx(KbHookHandle, HookCode, WParam, LParam)
End Function

' Ставит хук. NotifyWindow получает NotifyMessage после каждого нажатия.
Function KbHookInstall(ByVal NotifyWindow As Any Ptr, ByVal NotifyMessage As ULong) As Long
    If KbHookHandle <> 0 Then Return 1
    KbNotifyWindow = NotifyWindow
    KbNotifyMessage = NotifyMessage
    LbQueryPerformanceFrequency(KbCounterFreq)
    KbHookHandle = LbSetWindowsHookEx(LB_WH_KEYBOARD_LL, @KbHookProc, LbGetModuleHandle(0), 0)
    Return IIf(KbHookHandle <> 0, 1, 0)
End Function

Sub KbHookRemove()
    If KbHookHandle <> 0 Then
        LbUnhookWindowsHookEx(KbHookHandle)
        KbHookHandle = 0
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
