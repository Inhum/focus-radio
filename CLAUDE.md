# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Среда

- ОС: macOS (Darwin), shell zsh.

## Что лежит в репо

Это песочница для маленьких самодостаточных артефактов, не библиотека и не пакет:

- **`radio.swift`** — однофайловое меню-бар приложение для macOS (AppKit + AVFoundation). Воспроизводит онлайн-радио для фокусной работы. 14 станций сгруппированы по провайдерам (SomaFM / Radio Paradise / NTS Mixtapes). SomaFM URL обновляются на старте через `.pls`-файлы.
- **`invaders.html`** — однофайловая игра Space Invaders (Canvas + Web Audio). Открывается напрямую в браузере, без сборки.
- **`probe.swift`** — отдельный диагностический скрипт для проверки одного URL через `AVPlayer`. Используется для изоляции сетевых/AVFoundation-проблем от логики `radio.swift`.

## Сборка и запуск

```sh
# radio.swift — основное приложение
swiftc -O radio.swift -o radio && ./radio

# Самотест всех 14 станций (выходит с ненулевым кодом, если не все играют)
./radio --test-all 2>&1 | tee radio.test.log

# Прогон одной станции по индексу (0..13) с подробным логом
./radio --test-one 5

# probe.swift — минимальный AVPlayer-тест одного URL
swiftc -O probe.swift -o probe && ./probe "https://ice6.somafm.com/dronezone-256-mp3"
```

Тестов нет, линтеров нет — единственный «зелёный» сигнал это `--test-all` с exit 0.

## Архитектура `radio.swift`

Чтобы понять поведение приложения, важны несколько связок, разнесённых по файлу:

- **Цепочка фоллбэков:** `tryCurrentURL` → `watchdog` (8 с MP3 / 12 с AAC) → `tryNextURL` идёт по `station.urls`. Когда список исчерпан — пробуем `originalStationURLs[idx]` (хардкодный снимок до PLS-обновления), затем повторяем всю станцию `maxStationRetries` раз. Это отдельный механизм от per-URL фоллбэка.
- **Детектор реального воспроизведения** (`pollTimer`, 0.5 с): `timeControlStatus == .playing` сам по себе — это только *намерение* (особенно при `automaticallyWaitsToMinimizeStalling = false`). Реальный сигнал — `loadedTimeRanges.first.duration > 0.5`, рост `accessLog().events.last.numberOfBytesTransferred`, или продвижение `currentTime()`. Нужны два подряд успешных опроса прежде чем считать станцию играющей. Не упрощать обратно до `.playing`.
- **PLS race:** `fetchSomaFMURLs` обновляет `stations[idx].urls` асинхронно. `startPlayingCurrent` → `waitForPLS(idx, timeout: 1.5)` ждёт результата на главном потоке через `Timer` (не `DispatchQueue.main.asyncAfter` — тот не дренируется под `RunLoop.main.run(until:)`).
- **`teardownPlayer`:** единая точка снятия плеера, KVO и notification-обозревателей. Любая транзакция (stop, выбор другой станции, фоллбэк, выход) обязана идти через неё, иначе остаются стейл-обозреватели и «переключение туда-обратно» даёт тишину. Особенно важен `replaceCurrentItem(with: nil)` перед `player = nil`.
- **Режимы запуска:** `--test-all` итерирует станции через цепочку `Timer`-ов, не блокируя главный run loop. Гонка с AVPlayer возникает, если попытаться драйвить run loop вручную через `RunLoop.main.run(until:)` — AVPlayer перестаёт обращаться по сети. `testWaitTimer` регистрируется в `.common` mode (`RunLoop.main.add(timer, forMode: .common)`) — в `.default` mode AVPlayer может удерживать RunLoop в другом mode и таймер перестаёт тикать, что ведёт к elapsed=500s+ при 40s-таймауте.
- **Закрытие поповера в `.accessory`-приложении:** `popover.behavior = .transient` *не* закрывает окно при клике в другом приложении или по рабочему столу — только при кликах внутри своего процесса. Фикс — глобальный `NSEvent.addGlobalMonitorForEvents` на `.leftMouseDown`/`.rightMouseDown`, ставится в `togglePopover` при показе и снимается в `popoverDidClose`. Не упрощать обратно к одному `.transient`: визуально работает в окне Xcode, ломается в реальном использовании.

## Диагностика

Все события (CONNECT, status=, acclog, errlog, WATCHDOG, FALLBACK, PLAYING, RETRY) пишутся в stderr с миллисекундной меткой через `rlog(_:)`. При расследовании молчания первым делом смотреть в `radio.test.log`: наличие `acclog: bytes=N` означает, что байты реально текут; отсутствие `status=1 err=nil` после `CONNECT` означает, что `AVPlayerItem` так и не вышел в `readyToPlay`.

`probe.swift` полезен, когда нужно проверить, виноват ли конкретный URL/сеть, а не логика `radio.swift`. Сетевая нестабильность Icecast-серверов — реальная причина части провалов в `--test-all`; одна и та же URL у `probe` тоже иногда не запускается.

**Известные мёртвые URL (подтверждено `probe`):**
- `stream.radioparadise.com/global-128` — сервер отдаёт `audio/aac`, но `probe` показывает `bytes=0` на протяжении всех 12 с. AVPlayer не воспроизводит.
- `stream-mixtape-geo.ntslive.net/mixtape{,2,3,35}` — CDN редиректит (302) на HTML-страницу (геоблок). Non-geo вариант `stream-mixtape.ntslive.net` — DNS не существует. Probe показывает ~0.496 с буфера (HTML-ответ, распарсенный как 21 AAC-фрейм) — ниже порога `buffered > 0.5`.

## Соглашения

- Комментарии в Swift-коде — на русском (UTF-8 без BOM, как требует Swift).
- Обновление файла и его запуск — двумя отдельными шагами, чтобы пользователь видел вывод.
