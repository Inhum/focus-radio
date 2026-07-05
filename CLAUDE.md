# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Среда

- ОС: macOS (Darwin), shell zsh.

## Что это

**Focus Radio** — однофайловое меню-бар приложение для macOS (AppKit + AVFoundation + MediaPlayer). Воспроизводит онлайн-радио для фокусной работы. 18 станций, 4 провайдера: SomaFM (10), Radio Paradise (3), NTS Mixtapes (4), Nightwave Plaza (1). URL первых 7 SomaFM-станций обновляются на старте через `.pls`; остальные SomaFM — со статическими зеркалами ice4/ice6/ice2.

Весь код лежит в `radio.swift` (единственный source-файл). Всё остальное вокруг — обвязка `.app`-бандла и открытого репозитория (Info.plist, скрипты, шаблоны GitHub).

## Сборка и запуск

Всё делается через скрипты в `scripts/`, без Xcode — нужны только Command Line Tools (`xcode-select --install`).

```sh
./scripts/run.sh           # debug-сборка + запуск с логами в терминале (Ctrl+C = стоп)
./scripts/build.sh         # release-сборка → build/FocusRadio.app
./scripts/test.sh          # сборка + --test-all по всем станциям (exit != 0, если не все играют)
./scripts/package.sh       # release + build/FocusRadio-<версия>.dmg с ярлыком /Applications
./scripts/make-icon.sh     # перегенерить Resources/FocusRadio.icns + docs/icon.png
./scripts/make-cert.sh     # один раз: self-signed сертификат «Focus Radio Self-Signed» в login keychain
```

`build.sh` подписывает бандл сертификатом «Focus Radio Self-Signed», если он есть в связке ключей (стабильная идентичность → выданные разрешения держатся между сборками), иначе откатывается на ad-hoc — поэтому сторонние сборщики без сертификата собирают без ошибок. Self-signed **не** снимает Gatekeeper-предупреждение при первом запуске (нужен Apple Developer ID + нотаризация).

Ручной вызов самотеста одной станции по индексу (0..13):

```sh
./build/FocusRadio.app/Contents/MacOS/FocusRadio --test-one 5
```

Юнит-тестов нет, линтеров нет — единственный «зелёный» сигнал это `./scripts/test.sh` с exit 0. Но `--test-all` бьёт по живым Icecast-серверам, часть станций периодически отказывают из-за сети/гео-блока (см. «Известные мёртвые URL» ниже) — поэтому в CI самотест **не** запускается, только сборка.

## Архитектура `radio.swift`

Чтобы понять поведение приложения, важны несколько связок, разнесённых по файлу:

- **Цепочка фоллбэков:** `tryCurrentURL` → `watchdog` (8 с MP3 / 12 с AAC) → `tryNextURL` идёт по `station.urls`. Когда список исчерпан — пробуем `originalStationURLs[idx]` (хардкодный снимок до PLS-обновления), затем повторяем всю станцию `maxStationRetries` раз. Это отдельный механизм от per-URL фоллбэка.
- **`automaticallyWaitsToMinimizeStalling = true` (дефолт) — НЕ трогать.** С `false` плеер играет без достаточного буфера и на ряде потоков (Radio Paradise, NTS/radiomast) навсегда виснет на `currentTime=0` — те же URL при этом играют в QuickTime (тоже AVFoundation). Именно `false` когда-то приняли за гео-блок и ошибочно выпилили RP/NTS в 0.2.0. С `true` играют все станции.
- **Детектор реального воспроизведения** (`pollTimer`, 0.5 с): `timeControlStatus == .playing` — только *намерение*. Реальный сигнал — рост `accessLog().events.last.numberOfBytesTransferred` **или** продвижение `currentTime()`. Статический `loadedTimeRanges` в признак игры НЕ входит: замёрзший поток набирает стартовый буфер, но `currentTime` стоит — это давало ложный «зелёный». Нужны два подряд успешных опроса. У некоторых серверов (RP/NTS) `accessLog` не обновляет байты — тогда единственный признак это рост `currentTime`.
- **PLS race:** `fetchSomaFMURLs` обновляет `stations[idx].urls` асинхронно. `startPlayingCurrent` → `waitForPLS(idx, timeout: 1.5)` ждёт результата на главном потоке через `Timer` (не `DispatchQueue.main.asyncAfter` — тот не дренируется под `RunLoop.main.run(until:)`).
- **`teardownPlayer`:** единая точка снятия плеера, KVO и notification-обозревателей. Любая транзакция (stop, выбор другой станции, фоллбэк, выход) обязана идти через неё, иначе остаются стейл-обозреватели и «переключение туда-обратно» даёт тишину. Особенно важен `replaceCurrentItem(with: nil)` перед `player = nil`.
- **Режимы запуска:** `--test-all` итерирует станции через цепочку `Timer`-ов, не блокируя главный run loop. Гонка с AVPlayer возникает, если попытаться драйвить run loop вручную через `RunLoop.main.run(until:)` — AVPlayer перестаёт обращаться по сети. `testWaitTimer` регистрируется в `.common` mode (`RunLoop.main.add(timer, forMode: .common)`) — в `.default` mode AVPlayer может удерживать RunLoop в другом mode и таймер перестаёт тикать, что ведёт к elapsed=500s+ при 40s-таймауте.
- **Закрытие поповера в `.accessory`-приложении:** `popover.behavior = .transient` *не* закрывает окно при клике в другом приложении или по рабочему столу — только при кликах внутри своего процесса. Фикс — глобальный `NSEvent.addGlobalMonitorForEvents` на `.leftMouseDown`/`.rightMouseDown`, ставится в `togglePopover` при показе и снимается в `popoverDidClose`. Не упрощать обратно к одному `.transient`: визуально работает в окне Xcode, ломается в реальном использовании.
- **Media keys / Now Playing:** `setupMediaControls` регистрирует `togglePlayPause`/`play`/`pause` в `MPRemoteCommandCenter`, а `updateNowPlaying(playing:)` пишет/сбрасывает `MPNowPlayingInfoCenter.default().nowPlayingInfo` при старте реального воспроизведения (`declaredPlaying = true`) и в `stopPlaying`. macOS маршрутизирует физическую Play/Pause клавишу тому приложению, чья карточка сейчас в Now Playing — то есть нам, пока играем. Если забыть сбросить `nowPlayingInfo` в `stopPlaying`, система будет считать, что мы всё ещё играем, и кнопка будет доставаться нам даже когда стоим на паузе.
- **Персистенс через `UserDefaults`:** ключи `focusRadio.stationIdx` (Int) и `focusRadio.volume` (Float). Сохраняем в `selectStation` и `volumeChanged`; загружаем в `applicationDidFinishLaunching` **до** создания UI (но после раннего возврата из test-режимов, чтобы `--test-all` не завёлся с прошлой громкостью 0.05).
- **Локализация (en/ru):** все UI-строки идут через `L("ключ", args…)` (обёртка над `NSLocalizedString`); значения — в `Resources/{en,ru}.lproj/Localizable.strings`. `build.sh` копирует `*.lproj` в бандл, `Info.plist` объявляет `CFBundleLocalizations`. Язык выбирает система. Новую строку добавлять **в оба** файла с одним ключом; названия станций/провайдеров не локализуются (имена собственные).
- **Индикатор здоровья станции:** `setStatus(text, health)` пишет и текст статуса, и цвет кружка `statusDot` (`.connecting` жёлтый / `.playing` зелёный / `.failed` красный / `.idle` скрыт) — паттерн из Voica. Все точки установки статуса идут через него, не через `statusLabel.stringValue` напрямую.
- **Проверка обновлений (`Updater`):** анонимный запрос к GitHub Releases API (`/releases/latest`), semver-сравнение с `CFBundleShortVersionString`. Тихая проверка при старте кладёт результат в `availableUpdate` (подсказка в статусе, если стоим); в окне About — кнопка «Проверить обновления», которая при находке превращается в «Скачать <версия>» и открывает страницу релиза. Только уведомление — скачивает пользователь сам.

