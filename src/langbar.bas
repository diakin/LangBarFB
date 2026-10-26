' ---------------------------------------------------------------------------
'  LangBarFB - переключатель раскладки на FreeBASIC (перенос LangBarXX).
'
'  Сейчас (этап 1, часть 1):
'  - одна копия программы (мьютекс);
'  - значок в области уведомлений - флажок раскладки активного окна:
'    flags\<код>.png (ru-RU.png, en-US.png - как у LangBarXX), а если
'    файла нет - цветной прямоугольник с кодом страны;
'  - щелчок по значку - следующая раскладка в окне, где работали до щелчка;
'  - меню значка: «Окно отладки» (нажатия, хук, раскладка), «Выход»;
'  - хук WH_KEYBOARD_LL: нажатия только наблюдаются, не меняются.
'
'  Сборка: build.bat или unIDE (см. README.md).
' ---------------------------------------------------------------------------

#include once "dir.bi"
#include once "rqlcl.bi"
#include once "core/winapi.bi"
#include once "core/kbhook.bi"
#include once "core/layouts.bi"
#include once "ui/gfx.bi"
#include once "ui/tray.bi"

Const APP_TITLE = "LangBarFB"
Const MUTEX_NAME = "LangBarFB_SingleInstance"
Const KEY_EVENT_MSG = LB_WM_APP + 2
Const MAX_LOG_LINES = 300
Const LB_INFINITE = &hFFFFFFFF

Dim Shared MainForm As QFORM
Dim Shared LayoutLabel As QLABEL
Dim Shared HookLabel As QLABEL
Dim Shared FlagsLabel As QLABEL
Dim Shared EventList As QLISTBOX
Dim Shared ClearButton As QBUTTON
Dim Shared PollTimer As QTIMER

Dim Shared ExitRequested As Long
Dim Shared LastEventTick As Double
' окно, где пользователь работал последним (не панель задач и не наши окна):
' щелчок по значку меняет раскладку в нём
Dim Shared LastUserWindow As Any Ptr
Dim Shared ShownLayout As UInteger
Dim Shared FlagsFolder As String
Dim Shared FlagImages(0 To MAX_LAYOUTS - 1) As Any Ptr

Function HexByte(ByVal Value As ULong) As String
    Return Right("0" & Hex(Value), 2)
End Function

Function FolderExists(ByRef FolderPath As String) As Long
    Return IIf(Dir(FolderPath, fbDirectory) <> "", 1, 0)
End Function

' Папка флажков: flags рядом с exe или на уровень выше (exe в bin\ или src\,
' flags в корне проекта)
Function FindFlagsFolder() As String
    If FolderExists(ExePath & "\flags") Then Return ExePath & "\flags\"
    If FolderExists(ExePath & "\..\flags") Then Return ExePath & "\..\flags\"
    Return ""
End Function

Sub LoadFlags()
    Dim LayoutIdx As Long
    For LayoutIdx = 0 To MAX_LAYOUTS - 1
        GfxFreeImage(FlagImages(LayoutIdx))
    Next
    LayoutsLoad()
    FlagsFolder = FindFlagsFolder()
    Dim FoundCount As Long
    For LayoutIdx = 0 To LayoutCount - 1
        If FlagsFolder <> "" Then
            FlagImages(LayoutIdx) = GfxLoadImage(FlagsFolder & LayoutList(LayoutIdx).LocaleCode & ".png")
        End If
        If FlagImages(LayoutIdx) <> 0 Then FoundCount += 1
    Next
    If FlagsFolder = "" Then
        FlagsLabel.Caption = "Флажки: папки flags нет - текстовые флажки. Раскладок: " & LayoutCount
    Else
        FlagsLabel.Caption = "Флажки: " & FlagsFolder & " - найдено " & FoundCount & " из " & LayoutCount
    End If
End Sub

' Значок трея - флажок раскладки LayoutHandle
Sub ShowLayoutInTray(ByVal LayoutHandle As UInteger)
    Dim LayoutIdx As Long = LayoutIndexOf(LayoutHandle)
    If LayoutIdx < 0 Then
        ' раскладку добавили в Windows после запуска
        LoadFlags()
        LayoutIdx = LayoutIndexOf(LayoutHandle)
        If LayoutIdx < 0 Then Exit Sub
    End If
    Dim IconSize As Long = LbGetSystemMetrics(LB_SM_CXSMICON)
    If IconSize < 16 Then IconSize = 16
    With LayoutList(LayoutIdx)
        TraySetIcon(GfxMakeFlagIcon(FlagImages(LayoutIdx), .ShortLabel, .FlagColor, IconSize))
        TraySetTip(APP_TITLE & ": " & .LocaleCode)
    End With
    ShownLayout = LayoutHandle
End Sub

Function IsOwnOrShellWindow(ByVal WindowHandle As Any Ptr) As Long
    If WindowHandle = 0 Then Return 1
    If WindowHandle = TrayWindow Then Return 1
    If WindowHandle = Cast(Any Ptr, MainForm.Handle) Then Return 1
    Dim ClassBuffer As ZString * 64
    LbGetClassName(WindowHandle, @ClassBuffer, 64)
    Select Case ClassBuffer
    Case "Shell_TrayWnd", "NotifyIconOverflowWindow", "TopLevelWindowForOverflowXamlIsland"
        Return 1
    End Select
    Return 0
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
        ' список ведётся, только пока окно отладки открыто
        If MainForm.Visible Then
            EventList.AddItems(DescribeEvent(KeyEvent))
            AddedCount += 1
        End If
    Wend
    LastEventTick = Timer
    If AddedCount = 0 Then Exit Sub
    While EventList.ItemCount > MAX_LOG_LINES
        EventList.DelItems(0)
    Wend
    EventList.ItemIndex = EventList.ItemCount - 1
