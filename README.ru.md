<!-- Languages: [English](README.md) · **Русский** -->

<p align="center">
  <img src="docs/icon.png" width="128" alt="Focus Radio icon">
</p>

<h1 align="center">Focus Radio</h1>

<p align="center">
  Крошечный меню-бар плеер онлайн-радио для macOS — фоновая музыка для фокусной работы.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2013%2B-black" alt="macOS 13+">
  <img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT license">
  <img src="https://img.shields.io/badge/built%20with-Swift-orange" alt="Swift">
</p>

---

Focus Radio сидит в меню-баре и стримит 14 отобранных станций для фонового прослушивания:
ambient, drone, mellow, downtempo, spiritual jazz. Без аккаунтов, без рекламы, без
музыкальной библиотеки — клик, выбор станции, работа продолжается.

## Возможности

- **Только меню-бар.** Анимированная эквалайзер-иконка и компактный поповер — никакой
  иконки в Dock и никаких окон.
- **14 станций, три провайдера.** SomaFM (7 каналов: ambient / space / IDM / chillout),
  Radio Paradise (Mellow / Main / Global), NTS Mixtapes (Slow Focus / Low Key / Sheet
  Music / Expansions).
- **Свежие URL при запуске.** `.pls`-плейлисты SomaFM обновляются на старте — всегда
  берётся живой сервер.
- **Надёжный фоллбэк.** Watchdog по каждому URL → следующий URL → хардкодный снимок →
  повтор всей станции. Реальный факт воспроизведения — по буферу/байтам/`currentTime`,
  а не только по `timeControlStatus`.
- **Интеграция с macOS.** Регистрируется в `MPRemoteCommandCenter`, поэтому физическая
  кнопка Play/Pause и карточка в Control Center работают, пока Focus Radio играет.
- **Восстанавливает состояние.** Последняя станция и громкость возвращаются при следующем
  запуске.
- **Нулевые зависимости.** Один Swift-файл (`radio.swift`), только системные фреймворки
  (AppKit, AVFoundation, MediaPlayer).

## Скриншоты

<!-- Добавить docs/popover.png и docs/menubar.png до первого релиза. -->

## Установка

1. Скачайте `FocusRadio-<версия>.dmg` со страницы
   [Releases](https://github.com/Inhum/focus-radio/releases)
   (или соберите сами — см. ниже).
2. Откройте `.dmg` и перетащите **FocusRadio** в **Applications**.
3. Приложение не нотаризовано, поэтому при первом запуске macOS ругается на неизвестного
   разработчика: System Settings → Privacy & Security → **Open Anyway**. Дальше открывается
   нормально.

## Использование

- Клик по иконке в меню-баре → поповер со списком станций, кнопкой play/pause и громкостью.
- Иконка анимируется, пока станция играет.
- Play/Pause на клавиатуре (физическая медиа-кнопка) переключает воспроизведение, пока
  Focus Radio — активный источник звука. Как только запустите Spotify или ролик в
  YouTube — те заберут маршрут кнопки себе.
- Кнопка "About" — версия, лицензия, ссылка на репо. "Quit" — выход.

## Сборка из исходников

Требования: macOS 13+ и Command Line Tools (`xcode-select --install`). Полноценный Xcode
не нужен.

```bash
git clone https://github.com/Inhum/focus-radio.git
cd focus-radio
./scripts/run.sh           # debug-сборка + запуск с логами в терминале
./scripts/build.sh         # release-сборка → build/FocusRadio.app
./scripts/test.sh          # сборка + --test-all по всем станциям
./scripts/package.sh       # release-сборка + FocusRadio-<версия>.dmg
./scripts/make-icon.sh     # перегенерить Resources/FocusRadio.icns + docs/icon.png
```

## Данные и сеть

У Focus Radio нет бекенда, телеметрии и аналитики. Единственные сетевые запросы:

- `api.somafm.com` — обновление `.pls`-плейлистов SomaFM при запуске.
- Прямые стрим-эндпоинты из списка `stations` в `radio.swift`.

Настройки (индекс последней станции и громкость) хранятся через `UserDefaults` в
`~/Library/Preferences/com.ushakov.focus-radio.plist`. Подробнее и о том, как сообщать
об уязвимостях — в [SECURITY.md](SECURITY.md).

## Станции

Названия и URL станций принадлежат вещателям. Focus Radio — независимый клиент, не
аффилирован с SomaFM, Radio Paradise и NTS. Если вам нравится какая-то из этих станций,
поддержите её напрямую — все три без рекламы и живут на пожертвования слушателей.

## Вклад

Issues и pull requests приветствуются — см. [CONTRIBUTING.md](CONTRIBUTING.md). Проект
делается в свободное время, ответы могут быть медленными, не каждая идея будет принята.

## Благодарности

Focus Radio во многом сделан с [Claude Code](https://claude.com/claude-code) — агентным
инструментом Anthropic для программирования как парный AI-программист.

## Лицензия

[MIT](LICENSE) © 2026 Ivan Ushakov
