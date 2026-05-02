import Cocoa
import AVFoundation

let app = NSApplication.shared
let urlStr = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "https://ice6.somafm.com/dronezone-256-mp3"
let url = URL(string: urlStr)!
let item = AVPlayerItem(url: url)
let p = AVPlayer(playerItem: item)
p.automaticallyWaitsToMinimizeStalling = false

class D: NSObject, NSApplicationDelegate {
    var p: AVPlayer!
    var item: AVPlayerItem!
    var statusObs: NSKeyValueObservation?
    var rateObs: NSKeyValueObservation?
    func applicationDidFinishLaunching(_ n: Notification) {
        statusObs = item.observe(\.status, options:[.new]) { it,_ in
            print("status=\(it.status.rawValue) err=\(String(describing: it.error))")
        }
        rateObs = p.observe(\.timeControlStatus, options:[.new]) { pl,_ in
            print("tcs=\(pl.timeControlStatus.rawValue) reason=\(String(describing: pl.reasonForWaitingToPlay))")
        }
        NotificationCenter.default.addObserver(forName: .AVPlayerItemNewAccessLogEntry, object: item, queue: .main) { _ in
            if let e = self.item.accessLog()?.events.last {
                print("acclog uri=\(e.uri ?? "?") bytes=\(e.numberOfBytesTransferred) bitrate=\(e.observedBitrate)")
            }
        }
        NotificationCenter.default.addObserver(forName: .AVPlayerItemNewErrorLogEntry, object: item, queue: .main) { _ in
            if let e = self.item.errorLog()?.events.last {
                print("errlog \(e.errorComment ?? "?") status=\(e.errorStatusCode)")
            }
        }
        p.play()
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            let t = self.p.currentTime().seconds
            let buf = self.item.loadedTimeRanges.first?.timeRangeValue.duration.seconds ?? 0
            let bytes = self.item.accessLog()?.events.last?.numberOfBytesTransferred ?? 0
            print("poll t=\(t) buf=\(buf) bytes=\(bytes) tcs=\(self.p.timeControlStatus.rawValue)")
        }
        Timer.scheduledTimer(withTimeInterval: 12, repeats: false) { _ in exit(0) }
    }
}
let d = D()
d.p = p
d.item = item
app.delegate = d
app.setActivationPolicy(.accessory)
app.run()