End Sub

Sub OnPollTimer()
    Dim ForegroundWindow As Any Ptr = LbGetForegroundWindow()
    If IsOwnOrShellWindow(ForegroundWindow) = 0 Then LastUserWindow = ForegroundWindow

    ' флажок - раскладка окна, где работают; пока открыто меню значка
    ' или окно отладки - раскладка того окна, что было до них
    Dim Current As LayoutInfo = LayoutOfWindow(LastUserWindow)
    If Current.LayoutHandle <> 0 And Current.LayoutHandle <> ShownLayout Then
        ShowLayoutInTray(Current.LayoutHandle)
    End If

    If MainForm.Visible = 0 Then Exit Sub
    LayoutLabel.Caption = "Раскладка окна: " & Current.LanguageCode _
        & " (0x" & Right("0000" & Hex(Current.LanguageId), 4) & "), класс окна: " & Current.WindowClass
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

Sub OnTrayClick()
    LayoutNext(LastUserWindow)
    ' Windows может не дать окну активироваться обратно после щелчка по
    ' значку; раскладку окно получит и без этого
    LbSetForegroundWindow(LastUserWindow)
End Sub

Sub OnTrayShow()
    MainForm.WindowState = 0
    MainForm.Show
    LbSetForegroundWindow(Cast(Any Ptr, MainForm.Handle))
End Sub

Sub OnTrayExit()
    ExitRequested = 1
    LbPostMessage(TrayWindow, LB_WM_NULL, 0, 0)
End Sub

' --- одна копия ---
Dim Shared InstanceMutex As Any Ptr
InstanceMutex = LbCreateMutex(0, 0, MUTEX_NAME)
If LbGetLastError() = LB_ERROR_ALREADY_EXISTS Then
    LbMessageBox(0, "LangBarFB уже запущен.", APP_TITLE, LB_MB_ICONINFORMATION)
    LbCloseHandle(InstanceMutex)
    End 0
End If

' --- окно отладки (закрытие прячет его; программа остаётся в трее) ---
MainForm.Caption = APP_TITLE & " - отладка"
MainForm.Width = 720
MainForm.Height = 480
MainForm.Center

LayoutLabel.Parent = MainForm
LayoutLabel.Left = 8 : LayoutLabel.Top = 8
LayoutLabel.Caption = "Раскладка окна: ..."

HookLabel.Parent = MainForm
HookLabel.Left = 8 : HookLabel.Top = 30
HookLabel.Caption = "..."

FlagsLabel.Parent = MainForm
FlagsLabel.Left = 8 : FlagsLabel.Top = 52
FlagsLabel.Caption = "..."

ClearButton.Parent = MainForm
ClearButton.Left = 8 : ClearButton.Top = 76 : ClearButton.Width = 100
ClearButton.Caption = "Очистить"
ClearButton.OnClick = @OnClearClick

EventList.Parent = MainForm
EventList.Left = 8 : EventList.Top = 110
EventList.Width = MainForm.ClientWidth - 16
EventList.Height = MainForm.ClientHeight - 118

' --- значок, флажки, хук ---
If GfxStart() = 0 Then
    LbMessageBox(0, "Не удалось запустить GDI+: флажков не будет.", APP_TITLE, 0)
End If
LoadFlags()

TrayOnShow = @OnTrayShow
TrayOnClick = @OnTrayClick
TrayOnExit = @OnTrayExit
TrayOnAppMessage = @OnAppMessage
If TrayCreate(APP_TITLE) = 0 Then
    LbMessageBox(0, "Не удалось создать значок в области уведомлений.", APP_TITLE, 0)
End If
LastUserWindow = LbGetForegroundWindow()
If IsOwnOrShellWindow(LastUserWindow) Then LastUserWindow = 0
OnPollTimer()

If KbHookInstall(TrayWindow, KEY_EVENT_MSG) = 0 Then
    LbMessageBox(0, "Не удалось поставить хук клавиатуры (ошибка " & LbGetLastError() & ").", APP_TITLE, 0)
End If

PollTimer.Interval = 250
PollTimer.OnTimer = @OnPollTimer

' --- цикл сообщений: окно не нужно, программа живёт в трее ---
' DoEvents (Application.ProcessMessages) разбирает всё, что пришло, в том
' числе вызовы хука; MsgWaitForMultipleObjects ждёт следующего сообщения
Do
    DoEvents
    If ExitRequested Then Exit Do
    LbMsgWaitForMultipleObjects(0, 0, 0, LB_INFINITE, LB_QS_ALLINPUT)
Loop

PollTimer.Enabled = 0
KbHookRemove()
TrayDestroy()
Dim FlagIdx As Long
For FlagIdx = 0 To MAX_LAYOUTS - 1
    GfxFreeImage(FlagImages(FlagIdx))
Next
GfxStop()
MainForm.Close
LbCloseHandle(InstanceMutex)
