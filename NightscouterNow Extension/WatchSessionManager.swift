//
//  WatchSessionManager.swift
//  WCApplicationContextDemo
//
//  Created by Natasha Murashev on 9/22/15.
//  Copyright © 2015 NatashaTheRobot. All rights reserved.
//

import WatchConnectivity

@available(watchOS 2.0, *)
public protocol DataSourceChangedDelegate {
    // func dataSourceDidUpdate(dataSource: [Site])
    func dataSourceDidUpdateSiteModel(model: WatchModel, atIndex index: Int)
    func dataSourceDidAddSiteModel(model: WatchModel)
    func dataSourceDidDeleteSiteModel(model: WatchModel, atIndex index: Int)
}

@available(watchOS 2.0, *)
public class WatchSessionManager: NSObject, WCSessionDelegate {
    
    public static let sharedManager = WatchSessionManager()
    private override init() {
        super.init()
    }
    
    private var dataSourceChangedDelegates = [DataSourceChangedDelegate]()
    
    private let session: WCSession = WCSession.defaultSession()
    
    private var sites: [Site] = []
    private var models: [WatchModel] = []
    
    
    public func startSession() {
        if WCSession.isSupported() {
            session.delegate = self
            session.activateSession()
        }
        
        if !session.receivedApplicationContext.isEmpty {
            let context = session.receivedApplicationContext
            processApplicationContext(context)
        }
    }
    
    public func addDataSourceChangedDelegate<T where T: DataSourceChangedDelegate, T: Equatable>(delegate: T) {
        dataSourceChangedDelegates.append(delegate)
    }
    
    public func removeDataSourceChangedDelegate<T where T: DataSourceChangedDelegate, T: Equatable>(delegate: T) {
        for (index, indexDelegate) in dataSourceChangedDelegates.enumerate() {
            if let indexDelegate = indexDelegate as? T where indexDelegate == delegate {
                dataSourceChangedDelegates.removeAtIndex(index)
                break
            }
        }
    }
}

// MARK: Application Context
// use when your app needs only the latest information
// if the data was not sent, it will be replaced
extension WatchSessionManager {
    public func session(session: WCSession, didReceiveFile file: WCSessionFile) {
       // print("didReceiveFile: \(file)")
        dispatch_async(dispatch_get_main_queue()) {
            // make sure to put on the main queue to update UI!
        }
    }
    
    public func session(session: WCSession, didReceiveUserInfo userInfo: [String : AnyObject]) {
       // print("didReceiveUserInfo: \(userInfo)")
    }
    
    // Receiver
    public func session(session: WCSession, didReceiveApplicationContext applicationContext: [String : AnyObject]) {
        // print("didReceiveApplicationContext: \(applicationContext)")
        
        processApplicationContext(applicationContext)
    }
    
    public func session(session: WCSession, didReceiveMessage message: [String : AnyObject], replyHandler: ([String : AnyObject]) -> Void) {
        processApplicationContext(message)
        
    }
    
    public func requestLatestAppContext() {
        let applicationData = [WatchPayloadPropertyKeys.actionKey: WatchAction.AppContext.rawValue]
        session.sendMessage(applicationData, replyHandler: {(context:[String : AnyObject]) -> Void in
            // handle reply from iPhone app here
            
            // print("recievedMessageReply: \(context)")
            self.processApplicationContext(context)
            
            }, errorHandler: {(error ) -> Void in
                // catch any errors here
                print("error: \(error)")
        })
    }
    
    func processApplicationContext(context: [String : AnyObject]) {
        // print("processApplicationContext \(context)")
        
        guard let action = WatchAction(rawValue: (context[WatchPayloadPropertyKeys.actionKey] as? String)!) else {
            print("No action was found, didReceiveMessage: \(context)")
            return
        }
        
        switch action {
            
        case .Update:
            print("update on watch framework")
            
            if let modelArray = context[WatchPayloadPropertyKeys.modelsKey] as? [[String: AnyObject]]{//, model = WatchModel(fromDictionary: modelDict) {
                    for modelDict in modelArray {
                    
                        if let model = WatchModel(fromDictionary: modelDict) {
                    if let pos = models.indexOf(model){
                        models[pos] = model
                        dispatch_async(dispatch_get_main_queue()) { [weak self] in
                            self?.dataSourceChangedDelegates.forEach { $0.dataSourceDidUpdateSiteModel(model, atIndex: pos) }
                        }
                        
                    } else {
                        models.append(model)
                        
                        dispatch_async(dispatch_get_main_queue()) { [weak self] in
                            self?.dataSourceChangedDelegates.forEach { $0.dataSourceDidAddSiteModel(model) }
                        }
                        
                    }
                        }
                }
            }
        case .Delete:
            if let modelArray = context[WatchPayloadPropertyKeys.modelsKey] as? [[String: AnyObject]]{//, model = WatchModel(fromDictionary: modelDict) {

                for modelDict in modelArray {
                    let model = WatchModel(fromDictionary: modelDict)!

                if let pos = models.indexOf(model){
                    models.removeAtIndex(pos)
                    dispatch_async(dispatch_get_main_queue()) { [weak self] in
                        self?.dataSourceChangedDelegates.forEach { $0.dataSourceDidDeleteSiteModel(model, atIndex: pos) }
                    }
                }
                }
            }
        default:
            break
        }
    }
    
    
    public func loadDataFor(site: Site, index: Int) {
        print(">>> Entering \(__FUNCTION__) <<<")
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            // Start up the API
            let nsApi = NightscoutAPIClient(url: site.url)
            //            if (self.lastUpdatedTime?.timeIntervalSinceNow > 120) || self.lastUpdatedTime == nil {
            // Get settings for a given site.
            print("Loading data for \(site.url!)")
            nsApi.fetchServerConfiguration { (result) -> Void in
                switch (result) {
                case let .Error(error):
                    // display error message
                    print("\(__FUNCTION__) ERROR recieved: \(error)")
                case let .Value(boxedConfiguration):
                    let configuration:ServerConfiguration = boxedConfiguration.value
                    // do something with user
                    nsApi.fetchDataForWatchEntry({ (watchEntry, watchEntryErrorCode) -> Void in
                        
                        site.configuration = configuration
                        site.watchEntry = watchEntry
                        let model = WatchModel(fromSite: site)!

                        dispatch_async(dispatch_get_main_queue()) { [weak self] in
                            self?.dataSourceChangedDelegates.forEach { $0.dataSourceDidUpdateSiteModel(model, atIndex: index) }
                        }
                    })
                }
            }
        }
    }
    

}
