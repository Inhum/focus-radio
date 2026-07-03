# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Среда

- ОС: macOS (Darwin), shell zsh.

## Что это

**Focus Radio** — однофайловое меню-бар приложение для macOS (AppKit + AVFoundation + MediaPlayer). Воспроизводит онлайн-радио для фокусной работы. 14 станций сгруппированы по провайдерам (SomaFM / Radio Paradise / NTS Mixtapes). SomaFM URL обновляются на старте через `.pls`-файлы.

Весь код лежит в `radio.swift` (единственный source-файл). Всё остальное вокруг — обвязка `.app`-бандла и открытого репозитория (Info.plist, скрипты, шаблоны GitHub).

## Сборка и запуск

Всё делается через скрипты в `scripts/`, без Xcode — нужны только Command Line Tools (`xcode-select --install`).

```sh
./scripts/run.sh           # debug-сборка + запуск с логами в терминале (Ctrl+C = стоп)
./scripts/build.sh         # release-сборка → build/FocusRadio.app
./scripts/test.sh          # сборка + --test-all по всем станциям (exit != 0, если не все играют)
./scripts/package.sh       # release + build/FocusRadio-<версия>.dmg с ярлыком /Applications
./scripts/make-icon.sh     # перегенерить Resources/FocusRadio.icns + docs/icon.png
```

Ручной вызов самотеста одной станции по индексу (0..13):

```sh
./build/FocusRadio.app/Contents/MacOS/FocusRadio --test-one 5
```

Юнит-тестов нет, линтеров нет — единственный «зелёный» сигнал это `./scripts/test.sh` с exit 0. Но `--test-all` бьёт по живым Icecast-серверам, часть станций периодически отказывают из-за сети/гео-блока (см. «Известные мёртвые URL» ниже) — поэтому в CI самотест **не** запускается, только сборка.

## Архитектура `radio.swift`

Чтобы понять поведение приложения, важны несколько связок, разнесённых по файлу:

- **Цепочка фоллбэков:** `tryCurrentURL` → `watchdog` (8 с MP3 / 12 с AAC) → `tryNextURL` идёт по `station.urls`. Когда список исчерпан — пробуем `originalStationURLs[idx]` (хардкодный снимок до PLS-обновления), затем повторяем всю станцию `maxStationRetries` раз. Это отдельный механизм от per-URL фоллбэка.
- **Детектор реального воспроизведения** (`pollTimer`, 0.5 с): `timeControlStatus == .playing` сам по себе — это только *намерение* (особенно при `automaticallyWaitsToMinimizeStalling = false`). Реальный сигнал — `loadedTimeRanges.first.duration > 0.5`, рост `accessLog().events.last.numberOfBytesTransferred`, или продвижение `currentTime()`. Нужны два подряд успешных опроса прежде чем считать станцию играющей. Не упрощать обратно до `.playing`.
- **PLS race:** `fetchSomaFMURLs` обновляет `stations[idx].urls` асинхронно. `startPlayingCurrent` → `waitForPLS(idx, timeout: 1.5)` ждёт результата на главном потоке через `Timer` (не `DispatchQueue.main.asyncAfter` — тот не дренируется под `RunLoop.main.run(until:)`).
- **`teardownPlayer`:** единая точка снятия плеера, KVO и notification-обозревателей. Любая транзакция (stop, выбор другой станции, фоллбэк, выход) обязана идти через неё, иначе остаются стейл-обозреватели и «переключение туда-обратно» даёт тишину. Особенно важен `replaceCurrentItem(with: nil)` перед `player = nil`.
- **Режимы запуска:** `--test-all` итерирует станции через цепочку `Timer`-ов, не блокируя главный run loop. Гонка с AVPlayer возникает, если попытаться драйвить run loop вручную через `RunLoop.main.run(until:)` — AVPlayer перестаёт обращаться по сети. `testWaitTimer` регистрируется в `.common` mode (`RunLoop.main.add(timer, forMode: .common)`) — в `.default` mode AVPlayer может удерживать RunLoop в другом mode и таймер перестаёт тикать, что ведёт к elapsed=500s+ при 40s-таймауте.
- **Закрытие поповера в `.accessory`-приложении:** `popover.behavior = .transient` *не* закрывает окно при клике в другом приложении или по рабочему столу — только при кликах внутри своего процесса. Фикс — глобальный `NSEvent.addGlobalMonitorForEvents` на `.leftMouseDown`/`.rightMouseDown`, ставится в `togglePopover` при показе и снимается в `popoverDidClose`. Не упрощать обратно к одному `.transient`: визуально работает в окне Xcode, ломается в реальном использовании.
- **Media keys / Now Playing:** `setupMediaControls` регистрирует `togglePlayPause`/`play`/`pause` в `MPRemoteCommandCenter`, а `updateNowPlaying(playing:)` пишет/сбрасывает `MPNowPlayingInfoCenter.default().nowPlayingInfo` при старте реального воспроизведения (`declaredPlaying = true`) и в `stopPlaying`. macOS маршрутизирует физическую Play/Pause клавишу тому приложению, чья карточка сейчас в Now Playing — то есть нам, пока играем. Если забыть сбросить `nowPlayingInfo` в `stopPlaying`, система будет считать, что мы всё ещё играем, и кнопка будет доставаться нам даже когда стоим на паузе.
- **Персистенс через `UserDefaults`:** ключи `focusRadio.stationIdx` (Int) и `focusRadio.volume` (Float). Сохраняем в `selectStation` и `volumeChanged`; загружаем в `applicationDidFinishLaunching` **до** создания UI (но после раннего возврата из test-режимов, чтобы `--test-all` не завёлся с прошлой громкостью 0.05).

## Диагностика

Все события (CONNECT, status=, acclog, errlog, WATCHDOG, FALLBACK, PLAYING, RETRY) пишутся в stderr с миллисекундной меткой через `rlog(_:)`. Проще всего запустить через `./scripts/run.sh` — логи прямо в терминале. При расследовании молчания: наличие `acclog: bytes=N` означает, что байты реально текут; отсутствие `status=1 err=nil` после `CONNECT` означает, что `AVPlayerItem` так и не вышел в `readyToPlay`.

Сетевая нестабильность Icecast-серверов — реальная причина части провалов в `--test-all`; одни и те же URL иногда не запускаются даже через отдельный `AVPlayer` вне нашего кода.

**Известные мёртвые URL (по логам от 2026-05):**
- `stream.radioparadise.com/global-128` — сервер отдаёт `audio/aac`, но AVPlayer получает `bytes=0` на протяжении всех 12 с воспроизведения.
- `stream-mixtape-geo.ntslive.net/mixtape{,2,3,35}` — CDN редиректит (302) на HTML-страницу (геоблок). Non-geo вариант `stream-mixtape.ntslive.net` — DNS не существует.

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
