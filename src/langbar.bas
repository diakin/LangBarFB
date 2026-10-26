' ---------------------------------------------------------------------------
'  LangBarFB - переключатель раскладки на FreeBASIC (перенос LangBarXX).
'
'  Этап 0 - проверка основы на настоящей Windows:
'  - одна копия программы (мьютекс);
'  - значок в области уведомлений с меню «Показать окно» / «Выход»;
'  - хук WH_KEYBOARD_LL в одном потоке с формой RqLcl: нажатия любой
'    программы видны в списке, время работы обработчика хука - в строке
'    состояния;
'  - раскладка активного окна раз в 250 мс.
'  Нажатия не меняются и не глотаются.
'
'  Сборка: build.bat (см. README.md).
' ---------------------------------------------------------------------------

#include once "rqlcl.bi"
#include once "core/winapi.bi"
#include once "core/kbhook.bi"
#include once "core/layouts.bi"
#include once "ui/tray.bi"

Const APP_TITLE = "LangBarFB - этап 0"
Const MUTEX_NAME = "LangBarFB_SingleInstance"
Const KEY_EVENT_MSG = LB_WM_APP + 2
Const MAX_LOG_LINES = 300

Dim Shared MainForm As QFORM
Dim Shared LayoutLabel As QLABEL
Dim Shared HookLabel As QLABEL
Dim Shared EventList As QLISTBOX
Dim Shared ClearButton As QBUTTON
Dim Shared PollTimer As QTIMER
Dim Shared LastLanguageCode As String
Dim Shared LastEventTick As Double

Function HexByte(ByVal Value As ULong) As String
    Return Right("0" & Hex(Value), 2)
End Function

Function DescribeEvent(ByRef KeyEvent As KbEvent) As String
    Dim Direction As String = IIf(KeyEvent.IsKeyUp, "отпущена", "нажата  ")
    Dim LineText As String = Time & "  " & Direction & "  vk=" & HexByte(KeyEvent.VirtualKey) _
        & "  sc=" & HexByte(KeyEvent.ScanCode)
    If (KeyEvent.KeyFlags And LB_LLKHF_EXTENDED) <> 0 Then LineText &= "  ext"
    If (KeyEvent.KeyFlags And LB_LLKHF_ALTDOWN) <> 0 Then LineText &= "  alt"
    If KeyEvent.IsInjected Then LineText &= "  программная"
    Return LineText
End Function

' Сигнал хука: разбираем всё, что накопилось в буфере
Sub OnAppMessage(ByVal Msg As ULong)
    If Msg <> KEY_EVENT_MSG Then Exit Sub
    Dim KeyEvent As KbEvent
    Dim AddedCount As Long
    While KbHookTakeEvent(KeyEvent)
        EventList.AddItems(DescribeEvent(KeyEvent))
        AddedCount += 1
    Wend
    If AddedCount = 0 Then Exit Sub
    LastEventTick = Timer
    While EventList.ItemCount > MAX_LOG_LINES
        EventList.DelItems(0)
    Wend
    EventList.ItemIndex = EventList.ItemCount - 1
End Sub

Sub OnPollTimer()
    Dim Current As LayoutInfo = LayoutOfForeground()
    LayoutLabel.Caption = "Раскладка активного окна: " & Current.LanguageCode _
        & " (0x" & Right("0000" & Hex(Current.LanguageId), 4) & "), класс окна: " & Current.WindowClass
    If Current.LanguageCode <> LastLanguageCode Then
        LastLanguageCode = Current.LanguageCode
        TraySetTip("LangBarFB: " & Current.LanguageCode)
    End If

    Dim HookState As String = IIf(KbHookHandle <> 0, "хук стоит", "хука нет")
    Dim SinceLast As String = "-"
    If LastEventTick > 0 Then SinceLast = Str(Int((Timer - LastEventTick) * 10) / 10) & " с назад"
    HookLabel.Caption = HookState & ";  вызовов: " & KbHookCalls _
        & ";  в обработчике: среднее " & KbHookAverageMicros() & " мкс, наибольшее " & KbMaxHookMicros & " мкс" _
        & ";  потеряно: " & KbLostEvents & ";  последнее нажатие: " & SinceLast
End Sub

Sub OnClearClick()
    EventList.Clear
End Sub

Sub OnTrayShow()
    MainForm.WindowState = 0
    MainForm.Show
    LbSetForegroundWindow(Cast(Any Ptr, MainForm.Handle))
End Sub

Sub OnTrayExit()
    MainForm.Close
End Sub

' --- одна копия ---
Dim Shared InstanceMutex As Any Ptr
InstanceMutex = LbCreateMutex(0, 0, MUTEX_NAME)
If LbGetLastError() = LB_ERROR_ALREADY_EXISTS Then
    LbMessageBox(0, "LangBarFB уже запущен.", APP_TITLE, LB_MB_ICONINFORMATION)
    LbCloseHandle(InstanceMutex)
    End 0
End If

' --- форма ---
MainForm.Caption = APP_TITLE
MainForm.Width = 720
MainForm.Height = 460
MainForm.Center

LayoutLabel.Parent = MainForm
LayoutLabel.Left = 8 : LayoutLabel.Top = 8
LayoutLabel.Caption = "Раскладка активного окна: ..."

HookLabel.Parent = MainForm
HookLabel.Left = 8 : HookLabel.Top = 30
HookLabel.Caption = "..."

ClearButton.Parent = MainForm
ClearButton.Left = 8 : ClearButton.Top = 54 : ClearButton.Width = 100
ClearButton.Caption = "Очистить"
ClearButton.OnClick = @OnClearClick

EventList.Parent = MainForm
EventList.Left = 8 : EventList.Top = 88
EventList.Width = MainForm.ClientWidth - 16
EventList.Height = MainForm.ClientHeight - 96

' --- значок и хук ---
TrayOnShow = @OnTrayShow
TrayOnExit = @OnTrayExit
TrayOnAppMessage = @OnAppMessage
If TrayCreate("LangBarFB") = 0 Then
    LbMessageBox(0, "Не удалось создать значок в области уведомлений.", APP_TITLE, 0)
End If
If KbHookInstall(TrayWindow, KEY_EVENT_MSG) = 0 Then
    LbMessageBox(0, "Не удалось поставить хук клавиатуры (ошибка " & LbGetLastError() & ").", APP_TITLE, 0)
End If

PollTimer.Interval = 250
PollTimer.OnTimer = @OnPollTimer

' цикл сообщений - внутри ShowModal; хук работает, пока открыта форма
MainForm.ShowModal

PollTimer.Enabled = 0
KbHookRemove()
TrayDestroy()
LbCloseHandle(InstanceMutex)
