' ---------------------------------------------------------------------------
'  lang.bi - язык интерфейса: русский (в исходниках) или английский.
'
'  Tr("русская строка") возвращает перевод, если выбран английский, и саму
'  строку, если русский или перевода нет. Таблица - LangFillTable ниже,
'  строки сравниваются целиком. Окно отладки и журнал не переводятся.
'  Язык выбирается при запуске (LangSet); окна настроек строятся один раз,
'  поэтому смена языка действует после перезапуска.
' ---------------------------------------------------------------------------

#pragma once

Const LANG_MAX_PAIRS = 400

Dim Shared LangEnglish As Long
Dim Shared LangRuText(0 To LANG_MAX_PAIRS - 1) As String
Dim Shared LangEnText(0 To LANG_MAX_PAIRS - 1) As String
Dim Shared LangPairCount As Long

Private Sub LangAdd(ByRef RuText As String, ByRef EnText As String)
    If LangPairCount >= LANG_MAX_PAIRS Then Exit Sub
    LangRuText(LangPairCount) = RuText
    LangEnText(LangPairCount) = EnText
    LangPairCount += 1
End Sub

Function Tr(ByRef RuText As String) As String
    If LangEnglish = 0 Then Return RuText
    Dim PairIdx As Long
    For PairIdx = 0 To LangPairCount - 1
        If LangRuText(PairIdx) = RuText Then Return LangEnText(PairIdx)
    Next
    Return RuText
End Function

