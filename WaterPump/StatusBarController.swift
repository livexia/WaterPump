//
//  StatusBarController.swift
//  WaterPump
//
//  Created by livexia on 2021/11/18.
//

import AppKit

import UserNotifications

class StatusBarController {
    
    private var statusBar: NSStatusBar
    private var statusItem: NSStatusItem
    private var statusMenu: NSMenu
    
    private var un: UNUserNotificationCenter
    
    private var timeInterval: TimeInterval
    private var nextNotificationDate: Date?
    private var remainTime: TimeInterval?
    private var offsetTimeInterval: TimeInterval
    private var isRepeat: Bool
    private var isRunning: Bool
    private var isRandom: Bool

    
    init() {
        self.un = UNUserNotificationCenter.current();
        
        timeInterval = TimeInterval(1500)
        nextNotificationDate = nil
        remainTime = nil
        offsetTimeInterval = TimeInterval(0)
        isRepeat = true
        isRunning = false
        isRandom = false
        
        statusBar = NSStatusBar.init()
        // Creating a status bar item having a fixed length
        statusItem = statusBar.statusItem(withLength: 28.0)
        
        if let statusBarButton = statusItem.button {
            statusBarButton.image = #imageLiteral(resourceName: "StatusBarIcon")
            statusBarButton.image?.size = NSSize(width: 18.0, height: 18.0)
            statusBarButton.image?.isTemplate = true
        }
        
        statusMenu = NSMenu.init()
        
        do {
            statusMenu.addItem(withTitle: "时间间隔为空", action: nil, keyEquivalent: "")
            statusMenu.addItem(withTitle: "没有提醒，请点击开始", action: nil, keyEquivalent: "")
            statusMenu.addItem(withTitle: "剩余时间：nil", action: nil, keyEquivalent: "")
            statusMenu.addItem(.separator())
        }
        
        do {
            let newItem = NSMenuItem(title: "开始提醒",
                                     action: #selector(settingNotification),
                                     keyEquivalent: "s")
            newItem.tag = 4
            newItem.state = .off
            newItem.target = self
            statusMenu.addItem(newItem)
        }
        
        do {
            let newItem = NSMenuItem(title: "设置时间间隔",
                                     action: nil,
                                     keyEquivalent: "")
            newItem.tag = 5
            newItem.target = self
            newItem.submenu = getTimeIntervalSubMenu()
            statusMenu.addItem(newItem)
        }
        
        do {
            let newItem = NSMenuItem(title: "设置随机时间偏移",
                                     action: #selector(setRandomTimeInterval),
                                     keyEquivalent: "")
            newItem.tag = 6
            newItem.state = .off
            newItem.target = self
            statusMenu.addItem(newItem)
        }
        
        do {
            let newItem = NSMenuItem(title: "退出",
                                     action: #selector(quit),
                                     keyEquivalent: "q")
            newItem.tag = 8
            newItem.target = self
            statusMenu.addItem(newItem)
        }
        
        statusItem.menu = statusMenu
        
        let timer = Timer.scheduledTimer(timeInterval: 1,
                                         target: self,
                                         selector: #selector(refreshInfoMenu),
                                         userInfo: nil,
                                         repeats: true)
        RunLoop.current.add(timer, forMode: RunLoop.Mode.common)
    }
    
    @objc
    private func refreshInfoMenu() {
        // 刷新时间间隔
        if let time = StatusBarController.convertTime(time: timeInterval) {
            statusMenu.item(at: 0)?.title = "时间间隔：\(time)"
        } else {
            statusMenu.item(at: 0)?.title = "时间间隔为空"
        }
        
        // 刷新截止时间
        if let date = nextNotificationDate {
            statusMenu.item(at: 1)?.title = "下一次提醒：\(StatusBarController.getLocalDate(date: date))"
        } else {
            statusMenu.item(at: 1)?.title = "没有提醒，请点击开始"
        }
        
        // 刷新剩余时间
        remainTime = nextNotificationDate?.timeIntervalSinceNow;
        if let time = remainTime {
            if time < 0 {
                if isRepeat {
                    sendNotification(self)
                    remainTime = nextNotificationDate?.timeIntervalSinceNow;
                } else {
                    statusMenu.item(at: 1)?.title = "没有提醒，请点击开始"
                    statusMenu.item(at: 2)?.isHidden = true
                }
            } else if let time = StatusBarController.convertTime(time: time) {
                statusMenu.item(at: 2)?.isHidden = false
                statusMenu.item(at: 2)?.title = "剩余时间：\(time)"
            } else {
                statusMenu.item(at: 2)?.isHidden = true
            }
        } else {
            statusMenu.item(at: 2)?.isHidden = true
        }
        print("refresh info")
    }
    
