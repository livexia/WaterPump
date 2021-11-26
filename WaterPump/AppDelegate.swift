//
//  AppDelegate.swift
//  WaterPump
//
//  Created by livexia on 2021/11/18.
//

import Cocoa

import UserNotifications

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var menu: NSMenu!

    private var statusItem: NSStatusItem = NSStatusBar.system.statusItem(withLength: 28.0)

    private let un: UNUserNotificationCenter = UNUserNotificationCenter.current()

    private var timeInterval: TimeInterval = 1500
    private var nextNotificationDate: Date?
    private var remainTime: TimeInterval?
    private var offsetTimeInterval: TimeInterval = 0
    private var isRunning: Bool = false
    private var isRandom: Bool = false


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // request notification auth
        self.un.requestAuthorization(options: [.alert, .sound]) { (authorized, error) in
            if authorized {
                print("Notification authorized")
            } else if !authorized {
                print("Notification not authorized")
            } else {
                print(error?.localizedDescription as Any)
            }
        }
        
        // Insert code here to initialize your application

        if let statusBarButton = statusItem.button {
            statusBarButton.image = #imageLiteral(resourceName: "StatusBarIcon")
            statusBarButton.image?.size = NSSize(width: 18.0, height: 18.0)
            statusBarButton.image?.isTemplate = true
        }

        statusItem.menu = menu
        
        menu.item(withTag: 5)?.submenu = getTimeIntervalSubMenu()

        let timer = Timer.scheduledTimer(timeInterval: 1,
                                         target: self,
                                         selector: #selector(refreshInfoMenu),
                                         userInfo: nil,
                                         repeats: true)
        RunLoop.current.add(timer, forMode: RunLoop.Mode.common)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    @objc
    private func loadSettingView() {
        print("Load View")
        let newViewController = ViewController()
        newViewController.loadView()
    }

    @objc
    private func refreshInfoMenu() {
        // 刷新时间间隔
        if let time = AppDelegate.convertTime(time: timeInterval) {
            menu.item(at: 0)?.title = "时间间隔：\(time)"
        } else {
            menu.item(at: 0)?.title = "时间间隔为空"
        }

        // 刷新截止时间
        if let date = nextNotificationDate {
            menu.item(at: 1)?.title = "下一次提醒：\(AppDelegate.getLocalDate(date: date))"
        } else {
            menu.item(at: 1)?.title = "没有提醒，请点击开始"
        }

        // 刷新剩余时间
        remainTime = nextNotificationDate?.timeIntervalSinceNow
        if let time = remainTime {
            if time <= 0 && isRunning {
                // 当剩余时间结束后马上发送提醒，并设置下一次的提醒时间
                sendNotification(self)
                nextNotificationDate = getNextNotificationDate()
            } else if let time = AppDelegate.convertTime(time: time) {
                menu.item(at: 2)?.isHidden = false
                menu.item(at: 2)?.title = "剩余时间：\(time)"
            } else {
                menu.item(at: 2)?.isHidden = true
            }
        } else {
            menu.item(at: 2)?.isHidden = true
        }
        print("refresh info")
    }

    private func getTimeIntervalSubMenu() -> NSMenu? {
        let subMenu = NSMenu()
        
        // 临时添加5秒时间间隔，用作测试
        let timeIntervalArray = [5, ] + stride(from: 15 * 60, to: 60 * 60, by: 5 * 60)
        for timeInterval in timeIntervalArray {
            do {
                if let title = AppDelegate.convertTime(time: TimeInterval(timeInterval)) {
                    let newItem = NSMenuItem(title: title,
                                             action: #selector(setTimeInterval),
                                             keyEquivalent: "")
                    newItem.tag = timeInterval
                    newItem.target = self
                    if timeInterval == 25 * 60 {
                        newItem.state = .on
                    }
                    subMenu.addItem(newItem)
                }
            }
        }
        return subMenu
    }

    @objc func setTimeInterval(sender: NSMenuItem) {
        // 移除原有时间间隔处的标记
        sender.parent?.submenu?.item(withTag: Int(timeInterval - offsetTimeInterval))?.state = .off
        // 设置随机时间间隔偏移
        timeInterval = TimeInterval(sender.tag) + offsetTimeInterval

        sender.state = .on
        resettingNotification()
        print("设置时间间隔为：\(timeInterval)s")
    }

    @IBAction func setRandomTimeInterval(sender: NSMenuItem) {
        if sender.state == .on {
            isRandom = false
            timeInterval -= offsetTimeInterval
            offsetTimeInterval = 0
        } else {
            isRandom = true
            let range = timeInterval * 0.1
            offsetTimeInterval = TimeInterval(.random(in: -range..<range))
            timeInterval += offsetTimeInterval
            print("增加随机时间间偏移：\(offsetTimeInterval)")
        }
        sender.state = sender.state == .on ? .off : .on
        resettingNotification()
    }

    @objc
    private func quit() {
        NSApp.terminate(self)
    }

    @objc func resettingNotification() {
        if isRunning {
            // 根据新的时间间隔设置下一次的提醒时间
            nextNotificationDate = getNextNotificationDate()
        }
        refreshInfoMenu()
    }

    @IBAction func settingNotification(sender: NSMenuItem) {
        if sender.state == .on {
            removeNotification()
        } else {
            isRunning = true
            // 根据新的时间间隔设置下一次的提醒时间
            nextNotificationDate = getNextNotificationDate()
        }
        sender.state = sender.state == .on ? .off : .on
    }

    @objc private func sendNotification(_ sender: Any) {

        self.un.getNotificationSettings { (settings) in
            if settings.authorizationStatus == .authorized {
                let content = UNMutableNotificationContent()
                content.title = "喝点水"
                content.subtitle = "改变一下姿势吧"
                if let time = AppDelegate.convertTime(time: self.timeInterval) {
                    content.body = "已经保持现在的状态\(time)了，让眼睛休息一下，喝点水，改变一下姿势和状态吧"
                }
                content.sound = UNNotificationSound.default

                let id = "Water Pump"
                
                // 立即（1s后）发出提醒通知
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                self.un.add(request) { (error) in
                    if error != nil { print(error?.localizedDescription as Any)}
                }
                print("发送提醒")
                self.isRunning = true
                self.refreshInfoMenu()
            }
        }
    }

    @objc private func removeNotification() {
        un.getPendingNotificationRequests { (notificationRequests) in
            var identifiers: [String] = []
            for notification: UNNotificationRequest in notificationRequests {
                if notification.identifier == "Water Pump" {
                    identifiers.append(notification.identifier)
                }
            }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
            self.isRunning = false
            self.nextNotificationDate = nil
            print("Remove notifications: \(identifiers)")

        }
        refreshInfoMenu()
    }

    static func getLocalDate(date: Date) -> String {
        let format = DateFormatter()
        format.timeZone = .current
        format.dateFormat = "yyyy-MM-dd HH:mm:ss"

        return format.string(from: date)
    }

    static func convertTime(time: TimeInterval) -> String? {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        formatter.allowedUnits = [.day, .hour, .minute, .second]

        return formatter.string(from: time)
    }
    
    private func getNextNotificationDate() -> Date {
        return .now + timeInterval + 1
    }

    @IBAction func showAbout(_ sender: Any) {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

}
