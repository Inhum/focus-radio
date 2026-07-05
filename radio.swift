#!/usr/bin/env swift
// Меню-бар приложение для прослушивания радио для фокусной работы.
// Сборка: swiftc -O radio.swift -o radio && ./radio
// Самотест: ./radio --test-all

import Cocoa
import AVFoundation
import MediaPlayer

struct Station {
    let provider: String
    let name: String
    let genre: String
    var urls: [String]      // обновляется при загрузке из SomaFM PLS
    let plsURL: String?     // URL .pls-файла для получения актуальных серверов
}

// Хардкодные URL — запасной вариант если PLS недоступен.
// Актуальные URL загружаются при запуске через fetchSomaFMURLs().
var stations: [Station] = [
    Station(provider: "SomaFM", name: "Drone Zone",      genre: "drone ambient",
        urls: ["https://ice4.somafm.com/dronezone-256-mp3",
               "https://ice6.somafm.com/dronezone-256-mp3",
               "https://ice2.somafm.com/dronezone-256-mp3"],
        plsURL: "https://api.somafm.com/dronezone256.pls"),
    Station(provider: "SomaFM", name: "Deep Space One",  genre: "deep space ambient",
        urls: ["https://ice4.somafm.com/deepspaceone-128-aac",
               "https://ice6.somafm.com/deepspaceone-128-aac",
               "https://ice4.somafm.com/deepspaceone-128-mp3"],
        plsURL: "https://api.somafm.com/deepspaceone130.pls"),
    Station(provider: "SomaFM", name: "Synphaera",       genre: "beatless ambient",
        urls: ["https://ice4.somafm.com/synphaera-256-mp3",
               "https://ice6.somafm.com/synphaera-256-mp3",
               "https://ice2.somafm.com/synphaera-256-mp3"],
        plsURL: "https://api.somafm.com/synphaera256.pls"),
    Station(provider: "SomaFM", name: "Mission Control", genre: "space + NASA",
        urls: ["https://ice4.somafm.com/missioncontrol-128-aac",
               "https://ice6.somafm.com/missioncontrol-128-aac",
               "https://ice4.somafm.com/missioncontrol-128-mp3"],
        plsURL: "https://api.somafm.com/missioncontrol130.pls"),
    Station(provider: "SomaFM", name: "Cliqhop",         genre: "IDM / electronica",
        urls: ["https://ice4.somafm.com/cliqhop-256-mp3",
               "https://ice6.somafm.com/cliqhop-256-mp3",
               "https://ice2.somafm.com/cliqhop-256-mp3"],
        plsURL: "https://api.somafm.com/cliqhop256.pls"),
    Station(provider: "SomaFM", name: "Groove Salad",    genre: "chillout / downtempo",
        urls: ["https://ice4.somafm.com/groovesalad-256-mp3",
               "https://ice6.somafm.com/groovesalad-256-mp3",
               "https://ice2.somafm.com/groovesalad-256-mp3"],
        plsURL: "https://api.somafm.com/groovesalad256.pls"),
    Station(provider: "SomaFM", name: "SF 10-33",        genre: "ambient + soundscapes",
        urls: ["https://ice4.somafm.com/sf1033-128-aac",
               "https://ice6.somafm.com/sf1033-128-aac",
               "https://ice4.somafm.com/sf1033-128-mp3"],
        plsURL: "https://api.somafm.com/sf1033130.pls"),

    // Доп. каналы SomaFM. Все проверены реальным воспроизведением из RU (--test-one).
    // ice4/ice6/ice2 — зеркала одного слага; PLS нет (ice-URL стабильны).
    Station(provider: "SomaFM", name: "Space Station Soma", genre: "ambient / space",
        urls: ["https://ice4.somafm.com/spacestation-128-mp3",
               "https://ice6.somafm.com/spacestation-128-mp3",
               "https://ice2.somafm.com/spacestation-128-mp3"], plsURL: nil),
    Station(provider: "SomaFM", name: "Sonic Universe", genre: "avant jazz",
        urls: ["https://ice4.somafm.com/sonicuniverse-256-mp3",
               "https://ice6.somafm.com/sonicuniverse-256-mp3",
               "https://ice2.somafm.com/sonicuniverse-256-mp3"], plsURL: nil),
    Station(provider: "SomaFM", name: "The Trip", genre: "psychill / prog",
        urls: ["https://ice4.somafm.com/thetrip-128-mp3",
               "https://ice6.somafm.com/thetrip-128-mp3",
               "https://ice2.somafm.com/thetrip-128-mp3"], plsURL: nil),
    Station(provider: "Radio Paradise", name: "Mellow Mix", genre: "mellow eclectic",
        urls: ["https://stream.radioparadise.com/mellow-128"], plsURL: nil),
    Station(provider: "Radio Paradise", name: "Main Mix",   genre: "eclectic",
        urls: ["https://stream.radioparadise.com/mp3-128",
               "https://stream.radioparadise.com/aac-128"],   plsURL: nil),
    Station(provider: "Radio Paradise", name: "Global Mix", genre: "world",
        urls: ["https://stream.radioparadise.com/global-128"], plsURL: nil),

    // NTS переехали на radiomast: прямой streams.radiomast.io/<uuid> первым,
    // ntslive-URL фолбэком (на случай смены uuid).
    Station(provider: "NTS Mixtapes", name: "Slow Focus",  genre: "beatless ambient",
        urls: ["https://streams.radiomast.io/dfc76352-cda6-4a95-85dd-6f6609f83ba2",
               "https://stream-mixtape-geo.ntslive.net/mixtape"],   plsURL: nil),
    Station(provider: "NTS Mixtapes", name: "Low Key",     genre: "chill / downtempo",
        urls: ["https://streams.radiomast.io/de114902-ee1b-441f-91bc-5468d1e77605",
               "https://stream-mixtape-geo.ntslive.net/mixtape2"],  plsURL: nil),
    Station(provider: "NTS Mixtapes", name: "Sheet Music", genre: "classical",
        urls: ["https://streams.radiomast.io/976b6107-859e-4bc5-8d63-d6992431c414",
               "https://stream-mixtape-geo.ntslive.net/mixtape35"], plsURL: nil),
    Station(provider: "NTS Mixtapes", name: "Expansions",  genre: "spiritual jazz",
        urls: ["https://streams.radiomast.io/e4c0a484-140a-4adf-ae72-301280d635ba",
               "https://stream-mixtape-geo.ntslive.net/mixtape3"],  plsURL: nil),

    // Nightwave Plaza — независимый vaporwave-поток.
    Station(provider: "Nightwave Plaza", name: "Plaza", genre: "vaporwave / lo-fi",
        urls: ["https://radio.plaza.one/mp3"], plsURL: nil),
]