Private Sub LangFillTable()
    LangAdd(" (ошибка ", " (error ")
    LangAdd(" (папка hunspell LangBarXX)", " (LangBarXX hunspell folder)")
    LangAdd(" бит, сборка ", "-bit, built ")
    LangAdd(" нет функций Hunspell", " has no Hunspell functions")
    LangAdd("(нет)", "(none)")
    LangAdd("(по словарю): если в текущей раскладке его нет, а в другой есть, оно перепечатывается ", "(by dictionary): if it is not in the current layout but is in another one, it is retyped ")
    LangAdd("3 секунды после смены раскладки", "3 seconds after layout change")
    LangAdd("; нет словаря: ", "; no dictionary: ")
    LangAdd("; слов пользователя: ", "; user words: ")
    LangAdd("Hunspell (Hunspell*.dll)|Hunspell*.dll|Все файлы (*.*)|*.*", "Hunspell (Hunspell*.dll)|Hunspell*.dll|All files (*.*)|*.*")
    LangAdd("LangBarFB уже запущен.", "LangBarFB is already running.")
    LangAdd("Shift + Caps Lock включает и выключает Caps Lock", "Shift + Caps Lock turns Caps Lock on and off")
    LangAdd("Автопереключение", "Auto switching")
    LangAdd("Версия ", "Version ")
    LangAdd("Включать Num Lock при запуске", "Turn Num Lock on at startup")
    LangAdd("Выкл.", "Off")
    LangAdd("Выход", "Exit")
    LangAdd("Где лежит ", "Where is ")
    LangAdd("Горячие клавиши", "Hotkeys")
    LangAdd("Действие", "Action")
    LangAdd("Для автопереключения нужны словари Hunspell (", "Auto switching needs Hunspell dictionaries (")
    LangAdd("Для раскладок Windows нет словарей в LangBarFB.", "LangBarFB has no dictionaries for your Windows layouts.")
    LangAdd("Добавить...", "Add...")
    LangAdd("Запускать при старте Windows", "Start with Windows")
    LangAdd("Звуки", "Sounds")
    LangAdd("Звуки (*.wav)|*.wav|Все файлы (*.*)|*.*", "Sounds (*.wav)|*.wav|All files (*.*)|*.*")
    LangAdd("Звуковые эффекты", "Sound effects")
    LangAdd("Изменить...", "Change...")
    LangAdd("Копия текущих настроек сохранится в папке backup рядом с программой.", "A copy of the current settings will be saved to the backup folder next to the program.")
    LangAdd("Левый Alt + 1...9", "Left Alt + 1...9")
    LangAdd("Левый Ctrl + 1...9", "Left Ctrl + 1...9")
    LangAdd("Левый Shift + Backspace", "Left Shift + Backspace")
    LangAdd("Левый Win + 1...9", "Left Win + 1...9")
    LangAdd("НЕ скачано (ошибка 0x", "NOT downloaded (error 0x")
    LangAdd("Назначить сочетание", "Assign hotkey")
    LangAdd("Назначить...", "Assign...")
    LangAdd("Настройки LangBarFB", "LangBarFB settings")
    LangAdd("Настройки сброшены.", "Settings have been reset.")
    LangAdd("Настройки сброшены. Копия прежних: ", "Settings have been reset. Previous settings saved to: ")
    LangAdd("Настройки...", "Settings...")
    LangAdd("Не действует", "Disabled")
    LangAdd("Не переключать слова из заглавных букв (аббревиатуры)", "Do not switch words in capitals (abbreviations)")
    LangAdd("Не переключать слова с цифрами", "Do not switch words with digits")
    LangAdd("Не показывать", "Do not show")
    LangAdd("Не удалось запустить GDI+: флажков не будет.", "Could not start GDI+: flags will not be shown.")
    LangAdd("Не удалось поставить хук клавиатуры (ошибка ", "Could not install the keyboard hook (error ")
    LangAdd("Не удалось создать значок в области уведомлений.", "Could not create the notification area icon.")
    LangAdd("О LangBarFB", "About LangBarFB")
    LangAdd("Обзор...", "Browse...")
    LangAdd("Общие", "General")
    LangAdd("Обычный", "Normal")
    LangAdd("Одиночная клавиша срабатывает, если её нажали и отпустили без других клавиш и щелчков мыши.", "A single key works if it is pressed and released without other keys or mouse clicks.")
    LangAdd("Окно отладки", "Debug window")
    LangAdd("Отмена", "Cancel")
    LangAdd("Папка с hunspell\ и dict\ (пусто - рядом с программой или выше):", "Folder with hunspell\ and dict\ (empty - next to the program or above):")
    LangAdd("Папки hunspell и dict можно скачать вручную: ", "The hunspell and dict folders can be downloaded manually: ")
    LangAdd("Переключатель раскладки клавиатуры на FreeBASIC. Перенос LangBarXX (AutoHotkey, автор Krot66).", "Keyboard layout switcher in FreeBASIC. A port of LangBarXX (AutoHotkey, by Krot66).")
    LangAdd("Переключать слова из одной буквы", "Switch one-letter words")
    LangAdd("Переключение", "Switching")
    LangAdd("Перечитать словари", "Reload dictionaries")
    LangAdd("По умолчанию", "Default")
    LangAdd("Показывать всегда", "Always show")
    LangAdd("Показывать флажок у текстового курсора", "Show a flag at the text cursor")
    LangAdd("Помощь", "Help")
    LangAdd("Последнее слово в другой раскладке", "Last word in another layout")
    LangAdd("Последнее слово исправляют также:", "The last word is also fixed by:")
    LangAdd("Правила автопереключения: при наборе каких слов переключать раскладку, ", "Auto switching rules: which words switch the layout ")
    LangAdd("Правила переключения", "Switching rules")
    LangAdd("Предлагать добавить правило после", "Offer to add a rule after")
    LangAdd("Предыдущая раскладка", "Previous layout")
    LangAdd("Применить", "Apply")
    LangAdd("Проверять начало слова (с третьей буквы)", "Check the start of a word (from the third letter)")
    LangAdd("Проиграть", "Play")
    LangAdd("Проигрывать файлы", "Play files")
    LangAdd("Раскладка по номеру", "Layout by number")
    LangAdd("Регистр", "Case")
    LangAdd("Регистр выделенного текста", "Case of selected text")
    LangAdd("Сброс настроек...", "Reset settings...")
    LangAdd("Сбросить все настройки к значениям по умолчанию?", "Reset all settings to defaults?")
    LangAdd("Сбросить настройки...", "Reset settings...")
    LangAdd("Сейчас: ", "Now: ")
    LangAdd("Скачать их сейчас? Это несколько мегабайт, только языки ваших раскладок.", "Download them now? A few megabytes, only the languages of your layouts.")
    LangAdd("Скачать словари", "Download dictionaries")
    LangAdd("Скачивать нечего: ", "Nothing to download: ")
    LangAdd("Следующая раскладка", "Next layout")
    LangAdd("Слова пользователя", "User words")
    LangAdd("Словари других языков...", "Dictionaries for other languages...")
    LangAdd("Словари других языков: меню «Словари других языков...».", "Other languages: menu item “Dictionaries for other languages...”.")
    LangAdd("Словари уже скачиваются.", "Dictionaries are already downloading.")
    LangAdd("Слово проверяется на третьей букве (по началам слов словаря) и после пробела ", "A word is checked at the third letter (by dictionary word starts) and after a space ")
    LangAdd("Слово, переключение которого отменили Break, - в user_dict.dic", "Words whose switch was undone with Break go to user_dict.dic")
    LangAdd("Снять", "Clear")
    LangAdd("Событие", "Event")
    LangAdd("Сочетание", "Combination")
    LangAdd("Срабатывать по двойному нажатию", "Work on double press")
    LangAdd("Стандартный сигнал Windows", "Standard Windows beep")
    LangAdd("Удалить", "Delete")
    LangAdd("Условие", "Condition")
    LangAdd("Файл", "File")
    LangAdd("Флажок у указателя мыши", "Flag at mouse pointer")
    LangAdd("Язык интерфейса", "Interface language")
    LangAdd("Язык интерфейса сменится после перезапуска. Перезапустить LangBarFB сейчас?", "The interface language changes after a restart. Restart LangBarFB now?")
    LangAdd("Язык меняется после перезапуска программы.", "Takes effect after the program restarts.")
    LangAdd("а при каких нет. Пока не действуют.", "and which do not. Not active yet.")
    LangAdd("в ", "")
    LangAdd("звуки", "sounds")
    LangAdd("и положить рядом с программой (", "and put next to the program (")
    LangAdd("и раскладка меняется. Break сразу после этого возвращает слово.", "and the layout changes. Break right after that restores the word.")
    LangAdd("нажмите сочетание клавиш (Esc - отмена)", "press a key combination (Esc - cancel)")
    LangAdd("не загрузилась ", "could not load ")
    LangAdd("не найдена hunspell\", "not found: hunspell\")
    LangAdd("отмен подряд", "undos in a row")
    LangAdd("скачано", "downloaded")
    LangAdd("скачано из запасного источника (основной: ошибка 0x", "downloaded from the mirror (primary: error 0x")
    LangAdd("словарей нет в ", "no dictionaries in ")
    LangAdd("словари: ", "dictionaries: ")
    LangAdd("Левый Shift", "Left Shift")
    LangAdd("Правый Shift", "Right Shift")
    LangAdd("Левый Ctrl", "Left Ctrl")
    LangAdd("Правый Ctrl", "Right Ctrl")
    LangAdd("Отменить конвертацию раскладки", "Undo layout conversion")
    LangAdd("Сменить раскладку выделенного текста", "Change layout of selected text")
    LangAdd("Сменить регистр выделенного текста", "Change case of selected text")
    LangAdd("Транслитерировать выделенный текст", "Transliterate selected text")
    LangAdd("Автопереключение раскладки", "Layout auto switch")
    LangAdd("Отмена автопереключения", "Auto switch undone")
    LangAdd("Конвертация выделенного текста", "Selected text converted")
    LangAdd("Конвертация текста в буфере", "Clipboard text converted")
End Sub

' LangCode - "ru" или "en"
Sub LangSet(ByRef LangCode As String)
    LangEnglish = IIf(LangCode = "en", 1, 0)
    If LangEnglish And LangPairCount = 0 Then LangFillTable()
End Sub