## Диагностика

Все события (CONNECT, status=, acclog, errlog, WATCHDOG, FALLBACK, PLAYING, RETRY) пишутся в stderr с миллисекундной меткой через `rlog(_:)`. Проще всего запустить через `./scripts/run.sh` — логи прямо в терминале. При расследовании молчания: наличие `acclog: bytes=N` означает, что байты реально текут; отсутствие `status=1 err=nil` после `CONNECT` означает, что `AVPlayerItem` так и не вышел в `readyToPlay`.

Сетевая нестабильность Icecast-серверов — реальная причина части провалов в `--test-all`; одни и те же URL иногда не запускаются даже через отдельный `AVPlayer` вне нашего кода.

**Заметки по URL (аудит 2026-07):**
- **RP/NTS замирали из-за `automaticallyWaitsToMinimizeStalling`, не из-за гео.** Симптом: `status=2`, но `currentTime()` стоит на `0.0`. Долго списывали на гео-блок / путь `mediaserverd` (сбивало то, что `curl` через US-выход тянул потоки), пока не проверили те же URL в **QuickTime** — играют. QuickTime = AVFoundation с дефолтным флагом `true`; у нас было `false`. Вернули `true` → все 18 станций играют. Мораль: при «коннект, но `t=0`» сперва проверь QuickTime и буферизацию, а не сеть.
- **Ложный «зелёный» в детекторе (исправлено).** Раньше `loadedTimeRanges.duration > 0.5` (стартовый буфер) считался игрой — замёрзший поток набирал буфер и давал `played=true` при `t=0.0`. Теперь признак игры — только рост `currentTime`/байт.
- **NTS переехали на radiomast.** `stream-mixtape-geo.ntslive.net/mixtape{,2,3,35}` двойным 302-редиректом (через `streams.radiomast.io/<uuid>`) ведут на MP3-стрим `audio-edge-*.radiomast.io`. В `stations` прямой `streams.radiomast.io/<uuid>` первым, ntslive-URL — фолбэком.

## Устройство репозитория

```
radio.swift                 весь код
Resources/Info.plist        манифест .app-бандла (LSUIElement=true, версия и т.д.)
Resources/FocusRadio.icns   иконка (генерится make-icon.sh)
scripts/*.sh, make-icon.swift сборка/запуск/пакетирование/иконка
docs/icon.png, docs/*.png   для README (иконка + скриншоты)
.github/                    templates + CI (сборка, но не --test-all — см. выше)
README.md / README.ru.md    английская и русская версии
```

## Соглашения

- Комментарии в Swift-коде — на русском (UTF-8 без BOM, как требует Swift).
- Изменение файла и его запуск — двумя отдельными шагами, чтобы пользователь видел вывод.
- Ни одной сторонней зависимости — только системные фреймворки. Держим этот инвариант.
