' ---------------------------------------------------------------------------
'  dlg_settings.bi - окно настроек (как у Punto Switcher, только нужные
'  пункты): слева разделы, справа страница раздела.
'
'  Общие            - запуск с Windows, автопереключение (пока только
'                     галка - само автопереключение на этапе 5), флажок
'                     у каретки
'  Горячие клавиши  - четыре действия; «Назначить...» ждёт нажатия
'                     сочетания (его ловит хук, hotkeys.bi)
'  Звуки            - события с галками, файл каждого, сигнал динамика
'
'  Окно правит копию настроек (EditSettings); «OK» и «Применить» переносят
'  её в Settings, пишут ini и вызывают SettingsOnApply.
' ---------------------------------------------------------------------------

#pragma once

#include once "rqlcl.bi"
#include once "../core/winapi.bi"
#include once "../core/config.bi"
#include once "../core/hotkeys.bi"
#include once "../core/sendkeys.bi"

Type SettingsApplyFn As Sub()

Dim Shared SettingsOnApply As SettingsApplyFn
Dim Shared EditSettings As AppSettings
Dim Shared SettingsOpen As Long

Dim Shared SettingsForm As QFORM
Dim Shared SectionList As QLISTBOX
Dim Shared GeneralPage As QPANEL
Dim Shared HotkeysPage As QPANEL
Dim Shared SoundsPage As QPANEL
Dim Shared OkButton As QBUTTON
Dim Shared CancelButton As QBUTTON
Dim Shared ApplyButton As QBUTTON

Dim Shared AutoStartCheck As QCHECKBOX
Dim Shared AutoSwitchCheck As QCHECKBOX
Dim Shared CaretFlagCheck As QCHECKBOX
Dim Shared AutoSwitchNote As QLABEL

Dim Shared HotkeyView As QLISTVIEW
Dim Shared AssignButton As QBUTTON
Dim Shared ClearHotkeyButton As QBUTTON
Dim Shared DefaultHotkeyButton As QBUTTON

Dim Shared SoundsOnCheck As QCHECKBOX
Dim Shared SoundView As QLISTVIEW
Dim Shared SoundFileRadio As QRADIOBUTTON
Dim Shared SoundBeepRadio As QRADIOBUTTON
Dim Shared ChangeSoundButton As QBUTTON
Dim Shared PlaySoundButton As QBUTTON
Dim Shared DefaultSoundButton As QBUTTON
Dim Shared SoundDialog As QOPENDIALOG

' окно «Назначить сочетание»
Dim Shared CaptureForm As QFORM
Dim Shared CaptureLabel As QLABEL
Dim Shared CaptureCancelButton As QBUTTON
Dim Shared CaptureActionIdx As Long

' --- заполнение из EditSettings и обратно ---

Private Sub FillHotkeyView()
    Dim ActionIdx As Long
    For ActionIdx = 0 To HOTKEY_ACTION_COUNT - 1
        Dim ComboText As String = EditSettings.Hotkey(ActionIdx)
        If ComboText = "" Then ComboText = "(нет)"
        HotkeyView.SetSubItem(ActionIdx, 0, ComboText)
    Next
End Sub

Private Function SoundFileShown(ByVal EventIdx As Long) As String
    If EditSettings.SoundFile(EventIdx) = "" Then Return "(нет)"
    Return EditSettings.SoundFile(EventIdx)
End Function

Private Sub FillSoundView()
    Dim EventIdx As Long
    For EventIdx = 0 To SOUND_EVENT_COUNT - 1
        SoundView.Item(EventIdx).Checked = EditSettings.SoundOn(EventIdx)
        SoundView.SetSubItem(EventIdx, 0, SoundFileShown(EventIdx))
    Next
End Sub

Private Sub FillForm()
    AutoStartCheck.Checked = EditSettings.AutoStart
    AutoSwitchCheck.Checked = EditSettings.AutoSwitch
    CaretFlagCheck.Checked = EditSettings.CaretFlag
    SoundsOnCheck.Checked = EditSettings.SoundsOn
    SoundFileRadio.Checked = IIf(EditSettings.SoundBeep = 0, 1, 0)
    SoundBeepRadio.Checked = EditSettings.SoundBeep
    FillHotkeyView()
    FillSoundView()
End Sub

