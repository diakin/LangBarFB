# Словари Hunspell

Файлы папок `dict` и `hunspell` взяты без изменений из установщика LangBarXX 1.8.4 (https://github.com/Krot66/LangBarXX/releases/tag/v1.8.4, полная версия). LangBarFB скачивает их отсюда («Скачать словари»), только для языков раскладок Windows.

| Папка | Что указано в файлах о лицензии |
| --- | --- |
| `hunspell` | NHunspell: «Copyright (C) 2009 maierhofer software, Lazlo Nemeth and the contributing authors» (свойства DLL). Лицензия в файлах не указана — уточнить |
| `dict/ru-RU` | Alexander I. Lebedev, BSD-подобная лицензия — текст в `README_ru_RU.txt` (его нужно прикладывать при распространении) |
| `dict/be-BY` | CC BY-SA 4.0 или LGPLv3 — `README_be_BY.txt` |
| `dict/de-DE` | Björn Jacke, GPLv2 / GPLv3 (заголовок `de_DE.aff`) |
| `dict/fr-FR` | MPL 2.0 (заголовок `fr_FR.aff`) |
| `dict/en-US` | SCOWL, Kevin Atkinson и др. — `README_en_US.txt` |
| `dict/uk-UA` | MPL 1.1 — `README_uk_UA.txt` |

Файлы `README_*.txt` взяты из репозитория словарей LibreOffice (https://github.com/LibreOffice/dictionaries, ветка master) — версии словарей там могут быть новее, чем здесь.

Запасные источники при скачивании (если файл не скачался из этого репозитория): словари — тот же репозиторий LibreOffice; библиотека — пакет NHunspell 1.2.5554.16953 на nuget.org (DLL достаётся из zip скриптом Shell.Application). У этой версии NHunspell другой вызов HunspellInit (содержимое файлов вместо путей); LangBarFB определяет его по версии DLL.

Словари других языков: папка словарей LibreOffice на Google Drive (ссылка из LangBarXX, пункт меню «Словари других языков...»). Пара `.aff` + `.dic` кладётся в `dict\<код раскладки>\`.
