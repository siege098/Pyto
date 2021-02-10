//
//  BackgroundTask.swift
//
//  Created by Yaro on 8/27/16.
//  Copyright © 2016 Yaro. All rights reserved.
//

// https://github.com/yarodevuci/backgroundTask

import AVFoundation
import UIKit
import BackgroundTasks

@objc class BackgroundTask: NSObject {
    
    static private var count = 0
    
    // MARK: - Vars
    
    var player = AVAudioPlayer()
    var timer = Timer()
    var isActive = false
    
    @objc var scriptName = "Script"
    
    @objc var sendNotification = true
    
    @objc var delay: Double = 3600*6
    
    @objc var soundPath = Bundle.main.path(forResource: "blank", ofType: "wav")
    
    // MARK: - Methods
    
    @objc func startBackgroundTask() {
        
        isActive = true
        
        BackgroundTask.count += 1
        NotificationCenter.default.addObserver(self, selector: #selector(interruptedAudio), name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance())
        
        if BackgroundTask.count == 1 {
            playAudio()
        }
        
        if sendNotification {
            UNUserNotificationCenter.current().getNotificationSettings { (settings) in
                if settings.authorizationStatus == .notDetermined {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { (_, _) in }
                }
            }
        }
        
        var time = 0
        var i = 0
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = [.pad]
        DispatchQueue.main.async {
            _ = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] (timer) in
                
                guard let self = self else {
                    return
                }
                
                time += 1
                i += 1
                
                for scene in UIApplication.shared.connectedScenes {
                    if scene.activationState == .foregroundActive || scene.activationState == .foregroundInactive {
                        i = 0
                        break
                    }
                }
                
                if !self.isActive {
                    timer.invalidate()
                    return
                }
                                
                if Double(i) >= self.delay {
                    if time >= 3600*24 { // Running since more than a day
                        formatter.allowedUnits = [.day, .hour]
                    } else if time >= 3600 { // Running since more than an hour
                        formatter.allowedUnits = [.hour, .minute]
                    } else if time >= 60 { // Running since more than a minute
                        formatter.allowedUnits = [.minute, .second]
                    } else {
                        formatter.allowedUnits = [.second]
                    }
                    
                    if self.sendNotification, let str = formatter.string(from: TimeInterval(time)) {
                        PyNotificationCenter.scheduleNotification(title: self.scriptName, message: Localizable.Python.isRunning(script: self.scriptName, since: str), delay: 1)
                        i = 0
                    }
                }
            })
        }
    }
    
    @objc func stopBackgroundTask() {
        
        isActive = false
        
        BackgroundTask.count -= 1
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        
        if BackgroundTask.count == 0 {
            player.stop()
        }
    }
    
    @objc fileprivate func interruptedAudio(_ notification: Notification) {
        if notification.name == AVAudioSession.interruptionNotification && notification.userInfo != nil {
            let info = notification.userInfo!
            var intValue = 0
            (info[AVAudioSessionInterruptionTypeKey]! as AnyObject).getValue(&intValue)
            if intValue == 1 { playAudio() }
        }
    }
    
    fileprivate func playAudio() {
        
        guard let soundPath = soundPath else {
            return
        }
        
        do {
            let alertSound = URL(fileURLWithPath: soundPath)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: .mixWithOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            try self.player = AVAudioPlayer(contentsOf: alertSound)
            // Play audio forever by setting num of loops to -1
            self.player.numberOfLoops = -1
            self.player.prepareToPlay()
            self.player.play()
        } catch { print(error.localizedDescription) }
    }
    
    // MARK: - Background Fetch
    
    @objc static func scheduleFetch() {
        let request = BGAppRefreshTaskRequest(identifier: "pyto.backgroundfetch")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Unable to refresh: \(error.localizedDescription)")
        }
    }
    
    @objc static var backgroundScript: String? {
        get {
            guard let data = UserDefaults.standard.data(forKey: "backgroundScript") else {
                return nil
            }
            
            var isStale = false
            guard let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale) else {
                return nil
            }
            
            _ = url.startAccessingSecurityScopedResource()
            
            if !FileManager.default.fileExists(atPath: url.path) {
                return nil
            }
            
            return url.path
        }
        
        set {
            let url = URL(fileURLWithPath: newValue ?? "")
            UserDefaults.standard.set(try? url.bookmarkData(), forKey: "backgroundScript")
        }
    }
}