' Галки и переключатели - в EditSettings (сочетания и файлы туда пишут
' сами кнопки)
Private Sub ReadForm()
    EditSettings.AutoStart = IIf(AutoStartCheck.Checked, 1, 0)
    EditSettings.AutoSwitch = IIf(AutoSwitchCheck.Checked, 1, 0)
    EditSettings.CaretFlag = IIf(CaretFlagCheck.Checked, 1, 0)
    EditSettings.SoundsOn = IIf(SoundsOnCheck.Checked, 1, 0)
    EditSettings.SoundBeep = IIf(SoundBeepRadio.Checked, 1, 0)
    Dim EventIdx As Long
    For EventIdx = 0 To SOUND_EVENT_COUNT - 1
        EditSettings.SoundOn(EventIdx) = IIf(SoundView.Item(EventIdx).Checked, 1, 0)
    Next
End Sub

Private Sub ApplyEdits()
    ReadForm()
    Settings = EditSettings
    ConfigSave()
    If SettingsOnApply <> 0 Then SettingsOnApply()
End Sub

' --- кнопки окна ---

Private Sub OnSectionClick()
    Dim SectionIdx As Long = SectionList.ItemIndex
    GeneralPage.Visible = IIf(SectionIdx = 0, 1, 0)
    HotkeysPage.Visible = IIf(SectionIdx = 1, 1, 0)
    SoundsPage.Visible = IIf(SectionIdx = 2, 1, 0)
End Sub

Private Sub OnOkClick()
    ApplyEdits()
    SettingsForm.ModalResult = 1
End Sub

Private Sub OnCancelClick()
    SettingsForm.ModalResult = 2
End Sub

Private Sub OnApplyClick()
    ApplyEdits()
End Sub

' --- горячие клавиши ---

Private Sub OnCaptureCancelClick()
    HotkeyCaptureMode = 0
    CaptureForm.ModalResult = 2
End Sub

' Хук поймал сочетание (сообщение HotkeyCaptureMessage)
Sub SettingsCaptureDone()
    If CaptureForm.Visible = 0 Then Exit Sub
    ' клавиша проглочена - без лишнего нажатия отпущенный Win открыл бы «Пуск»
    If (HotkeyCapturedMods And (KB_MOD_ALT Or KB_MOD_WIN)) <> 0 Then SendKeyTap(LB_VK_MENU_MASK)
    If HotkeyCapturedKey = LB_VK_ESCAPE And HotkeyCapturedMods = 0 Then
        CaptureForm.ModalResult = 2
        Exit Sub
    End If
    Dim ComboText As String = HotkeyFormat(HotkeyCapturedKey, HotkeyCapturedMods)
    ' то же сочетание у другого действия снимается
    Dim ActionIdx As Long
    For ActionIdx = 0 To HOTKEY_ACTION_COUNT - 1
        If ActionIdx <> CaptureActionIdx And EditSettings.Hotkey(ActionIdx) = ComboText Then
            EditSettings.Hotkey(ActionIdx) = ""
        End If
    Next
    EditSettings.Hotkey(CaptureActionIdx) = ComboText
    CaptureForm.ModalResult = 1
End Sub

Private Function SelectedHotkey() As Long
    Dim ActionIdx As Long = HotkeyView.ItemIndex
    If ActionIdx < 0 Or ActionIdx >= HOTKEY_ACTION_COUNT Then Return -1
    Return ActionIdx
End Function

Private Sub OnAssignClick()
    Dim ActionIdx As Long = SelectedHotkey()
    If ActionIdx < 0 Then Exit Sub
    CaptureActionIdx = ActionIdx
    CaptureLabel.Caption = HotkeyActionNames(ActionIdx) & ":" & Chr(13, 10) & Chr(13, 10) _
        & "нажмите сочетание клавиш (Esc - отмена)"
    HotkeyCaptureMode = 1
    CaptureForm.Center
    CaptureForm.ShowModal
    HotkeyCaptureMode = 0
    FillHotkeyView()
End Sub

Private Sub OnClearHotkeyClick()
    Dim ActionIdx As Long = SelectedHotkey()
    If ActionIdx < 0 Then Exit Sub
    EditSettings.Hotkey(ActionIdx) = ""
    FillHotkeyView()
End Sub

Private Sub OnDefaultHotkeyClick()
    Dim ActionIdx As Long
    For ActionIdx = 0 To HOTKEY_ACTION_COUNT - 1
        EditSettings.Hotkey(ActionIdx) = HotkeyDefaults(ActionIdx)
    Next
    FillHotkeyView()
End Sub

' --- звуки ---

Private Function SelectedSound() As Long
    Dim EventIdx As Long = SoundView.ItemIndex
    If EventIdx < 0 Or EventIdx >= SOUND_EVENT_COUNT Then Return -1
    Return EventIdx
End Function

