//
//  ExtensionDelegate.swift
//  NightscouterNow Extension
//
//  Created by Peter Ina on 10/4/15.
//  Copyright © 2015 Peter Ina. All rights reserved.
//

import WatchKit
import NightscouterWatchOSKit

class ExtensionDelegate: NSObject, WKExtensionDelegate {
    var timer: NSTimer?
    
    override init() {
        print(">>> Entering \(#function) <<<")
        WatchSessionManager.sharedManager.startSession()
        
        super.init()
    }
    
    func applicationDidFinishLaunching() {
        #if DEBUG
            print(">>> Entering \(#function) <<<")
        #endif
        
        WatchSessionManager.sharedManager.startSession()
    }
    
    func applicationDidBecomeActive() {
        #if DEBUG
            print(">>> Entering \(#function) <<<")
        #endif
        updateDataNotification(nil)
    }
    
    func applicationWillResignActive() {
        #if DEBUG
            print(">>> Entering \(#function) <<<")
        #endif
        
        self.timer?.invalidate()
        self.timer = nil
        
        WatchSessionManager.sharedManager.saveData()
    }
    
    func createUpdateTimer() -> NSTimer {
        let localTimer = NSTimer.scheduledTimerWithTimeInterval(Constants.StandardTimeFrame.FourMinutesInSeconds, target: self, selector: #selector(ExtensionDelegate.updateDataNotification(_:)), userInfo: nil, repeats: true)
        return localTimer
    }
    
    func updateDataNotification(timer: NSTimer?) -> Void {
        #if DEBUG
            print(">>> Entering \(#function) <<<")
        #endif
        
        let date = NSDate()
        let calendar = NSCalendar.currentCalendar()
        let components = calendar.components([.Second], fromDate: date)
        let delayedStart:Double=(Double)(10 - components.second)
        let dispatchTime: dispatch_time_t = dispatch_time(DISPATCH_TIME_NOW, Int64(delayedStart * Double(NSEC_PER_SEC)))
        dispatch_after(dispatchTime, dispatch_get_main_queue(), {
            print("ExtensionDelegate:   Posting \(NightscoutAPIClientNotification.DataIsStaleUpdateNow) notification at \(NSDate())")
            NSNotificationCenter.defaultCenter().postNotification(NSNotification(name: NightscoutAPIClientNotification.DataIsStaleUpdateNow, object: self))
            
            if (self.timer == nil) {
                self.timer = self.createUpdateTimer()
            }
        })
    }
}

