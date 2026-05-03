#!/usr/bin/env swift
// Меню-бар приложение для прослушивания радио для фокусной работы.
// Сборка: swiftc -O radio.swift -o radio && ./radio
// Самотест: ./radio --test-all

import Cocoa
import AVFoundation

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

    Station(provider: "Radio Paradise", name: "Mellow Mix", genre: "mellow eclectic",
        urls: ["https://stream.radioparadise.com/mellow-128"], plsURL: nil),
    Station(provider: "Radio Paradise", name: "Main Mix",   genre: "eclectic",
        urls: ["https://stream.radioparadise.com/mp3-128"],   plsURL: nil),
    Station(provider: "Radio Paradise", name: "Global Mix", genre: "world",
        urls: ["https://stream.radioparadise.com/global-128"], plsURL: nil),

    Station(provider: "NTS Mixtapes", name: "Slow Focus",  genre: "beatless ambient",
        urls: ["https://stream-mixtape-geo.ntslive.net/mixtape"],   plsURL: nil),
    Station(provider: "NTS Mixtapes", name: "Low Key",     genre: "chill / downtempo",
        urls: ["https://stream-mixtape-geo.ntslive.net/mixtape2"],  plsURL: nil),
    Station(provider: "NTS Mixtapes", name: "Sheet Music", genre: "classical",
        urls: ["https://stream-mixtape-geo.ntslive.net/mixtape35"], plsURL: nil),
    Station(provider: "NTS Mixtapes", name: "Expansions",  genre: "spiritual jazz",
        urls: ["https://stream-mixtape-geo.ntslive.net/mixtape3"],  plsURL: nil),
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

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
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
        playButton.title = "▶ Play"
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

        statusLabel = NSTextField(labelWithString: "Ready")
        statusLabel.frame = NSRect(x: 16, y: 32, width: 308, height: 18)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        v.addSubview(statusLabel)

        let quit = NSButton(frame: NSRect(x: 254, y: 4, width: 70, height: 22))
        quit.title = "Quit"; quit.bezelStyle = .rounded
        quit.target = NSApp
        quit.action = #selector(NSApplication.terminate(_:))
        v.addSubview(quit)

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
        startPlayingCurrent()
    }

    @objc func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown { popover.performClose(sender) }
        else { popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY) }
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
        playButton?.title = "▶ Play"
        statusLabel?.stringValue = "Paused"
        rlog("STOP")
    }

    // Учитывает PLS race: если станция ещё не получила свежие URL — ждёт до 1.5 с.
    func startPlayingCurrent() {
        let idx = currentStationIdx
        statusLabel?.stringValue = "Refreshing servers…"
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
            playButton?.title = "▶ Play"
            statusLabel?.stringValue = "All sources unavailable for \(station.name)"
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
        p.automaticallyWaitsToMinimizeStalling = false
        p.volume = volume
        player = p
        currentItem = item
        isPlaying = true
        playButton?.title = "⏸ Pause"
        statusLabel?.stringValue = "Connecting \(station.name)…"
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
        let watchdogSec: TimeInterval = isAAC ? 12.0 : 8.0
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
            // Успех = плеер играет И байты приходят (или буфер заполнен, или currentTime тикает)
            let timeAdvancing = now.isFinite && now > self.lastObservedTime + 0.05
            let realPlaying = okStatus && (bytesGrowing || buffered > 0.5 || timeAdvancing)
            if realPlaying {
                self.advanceChecks += 1
            } else {
                self.advanceChecks = 0
            }
            self.lastObservedTime = now.isFinite ? now : self.lastObservedTime
            if self.advanceChecks >= 2 && !self.declaredPlaying {
                self.declaredPlaying = true
                self.watchdog?.invalidate(); self.watchdog = nil
                self.statusLabel?.stringValue = "♪ \(station.provider) — \(station.name)"
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