    private func getTimeIntervalSubMenu() -> NSMenu? {
        let subMenu = NSMenu()
        do {
            if let title = StatusBarController.convertTime(time: TimeInterval(1)) {
                let newItem = NSMenuItem(title: title,
                                         action: #selector(setTimeInterval),
                                         keyEquivalent: "")
                newItem.tag = 1
                newItem.target = self
                subMenu.addItem(newItem)
            }
        }
        do {
                if let title = StatusBarController.convertTime(time: TimeInterval(60)) {
                let newItem = NSMenuItem(title: title,
                                         action: #selector(setTimeInterval),
                                         keyEquivalent: "")
                newItem.tag = 60
                newItem.target = self
                subMenu.addItem(newItem)
            }
        }
        for timeInterval in stride(from: 15 * 60, to: 60 * 60, by: 5 * 60) {
            do {
                if let title = StatusBarController.convertTime(time: TimeInterval(timeInterval)) {
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
        self.timeInterval = 1500
        refreshInfoMenu()
        print("设置默认时间间隔为：\(timeInterval)s")
        return subMenu
    }
    
    @objc
    private func setTimeInterval(sender: NSMenuItem) {
        // 移除原有时间间隔处的标记
        sender.parent?.submenu?.item(withTag: Int(timeInterval - offsetTimeInterval))?.state = .off
        // 设置随机时间间隔偏移
        timeInterval = TimeInterval(sender.tag) + offsetTimeInterval
        
        if timeInterval < 60 {
            isRepeat = false
        } else {
            isRepeat = true
        }
        
        sender.state = .on
        resettingNotification()
        print("设置时间间隔为：\(timeInterval)s，是否重复：\(isRepeat)")
    }
    
    @objc
    private func setRandomTimeInterval(sender: NSMenuItem) {
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
            removeNotification()
            sendNotification(self)
        }
        refreshInfoMenu()
    }
    
    @objc
    private func settingNotification(sender: NSMenuItem) {
        if sender.state == .on {
            removeNotification()
        } else {
            sendNotification(self)
        }
        if isRepeat {
            sender.state = sender.state == .on ? .off : .on
        }
    }
    
    @objc
    private func sendNotification(_ sender: Any) {
        // request notification auth
        self.un.requestAuthorization(options: [.alert, .sound]) { (authorized, error) in
            if authorized {
                print("Authorized")
            } else if !authorized {
                print("Not authorized")
            } else {
                print(error?.localizedDescription as Any)
            }
        }
        
        self.un.getNotificationSettings { (settings) in
            if settings.authorizationStatus == .authorized {
                let content = UNMutableNotificationContent()
                content.title = "喝点水"
                content.subtitle = "改变一下姿势吧"
                if let time = StatusBarController.convertTime(time: self.timeInterval) {
                    content.body = "已经保持现在的状态\(time)了，让眼睛休息一下，喝点水，改变一下姿势和状态吧"
                }
                content.sound = UNNotificationSound.default
                
                let id = "Water Pump"
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: self.timeInterval,
                                                                repeats: false)
                
                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                self.un.add(request) { (error) in
                    if error != nil { print(error?.localizedDescription as Any)}
                }
                self.nextNotificationDate = trigger.nextTriggerDate()
                print("增加提醒")
                self.isRunning = true
                self.refreshInfoMenu()
            }
        }
    }
    
    @objc
    private func removeNotification() {
        un.getPendingNotificationRequests { (notificationRequests) in
            var identifiers: [String] = []
            for notification: UNNotificationRequest in notificationRequests {
                if notification.identifier == "Water Pump" {
                    identifiers.append(notification.identifier)
                }
            }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
            self.isRunning = false
            print("Remove notifications: \(identifiers)")
            
        }
        self.nextNotificationDate = nil
        refreshInfoMenu()
    }
    
    static func getLocalDate(date: Date) -> String {
        let format = DateFormatter();
        format.timeZone = .current;
        format.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        return format.string(from: date)
    }
    
    static func convertTime(time: TimeInterval) -> String? {
        let formatter = DateComponentsFormatter();
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        formatter.allowedUnits = [.day, .hour, .minute, .second]
        
        return formatter.string(from: time)
    }
}