Private Sub OnChangeSoundClick()
    Dim EventIdx As Long = SelectedSound()
    If EventIdx < 0 Then Exit Sub
    SoundDialog.Caption = SoundEventNames(EventIdx)
    SoundDialog.Filter = "Звуки (*.wav)|*.wav|Все файлы (*.*)|*.*"
    SoundDialog.FileName = SoundPath(EditSettings.SoundFile(EventIdx))
    If SoundDialog.Execute() = 0 Then Exit Sub
    EditSettings.SoundFile(EventIdx) = SoundDialog.FileName
    SoundView.SetSubItem(EventIdx, 0, SoundFileShown(EventIdx))
End Sub

Private Sub OnPlaySoundClick()
    Dim EventIdx As Long = SelectedSound()
    If EventIdx < 0 Then Exit Sub
    If SoundBeepRadio.Checked Then
        LbMessageBeep(&hFFFFFFFF)
        Exit Sub
    End If
    Dim FullPath As String = SoundPath(EditSettings.SoundFile(EventIdx))
    If FullPath <> "" Then LbPlaySound(StrPtr(FullPath), 0, LB_SND_FILENAME Or LB_SND_ASYNC Or LB_SND_NODEFAULT)
End Sub

Private Sub OnDefaultSoundClick()
    Dim EventIdx As Long
    For EventIdx = 0 To SOUND_EVENT_COUNT - 1
        EditSettings.SoundFile(EventIdx) = SoundDefaults(EventIdx)
        EditSettings.SoundOn(EventIdx) = 1
    Next
    FillSoundView()
End Sub

Private Sub OnSettingsShow()
    LbSetForegroundWindow(Cast(Any Ptr, SettingsForm.Handle))
End Sub

Private Sub OnCaptureShow()
    LbSetForegroundWindow(Cast(Any Ptr, CaptureForm.Handle))
End Sub

' --- создание окна (один раз, при запуске) ---

Private Sub PlaceButton(ByRef Button As QBUTTON, ByRef ParentCtl As QCONTROL, ByRef Caption As String, _
        ByVal PosX As Long, ByVal PosY As Long, ByVal ButtonWidth As Long)
    Button.Parent = ParentCtl
    Button.Left = PosX : Button.Top = PosY
    Button.Width = ButtonWidth : Button.Height = 25
    Button.Caption = Caption
End Sub

Private Sub PlaceCheck(ByRef Check As QCHECKBOX, ByRef ParentCtl As QCONTROL, ByRef Caption As String, _
        ByVal PosY As Long)
    Check.Parent = ParentCtl
    Check.Left = 8 : Check.Top = PosY : Check.Width = 400
    Check.Caption = Caption
End Sub

Private Sub PreparePage(ByRef Page As QPANEL)
    Page.Parent = SettingsForm
    Page.Left = 172 : Page.Top = 8
    Page.Width = 420 : Page.Height = 344
    Page.BevelOuter = 0
    Page.Caption = ""
End Sub