// Снимок исходных хардкодных URL — для повторного fallback после неудачи с PLS-серверами.
let originalStationURLs: [[String]] = stations.map { $0.urls }

// Глобальный логгер — пишет в stderr с миллисекундной меткой.
let logFmt: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss.SSS"
    return f
}()
func rlog(_ s: String) {
    let line = "[\(logFmt.string(from: Date()))] \(s)\n"
    FileHandle.standardError.write(line.data(using: .utf8)!)
}

// Помощник локализации. Строки лежат в Resources/<lang>.lproj/Localizable.strings.
// Язык выбирается автоматически по системным настройкам (en — база, ru — перевод).
func L(_ key: String, _ args: CVarArg...) -> String {
    let format = NSLocalizedString(key, comment: "")
    return args.isEmpty ? format : String(format: format, arguments: args)
}

// Проверка обновлений через публичный GitHub Releases API (репозиторий публичный →
// запрос анонимный, без токена). Это ТОЛЬКО уведомление: если версия новее — приложение
// предлагает открыть страницу релиза, скачивание и замену пользователь делает сам.
struct Update {
    let version: String     // без ведущего "v", напр. "0.2.0"
    let pageURL: URL        // html_url релиза на GitHub
}

enum Updater {
    static let releasesAPI = URL(string: "https://api.github.com/repos/Inhum/focus-radio/releases/latest")!

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// completion(.success(update)) — доступна версия новее; .success(nil) — уже последняя.
    static func check(completion: @escaping (Result<Update?, Error>) -> Void) {
        var req = URLRequest(url: releasesAPI)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("FocusRadio", forHTTPHeaderField: "User-Agent")   // GitHub API отклоняет запрос без User-Agent
        req.timeoutInterval = 20

        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err { return completion(.failure(err)) }
            guard let http = resp as? HTTPURLResponse, let data = data else {
                return completion(.failure(UpdateError.noResponse))
            }
            guard (200..<300).contains(http.statusCode) else {
                return completion(.failure(UpdateError.http(http.statusCode)))
            }
            guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = obj["tag_name"] as? String,
                  let page = (obj["html_url"] as? String).flatMap(URL.init(string:)) else {
                return completion(.failure(UpdateError.decode))
            }
            let latest = normalize(tag)
            if isNewer(latest, than: normalize(currentVersion)) {
                completion(.success(Update(version: latest, pageURL: page)))
            } else {
                completion(.success(nil))
            }
        }.resume()
    }

    /// Убирает ведущие не-цифры из тега: "v0.2.0" → "0.2.0".
    static func normalize(_ tag: String) -> String {
        let s = tag.trimmingCharacters(in: .whitespaces)
        return String(s.drop(while: { !$0.isNumber }))
    }

    /// Сравнение версий покомпонентно (semver-подобно): 0.10.0 > 0.9.0.
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let b = current.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    enum UpdateError: Error, LocalizedError {
        case noResponse, http(Int), decode
        var errorDescription: String? {
            switch self {
            case .noResponse:  return L("update.err.noResponse")
            case .http(let c): return L("update.err.http", c)
            case .decode:      return L("update.err.decode")
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var eventMonitor: Any?
    var aboutWindow: NSWindow?
    var player: AVPlayer?
    var currentItem: AVPlayerItem?
    var watchdog: Timer?
    var pollTimer: Timer?
    var isPlaying = false
    var currentStationIdx = 0
    var currentURLIdx = 0
    var volume: Float = 0.7
    var phase: Double = 0
    var animTimer: Timer?

    // Состояние детектора реального воспроизведения
    var lastObservedTime: Double = 0
    var advanceChecks: Int = 0
    var declaredPlaying = false
    var triedHardcodedFallback = false
    var stationRetryCount = 0
    let maxStationRetries = 1

    // KVO и обозреватели уведомлений
    var statusObs: NSKeyValueObservation?
    var errorObs: NSKeyValueObservation?
    var rateObs: NSKeyValueObservation?
    var nObservers: [NSObjectProtocol] = []

    // PLS race
    var plsLoaded: Set<Int> = []
    var plsPending: [Int: [() -> Void]] = [:]

    var stationButton: NSButton!
    var stationMenu: NSMenu!
    var playButton: NSButton!
    var volumeSlider: NSSlider!
    var statusLabel: NSTextField!
    var statusDot: NSImageView!          // цветной индикатор здоровья станции

    var availableUpdate: Update?         // заполняется тихой проверкой при старте
    var aboutUpdateLabel: NSTextField?   // строка результата проверки в окне About
    var aboutCheckButton: NSButton?      // кнопка «Проверить обновления» / «Скачать …»

    var isTestMode = false

    var testOneIdx: Int? = nil

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let one = testOneIdx {
            // Режим прогона одной станции: играем 15 секунд и выходим.
            fetchSomaFMURLs()
            Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                self.currentStationIdx = one
                self.currentURLIdx = 0
                self.triedHardcodedFallback = false
                rlog("=== TEST-ONE [\(one)] \(stations[one].name) ===")
                self.startPlayingCurrent()
                Timer.scheduledTimer(withTimeInterval: 18.0, repeats: false) { _ in
                    let t = self.player?.currentTime().seconds ?? 0
                    let bytes = self.player?.currentItem?.accessLog()?.events.last?.numberOfBytesTransferred ?? 0
                    rlog("=== TEST-ONE END played=\(self.declaredPlaying) t=\(t) bytes=\(bytes) urlIdx=\(self.currentURLIdx) ===")
                    exit(self.declaredPlaying ? 0 : 1)
                }
            }
            return
        }
        if isTestMode {
            // В режиме самотеста UI не нужен.
            fetchSomaFMURLs()
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.runSelfTest()
            }
            return
        }

        // Восстанавливаем последнее состояние (станция и громкость).
        let d = UserDefaults.standard
        if let idx = d.object(forKey: "focusRadio.stationIdx") as? Int,
           idx >= 0, idx < stations.count {
            currentStationIdx = idx
        }
        if let v = d.object(forKey: "focusRadio.volume") as? Float {
            volume = max(0, min(1, v))
        }

        statusItem = NSStatusBar.system.statusItem(withLength: 28)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover(_:))
        updateStatusIcon()

        popover = NSPopover()
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = makePopoverViewController()

        animTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateStatusIcon()
        }

        fetchSomaFMURLs()
        setupMediaControls()

        // Тихая проверка обновлений при старте: только запоминаем результат и, если стоим
        // на месте, показываем ненавязчивую подсказку в статусе (детали — в окне About).
        Updater.check { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self, case .success(let up?) = result else { return }
                self.availableUpdate = up
                if !self.isPlaying {
                    self.setStatus(L("status.updateAvailable", up.version), .idle)
                }
            }
        }
    }

    // Запрашиваем .pls для каждой SomaFM-станции и обновляем список URL.
    func fetchSomaFMURLs() {
        for (idx, station) in stations.enumerated() {
            guard let plsURLStr = station.plsURL,
                  let url = URL(string: plsURLStr) else { continue }
            URLSession.shared.dataTask(with: url) { [weak self] data, _, err in
                defer {
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.plsLoaded.insert(idx)
                        let pending = self.plsPending.removeValue(forKey: idx) ?? []
                        for cb in pending { cb() }
                    }
                }
                guard let data = data,
                      let text = String(data: data, encoding: .utf8) else {
                    rlog("PLS idx=\(idx) FAIL err=\(String(describing: err))")
                    return
                }
                let urls = text.components(separatedBy: "\n")
                    .filter { $0.hasPrefix("File") }
                    .compactMap { line -> String? in
                        guard let eq = line.firstIndex(of: "=") else { return nil }
                        return String(line[line.index(after: eq)...])
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    .filter { !$0.isEmpty }
                guard !urls.isEmpty else { return }
                DispatchQueue.main.async {
                    stations[idx].urls = urls
                    rlog("PLS idx=\(idx) \(stations[idx].name) -> \(urls.count) urls, first=\(urls[0])")
                }
            }.resume()
        }
    }

    // Если PLS ещё не загрузился — ждём до timeout, затем callback.
    func waitForPLS(idx: Int, timeout: TimeInterval, then: @escaping () -> Void) {
        if plsLoaded.contains(idx) || stations[idx].plsURL == nil {
            then(); return
        }
        var fired = false
        let cb: () -> Void = {
            if fired { return }
            fired = true
            then()
        }
        plsPending[idx, default: []].append(cb)
        // Используем Timer вместо asyncAfter, чтобы корректно работать под RunLoop.run(until:).
        Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in cb() }
    }

    // --- UI поповера ---
    func makePopoverViewController() -> NSViewController {
        let vc = NSViewController()
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 180))

        let title = NSTextField(labelWithString: "🎵 Focus Radio")
        title.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        title.frame = NSRect(x: 16, y: 145, width: 308, height: 20)
        v.addSubview(title)

        stationMenu = buildStationMenu()
        stationButton = NSButton(frame: NSRect(x: 16, y: 108, width: 308, height: 26))
        updateStationButtonTitle()
        stationButton.bezelStyle = .rounded
        stationButton.target = self
        stationButton.action = #selector(showStationMenu(_:))
        v.addSubview(stationButton)

        playButton = NSButton(frame: NSRect(x: 16, y: 65, width: 90, height: 28))
        playButton.title = L("ui.play")
        playButton.bezelStyle = .rounded
        playButton.target = self
        playButton.action = #selector(togglePlay)
        v.addSubview(playButton)

        volumeSlider = NSSlider(frame: NSRect(x: 116, y: 67, width: 208, height: 24))
        volumeSlider.minValue = 0; volumeSlider.maxValue = 1
        volumeSlider.doubleValue = Double(volume)
        volumeSlider.target = self
        volumeSlider.action = #selector(volumeChanged)
        v.addSubview(volumeSlider)

        statusDot = NSImageView(frame: NSRect(x: 16, y: 33, width: 12, height: 12))
        statusDot.imageScaling = .scaleProportionallyUpOrDown
        statusDot.isHidden = true
        v.addSubview(statusDot)

        statusLabel = NSTextField(labelWithString: L("status.ready"))
        statusLabel.frame = NSRect(x: 33, y: 32, width: 291, height: 18)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        v.addSubview(statusLabel)

        let about = NSButton(frame: NSRect(x: 16, y: 4, width: 120, height: 22))
        about.title = L("ui.about"); about.bezelStyle = .rounded
        about.target = self
        about.action = #selector(showAbout)
        v.addSubview(about)

        let quit = NSButton(frame: NSRect(x: 254, y: 4, width: 70, height: 22))
        quit.title = L("ui.quit"); quit.bezelStyle = .rounded
        quit.target = NSApp
        quit.action = #selector(NSApplication.terminate(_:))
        v.addSubview(quit)

        // Если тихая проверка при старте нашла обновление — сразу показываем подсказку.
        if let up = availableUpdate {
            setStatus(L("status.updateAvailable", up.version), .idle)
        }

        vc.view = v
        return vc
    }

    func updateStationButtonTitle() {
        let s = stations[currentStationIdx]
        stationButton?.title = "\(s.name)  ·  \(s.genre)  ▾"
    }

    func buildStationMenu() -> NSMenu {
        let menu = NSMenu()
        var lastProvider: String? = nil
        for (idx, station) in stations.enumerated() {
            if station.provider != lastProvider {
                if lastProvider != nil { menu.addItem(NSMenuItem.separator()) }
                let header = NSMenuItem()
                header.attributedTitle = NSAttributedString(
                    string: station.provider.uppercased(),
                    attributes: [.font: NSFont.systemFont(ofSize: 10, weight: .semibold),
                                 .foregroundColor: NSColor.secondaryLabelColor])
                header.isEnabled = false
                menu.addItem(header)
                lastProvider = station.provider
            }
            let item = NSMenuItem(title: "\(station.name)  ·  \(station.genre)",
                                  action: #selector(selectStation(_:)), keyEquivalent: "")
            item.tag = idx; item.target = self
            menu.addItem(item)
        }
        return menu
    }

    @objc func showStationMenu(_ sender: NSButton) {
        stationMenu.popUp(positioning: nil,
                          at: NSPoint(x: 0, y: sender.bounds.height + 2),
                          in: sender)
    }

    @objc func selectStation(_ sender: NSMenuItem) {
        currentStationIdx = sender.tag
        currentURLIdx = 0
        triedHardcodedFallback = false
        stationRetryCount = 0
        updateStationButtonTitle()
        UserDefaults.standard.set(currentStationIdx, forKey: "focusRadio.stationIdx")
        startPlayingCurrent()
    }

    @objc func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            eventMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] _ in
                self?.popover.performClose(nil)
            }
        }
    }

    func popoverDidClose(_ notification: Notification) {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    @objc func togglePlay() {
        if isPlaying { stopPlaying() }
        else {
            currentURLIdx = 0
            triedHardcodedFallback = false
            stationRetryCount = 0
            startPlayingCurrent()
        }
    }

    @objc func volumeChanged() {
        volume = Float(volumeSlider.doubleValue)
        player?.volume = volume
        UserDefaults.standard.set(volume, forKey: "focusRadio.volume")
    }

    @objc func showAbout() {
        popover.performClose(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Окно создаётся один раз; повторный клик по «About» просто поднимает его наверх.
        if let w = aboutWindow {
            w.makeKeyAndOrderFront(nil)
            return
        }

        // Версию и билд берём из Info.plist бандла — так же, как их показывала
        // стандартная панель («Version 0.1.0 (1)»).
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"

        let content = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 344))

        // Наша иконка приложения (из Resources/FocusRadio.icns через бандл).
        let icon = NSImageView(frame: NSRect(x: (340 - 96) / 2, y: 232, width: 96, height: 96))
        icon.image = NSApp.applicationIconImage
        icon.imageScaling = .scaleProportionallyUpOrDown
        content.addSubview(icon)

        let name = NSTextField(labelWithString: "Focus Radio")
        name.font = NSFont.systemFont(ofSize: 17, weight: .bold)
        name.alignment = .center
        name.frame = NSRect(x: 0, y: 202, width: 340, height: 24)
        content.addSubview(name)

        let version = NSTextField(labelWithString: L("about.version", short, build))
        version.font = NSFont.systemFont(ofSize: 12)
        version.textColor = .secondaryLabelColor
        version.alignment = .center
        version.frame = NSRect(x: 0, y: 178, width: 340, height: 18)
        content.addSubview(version)

        let tagline = NSTextField(labelWithString: L("about.tagline"))
        tagline.font = NSFont.systemFont(ofSize: 12)
        tagline.alignment = .center
        tagline.frame = NSRect(x: 20, y: 148, width: 300, height: 20)
        content.addSubview(tagline)

        // Кнопки в столбик — русские подписи длиннее английских, в ряд не помещаются.
        let gh = NSButton(frame: NSRect(x: (340 - 110) / 2, y: 106, width: 110, height: 28))
        gh.title = L("about.github")
        gh.bezelStyle = .rounded
        gh.target = self
        gh.action = #selector(openRepo)
        content.addSubview(gh)

        let check = NSButton(frame: NSRect(x: (340 - 220) / 2, y: 72, width: 220, height: 28))
        check.bezelStyle = .rounded
        check.target = self
        content.addSubview(check)
        aboutCheckButton = check

        let updateLabel = NSTextField(labelWithString: "")
        updateLabel.font = NSFont.systemFont(ofSize: 11)
        updateLabel.textColor = .secondaryLabelColor
        updateLabel.alignment = .center
        updateLabel.frame = NSRect(x: 20, y: 48, width: 300, height: 16)
        content.addSubview(updateLabel)
        aboutUpdateLabel = updateLabel

        // Если тихая проверка при старте уже нашла обновление — показываем сразу «Скачать …».
        applyUpdateStateToAbout()

        let footer = NSTextField(labelWithString: L("about.copyright"))
        footer.font = NSFont.systemFont(ofSize: 10)
        footer.textColor = .tertiaryLabelColor
        footer.alignment = .center
        footer.frame = NSRect(x: 0, y: 20, width: 340, height: 16)
        content.addSubview(footer)

        let window = NSWindow(
            contentRect: content.frame,
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false)
        window.title = L("about.windowTitle")
        window.contentView = content
        window.isReleasedWhenClosed = false   // держим ссылку в aboutWindow, не даём освободить
        window.center()
        window.makeKeyAndOrderFront(nil)
        aboutWindow = window
    }

    // Приводит кнопку/строку обновлений в окне About к текущему состоянию availableUpdate.
    func applyUpdateStateToAbout() {
        guard let check = aboutCheckButton else { return }
        if let up = availableUpdate {
            check.title = L("about.update.download", up.version)
            check.action = #selector(openReleasePage)
            aboutUpdateLabel?.textColor = .systemGreen
            aboutUpdateLabel?.stringValue = L("about.update.available", up.version)
        } else {
            check.title = L("about.update.check")
            check.action = #selector(checkForUpdates)
            aboutUpdateLabel?.stringValue = ""
        }
    }

    @objc func checkForUpdates() {
        aboutCheckButton?.isEnabled = false
        aboutUpdateLabel?.textColor = .secondaryLabelColor
        aboutUpdateLabel?.stringValue = L("about.update.checking")
        Updater.check { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.aboutCheckButton?.isEnabled = true
                switch result {
                case .success(let up):
                    self.availableUpdate = up
                    if up != nil {
                        self.applyUpdateStateToAbout()
                    } else {
                        self.aboutUpdateLabel?.textColor = .secondaryLabelColor
                        self.aboutUpdateLabel?.stringValue = L("about.update.upToDate")
                    }
                case .failure(let err):
                    self.aboutUpdateLabel?.textColor = .systemRed
                    self.aboutUpdateLabel?.stringValue = err.localizedDescription
                }
            }
        }
    }

    @objc func openReleasePage() {
        if let up = availableUpdate { NSWorkspace.shared.open(up.pageURL) }
    }

    // Открыть репозиторий в браузере — действие кнопки GitHub в окне About.
    @objc func openRepo() {
        NSWorkspace.shared.open(URL(string: "https://github.com/Inhum/focus-radio")!)
    }

    // --- Media keys + Now Playing (Control Center) ---
    // Регистрируем команды в MPRemoteCommandCenter и обновляем NowPlayingInfoCenter
    // при старте/остановке. macOS маршрутизирует физическую Play/Pause клавишу тому
    // приложению, чья карточка сейчас в Now Playing — то есть нам, пока мы играем.
    func setupMediaControls() {
        let c = MPRemoteCommandCenter.shared()
        c.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlay(); return .success
        }
        c.playCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            if !self.isPlaying { self.togglePlay() }
            return .success
        }
        c.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            if self.isPlaying { self.togglePlay() }
            return .success
        }
    }

    func updateNowPlaying(playing: Bool) {
        let center = MPNowPlayingInfoCenter.default()
        guard playing else {
            center.nowPlayingInfo = nil
            center.playbackState = .stopped
            return
        }
        let s = stations[currentStationIdx]
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: "\(s.name) · \(s.genre)",
            MPMediaItemPropertyArtist: s.provider,
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: 1.0,
        ]
        if let icon = NSApp.applicationIconImage {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: icon.size) { _ in icon }
        }
        center.nowPlayingInfo = info
        center.playbackState = .playing
    }

    // Полностью разбираем плеер и связанные обозреватели.
    func teardownPlayer() {
        watchdog?.invalidate(); watchdog = nil
        pollTimer?.invalidate(); pollTimer = nil
        statusObs?.invalidate(); statusObs = nil
        errorObs?.invalidate(); errorObs = nil
        rateObs?.invalidate(); rateObs = nil
        for o in nObservers { NotificationCenter.default.removeObserver(o) }
        nObservers.removeAll()
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        currentItem = nil
        lastObservedTime = 0
        advanceChecks = 0
        declaredPlaying = false
    }

    func stopPlaying() {
        teardownPlayer()
        isPlaying = false
        playButton?.title = L("ui.play")
        setStatus(L("status.paused"), .idle)
        updateNowPlaying(playing: false)
        rlog("STOP")
    }

    // Учитывает PLS race: если станция ещё не получила свежие URL — ждёт до 1.5 с.
    func startPlayingCurrent() {
        let idx = currentStationIdx
        setStatus(L("status.refreshing"), .connecting)
        waitForPLS(idx: idx, timeout: 1.5) { [weak self] in
            guard let self = self, self.currentStationIdx == idx else { return }
            self.tryCurrentURL()
        }
    }

    func tryCurrentURL() {
        let station = stations[currentStationIdx]
        guard currentURLIdx < station.urls.count else {
            // Сначала пытаемся вернуться к исходным хардкодным URL (PLS мог дать стейл).
            if !triedHardcodedFallback && currentStationIdx < originalStationURLs.count {
                let orig = originalStationURLs[currentStationIdx]
                if orig != stations[currentStationIdx].urls && !orig.isEmpty {
                    rlog("FALLBACK \(station.name): exhausted, retry with original hardcoded urls")
                    stations[currentStationIdx].urls = orig
                    currentURLIdx = 0
                    triedHardcodedFallback = true
                    tryCurrentURL()
                    return
                }
            }
            // Все URL исчерпаны и хардкодный фоллбэк уже пробовали.
            // Пробуем ещё раз с самого начала (свежий AVPlayer часто помогает на flaky-сети).
            if stationRetryCount < maxStationRetries {
                stationRetryCount += 1
                rlog("RETRY \(station.name) attempt=\(stationRetryCount)/\(maxStationRetries)")
                currentURLIdx = 0
                triedHardcodedFallback = false
                Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                    self?.tryCurrentURL()
                }
                return
            }
            teardownPlayer()
            isPlaying = false
            playButton?.title = L("ui.play")
            setStatus(L("status.unavailable", station.name), .failed)
            rlog("EXHAUSTED \(station.name)")
            return
        }
        let urlStr = station.urls[currentURLIdx]
        guard let url = URL(string: urlStr) else {
            tryNextURL(reason: "bad-url"); return
        }

        teardownPlayer()

        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        // ВАЖНО: true (дефолт). С false плеер начинает играть без достаточного буфера и на
        // ряде потоков (Radio Paradise, NTS/radiomast) навсегда замирает на currentTime=0 —
        // те же URL при этом отлично играют в QuickTime (тоже AVFoundation). Раньше это
        // ошибочно приняли за гео-блок и выпилили станции. Не менять обратно на false.
        p.automaticallyWaitsToMinimizeStalling = true
        p.volume = volume
        player = p
        currentItem = item
        isPlaying = true
        playButton?.title = L("ui.pause")
        setStatus(L("status.connecting", station.name), .connecting)
        rlog("CONNECT \(station.name) url[\(currentURLIdx)]=\(urlStr)")

        // KVO
        statusObs = item.observe(\.status, options: [.new]) { it, _ in
            rlog("status=\(it.status.rawValue) err=\(String(describing: it.error))")
        }
        errorObs = item.observe(\.error, options: [.new]) { it, _ in
            if let e = it.error { rlog("item.error=\(e)") }
        }
        rateObs = p.observe(\.timeControlStatus, options: [.new]) { pl, _ in
            rlog("timeControlStatus=\(pl.timeControlStatus.rawValue) reason=\(String(describing: pl.reasonForWaitingToPlay))")
        }

        let nc = NotificationCenter.default
        nObservers.append(nc.addObserver(forName: .AVPlayerItemNewErrorLogEntry, object: item, queue: .main) { _ in
            if let ev = item.errorLog()?.events.last {
                rlog("errlog: comment=\(ev.errorComment ?? "?") status=\(ev.errorStatusCode) domain=\(ev.errorDomain)")
            }
        })
        nObservers.append(nc.addObserver(forName: .AVPlayerItemNewAccessLogEntry, object: item, queue: .main) { _ in
            if let ev = item.accessLog()?.events.last {
                rlog("acclog: uri=\(ev.uri ?? "?") bytes=\(ev.numberOfBytesTransferred) bitrate=\(ev.observedBitrate)")
            }
        })
        nObservers.append(nc.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self] n in
            rlog("FailedToPlayToEndTime err=\(String(describing: n.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey]))")
            self?.tryNextURL(reason: "failed-to-end")
        })
        nObservers.append(nc.addObserver(forName: .AVPlayerItemPlaybackStalled, object: item, queue: .main) { [weak self] _ in
            rlog("PlaybackStalled")
            self?.tryNextURL(reason: "stalled")
        })

        p.play()

        // Поллинг реального воспроизведения: currentTime должна расти, буфер должен быть непустым.
        let isAAC = urlStr.contains("-aac")
        // С automaticallyWaitsToMinimizeStalling=true плеер сперва набирает буфер, потом
        // играет — старт медленнее, поэтому watchdog щедрее (иначе ложный фоллбэк до старта).
        let watchdogSec: TimeInterval = isAAC ? 16.0 : 12.0
        let capturedPlayer = p

        // Прямой признак реального воспроизведения — байты, переданные через accessLog.
        var lastBytes: Int64 = 0
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            guard self.player === capturedPlayer, self.isPlaying else { t.invalidate(); return }
            let now = capturedPlayer.currentTime().seconds
            let buffered: Double = {
                if let r = capturedPlayer.currentItem?.loadedTimeRanges.first {
                    return r.timeRangeValue.duration.seconds
                }
                return 0
            }()
            let bytes = capturedPlayer.currentItem?.accessLog()?.events.last?.numberOfBytesTransferred ?? 0
            let bytesGrowing = bytes > lastBytes && bytes > 4096
            lastBytes = bytes
            let okStatus = capturedPlayer.timeControlStatus == .playing
            // Успех = плеер играет И поток реально ПРОДВИГАЕТСЯ: растут байты или currentTime.
            // Статический буфер (loadedTimeRanges > 0.5) НЕ считаем игрой — RP/NTS набирают
            // стартовый буфер ~1с и замирают на t=0, а curl тянет их поток нормально; засчёт
            // буфера давал ложный «зелёный». Признак настоящей игры — движение, не наличие данных.
            let timeAdvancing = now.isFinite && now > self.lastObservedTime + 0.05
            let realPlaying = okStatus && (bytesGrowing || timeAdvancing)
            if realPlaying {
                self.advanceChecks += 1
            } else {
                self.advanceChecks = 0
            }
            self.lastObservedTime = now.isFinite ? now : self.lastObservedTime
            if self.advanceChecks >= 2 && !self.declaredPlaying {
                self.declaredPlaying = true
                self.watchdog?.invalidate(); self.watchdog = nil
                self.setStatus(L("status.playing", station.provider, station.name), .playing)
                self.updateNowPlaying(playing: true)
                rlog("PLAYING \(station.name) t=\(now) buffered=\(buffered) bytes=\(bytes)")
            }
        }

        watchdog = Timer.scheduledTimer(withTimeInterval: watchdogSec, repeats: false) { [weak self] _ in
            guard let self = self, self.player === capturedPlayer, self.isPlaying else { return }
            if !self.declaredPlaying {
                let now = capturedPlayer.currentTime().seconds
                rlog("WATCHDOG \(station.name) url[\(self.currentURLIdx)] timeout — t=\(now) status=\(capturedPlayer.timeControlStatus.rawValue) err=\(String(describing: capturedPlayer.currentItem?.error))")
                self.tryNextURL(reason: "watchdog")
            }
        }
    }

    func tryNextURL(reason: String) {
        let station = stations[currentStationIdx]
        rlog("FALLBACK \(station.name) url[\(currentURLIdx)] -> url[\(currentURLIdx+1)]: \(reason)")
        currentURLIdx += 1
        tryCurrentURL()
    }

    // Здоровье станции — как в Voica проверка ключа: цветной кружок рядом со статусом.
    enum StationHealth { case idle, connecting, playing, failed }

    func setStatus(_ text: String, _ health: StationHealth) {
        statusLabel?.stringValue = text
        guard let dot = statusDot else { return }
        let dotImg = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)
        switch health {
        case .idle:
            dot.isHidden = true
        case .connecting:
            dot.image = dotImg; dot.contentTintColor = .systemYellow; dot.isHidden = false
        case .playing:
            dot.image = dotImg; dot.contentTintColor = .systemGreen;  dot.isHidden = false
        case .failed:
            dot.image = dotImg; dot.contentTintColor = .systemRed;    dot.isHidden = false
        }
    }

    func updateStatusIcon() {
        phase += 0.22
        let size = NSSize(width: 22, height: 18)
        let img = NSImage(size: size, flipped: false) { rect in
            let bars = 3, barW: CGFloat = 4, gap: CGFloat = 2
            let startX = (rect.width - CGFloat(bars) * barW - CGFloat(bars - 1) * gap) / 2
            for i in 0..<bars {
                let h: CGFloat = self.isPlaying
                    ? 3 + CGFloat(0.5 + 0.5 * sin(self.phase + Double(i) * 1.3)) * 13
                    : 3
                let r = NSRect(x: startX + CGFloat(i) * (barW + gap),
                               y: (rect.height - h) / 2, width: barW, height: h)
                NSColor.black.setFill()
                NSBezierPath(roundedRect: r, xRadius: 1, yRadius: 1).fill()
            }
            return true
        }
        img.isTemplate = true
        statusItem?.button?.image = img
    }

    // --- Самотест: прогоняем станции последовательно через таймеры, не блокируя главный run loop ---
    var testResults: [(String, Bool, String)] = []
    var testIdx: Int = 0
    var testStartTime: Date = Date()
    var testWaitTimer: Timer?
    let testPerStationTimeout: TimeInterval = 40.0  // 1.5с PLS + 8-12с × 3 URL × 2 попытки

    func runSelfTest() {
        rlog("=== SELF-TEST START: \(stations.count) stations ===")
        testResults = []
        testIdx = 0
        startNextTestStation()
    }

    func startNextTestStation() {
        if testIdx >= stations.count {
            finishSelfTest()
            return
        }
        let i = testIdx
        let st = stations[i]
        currentStationIdx = i
        currentURLIdx = 0
        triedHardcodedFallback = false
        stationRetryCount = 0
        testStartTime = Date()
        rlog("--- TEST [\(i)] \(st.provider) / \(st.name) ---")
        startPlayingCurrent()

        // Раз в 0.5с проверяем — заиграло ли, и не вышли ли за таймаут.
        // Регистрируем в .common mode: иначе AVPlayer внутри может удерживать RunLoop
        // в другом mode'е, и таймер перестанет тикать (наблюдалось elapsed=538s при таймауте 40s).
        testWaitTimer?.invalidate()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            let elapsed = Date().timeIntervalSince(self.testStartTime)
            if self.declaredPlaying && elapsed > 2.0 {
                t.invalidate()
                self.recordTestResult(passed: true, elapsed: elapsed)
            } else if elapsed > self.testPerStationTimeout {
                t.invalidate()
                self.recordTestResult(passed: false, elapsed: elapsed)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        testWaitTimer = timer
    }

    func recordTestResult(passed: Bool, elapsed: TimeInterval) {
        let i = testIdx
        let st = stations[i]
        let final = player?.currentTime().seconds ?? 0
        let detail = "t=\(String(format: "%.2f", final)) elapsed=\(String(format: "%.1f", elapsed))s urlIdx=\(currentURLIdx)"
        testResults.append((st.name, passed, detail))
        rlog(passed ? "RESULT [\(i)] PASS \(st.name) \(detail)" : "RESULT [\(i)] FAIL \(st.name) \(detail)")
        stopPlaying()
        testIdx += 1
        // Пауза 0.5с между станциями для гарантии тиар-дауна.
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.startNextTestStation()
        }
    }

    func finishSelfTest() {
        rlog("=== SELF-TEST SUMMARY ===")
        var failures = 0
        for (i, r) in testResults.enumerated() {
            let tag = r.1 ? "PASS" : "FAIL"
            FileHandle.standardError.write("  [\(i)] \(tag)  \(r.0)  — \(r.2)\n".data(using: .utf8)!)
            if !r.1 { failures += 1 }
        }
        FileHandle.standardError.write("=== \(testResults.count - failures)/\(testResults.count) passed ===\n".data(using: .utf8)!)
        exit(failures == 0 ? 0 : 1)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
delegate.isTestMode = CommandLine.arguments.contains("--test-all")
if let i = CommandLine.arguments.firstIndex(of: "--test-one"),
   i + 1 < CommandLine.arguments.count,
   let n = Int(CommandLine.arguments[i + 1]) {
    delegate.testOneIdx = n
}
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