Sub SettingsCreate()
    SettingsForm.Caption = "Настройки LangBarFB"
    SettingsForm.BorderStyle = 3
    SettingsForm.ClientWidth = 600
    SettingsForm.ClientHeight = 392
    SettingsForm.OnShow = @OnSettingsShow

    SectionList.Parent = SettingsForm
    SectionList.Left = 8 : SectionList.Top = 8
    SectionList.Width = 156 : SectionList.Height = 344
    SectionList.AddItems("Общие", "Горячие клавиши", "Звуки")
    SectionList.OnClick = @OnSectionClick

    PreparePage(GeneralPage)
    PreparePage(HotkeysPage)
    PreparePage(SoundsPage)

    ' Общие
    PlaceCheck(AutoStartCheck, GeneralPage, "Запускать при старте Windows", 8)
    PlaceCheck(AutoSwitchCheck, GeneralPage, "Автопереключение", 36)
    PlaceCheck(CaretFlagCheck, GeneralPage, "Показывать флажок у текстового курсора", 64)
    AutoSwitchNote.Parent = GeneralPage
    AutoSwitchNote.Left = 8 : AutoSwitchNote.Top = 104
    AutoSwitchNote.Caption = "Автопереключение пока не работает: галка только запоминается."

    ' Горячие клавиши
    HotkeyView.Parent = HotkeysPage
    HotkeyView.Left = 0 : HotkeyView.Top = 0
    HotkeyView.Width = 420 : HotkeyView.Height = 300
    HotkeyView.ViewStyle = 3
    HotkeyView.RowSelect = 1
    HotkeyView.ReadOnly = 1
    HotkeyView.HideSelection = 0
    HotkeyView.AddColumns("Действие", "Сочетание")
    HotkeyView.Column(0).Width = 270
    HotkeyView.Column(1).Width = 140
    Dim ItemIdx As Long
    For ItemIdx = 0 To HOTKEY_ACTION_COUNT - 1
        HotkeyView.AddItems(HotkeyActionNames(ItemIdx))
    Next
    HotkeyView.OnDblClick = @OnAssignClick
    PlaceButton(AssignButton, HotkeysPage, "Назначить...", 0, 310, 100)
    PlaceButton(ClearHotkeyButton, HotkeysPage, "Снять", 108, 310, 100)
    PlaceButton(DefaultHotkeyButton, HotkeysPage, "По умолчанию", 216, 310, 110)
    AssignButton.OnClick = @OnAssignClick
    ClearHotkeyButton.OnClick = @OnClearHotkeyClick
    DefaultHotkeyButton.OnClick = @OnDefaultHotkeyClick

    ' Звуки
    SoundsOnCheck.Parent = SoundsPage
    SoundsOnCheck.Left = 0 : SoundsOnCheck.Top = 0 : SoundsOnCheck.Width = 400
    SoundsOnCheck.Caption = "Звуковые эффекты"
    SoundView.Parent = SoundsPage
    SoundView.Left = 0 : SoundView.Top = 28
    SoundView.Width = 420 : SoundView.Height = 200
    SoundView.ViewStyle = 3
    SoundView.CheckBoxes = 1
    SoundView.RowSelect = 1
    SoundView.ReadOnly = 1
    SoundView.HideSelection = 0
    SoundView.AddColumns("Событие", "Файл")
    SoundView.Column(0).Width = 220
    SoundView.Column(1).Width = 190
    For ItemIdx = 0 To SOUND_EVENT_COUNT - 1
        SoundView.AddItems(SoundEventNames(ItemIdx))
    Next
    SoundView.OnDblClick = @OnChangeSoundClick
    SoundFileRadio.Parent = SoundsPage
    SoundFileRadio.Left = 0 : SoundFileRadio.Top = 236 : SoundFileRadio.Width = 400
    SoundFileRadio.Caption = "Проигрывать файлы"
    SoundBeepRadio.Parent = SoundsPage
    SoundBeepRadio.Left = 0 : SoundBeepRadio.Top = 260 : SoundBeepRadio.Width = 400
    SoundBeepRadio.Caption = "Стандартный сигнал Windows"
    PlaceButton(ChangeSoundButton, SoundsPage, "Изменить...", 0, 310, 100)
    PlaceButton(PlaySoundButton, SoundsPage, "Проиграть", 108, 310, 100)
    PlaceButton(DefaultSoundButton, SoundsPage, "По умолчанию", 216, 310, 110)
    ChangeSoundButton.OnClick = @OnChangeSoundClick
    PlaySoundButton.OnClick = @OnPlaySoundClick
    DefaultSoundButton.OnClick = @OnDefaultSoundClick

    ' кнопки окна
    PlaceButton(OkButton, SettingsForm, "OK", 356, 360, 75)
    PlaceButton(CancelButton, SettingsForm, "Отмена", 436, 360, 75)
    PlaceButton(ApplyButton, SettingsForm, "Применить", 516, 360, 76)
    OkButton.Default = 1
    CancelButton.Cancel = 1
    OkButton.OnClick = @OnOkClick
    CancelButton.OnClick = @OnCancelClick
    ApplyButton.OnClick = @OnApplyClick

    ' окно записи сочетания
    CaptureForm.Caption = "Назначить сочетание"
    CaptureForm.BorderStyle = 3
    CaptureForm.ClientWidth = 360
    CaptureForm.ClientHeight = 110
    CaptureForm.OnShow = @OnCaptureShow
    CaptureLabel.Parent = CaptureForm
    CaptureLabel.Left = 12 : CaptureLabel.Top = 12
    CaptureLabel.Width = 336 : CaptureLabel.Height = 56
    CaptureLabel.WordWrap = 1
    PlaceButton(CaptureCancelButton, CaptureForm, "Отмена", 272, 76, 76)
    CaptureCancelButton.OnClick = @OnCaptureCancelClick
End Sub

' Показывает окно настроек; возвращается, когда его закрыли
Sub SettingsShow(ByVal SectionIdx As Long = 0)
    If SettingsOpen Then
        LbSetForegroundWindow(Cast(Any Ptr, SettingsForm.Handle))
        Exit Sub
    End If
    SettingsOpen = 1
    EditSettings = Settings
    FillForm()
    SectionList.ItemIndex = SectionIdx
    OnSectionClick()
    HotkeyView.ItemIndex = 0
    SoundView.ItemIndex = 0
    ' пока окно открыто, сочетания не действуют: их назначают
    HotkeysEnabled = 0
    SettingsForm.Center
    SettingsForm.ShowModal
    HotkeysEnabled = 1
    SettingsOpen = 0
End Sub
