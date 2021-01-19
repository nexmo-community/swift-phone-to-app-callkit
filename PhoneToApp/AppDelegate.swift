//
//  AppDelegate.swift
//  PhoneToApp
//
//  Created by Abdulhakim Ajetunmobi on 06/07/2020.
//  Copyright © 2020 Vonage. All rights reserved.
//

import UIKit
import PushKit
import AVFoundation

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    private let clientManager = ClientManager.shared
    private let providerDelegate = ProviderDelegate()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        AVAudioSession.sharedInstance().requestRecordPermission { (granted:Bool) in
            print("Allow microphone use. Response: \(granted)")
        }
        registerForVoIPPushes()
        clientManager.login()
        return true
    }
    
    // MARK: UISceneSession Lifecycle
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {}
}

extension AppDelegate: PKPushRegistryDelegate {
    
    /*
     Register for voip push notifications.
     */
    private func registerForVoIPPushes() {
        let voipRegistry = PKPushRegistry(queue: nil)
        voipRegistry.delegate = self
        voipRegistry.desiredPushTypes = [PKPushType.voIP]
    }
    
    /*
     This provides the client manager with the push notification token.
     */
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        clientManager.pushToken = pushCredentials.token
    }
    
    /*
     If the push notification token becomes invalid,
     the client manager needs to remove it.
     */
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        clientManager.invalidatePushToken()
    }
    
    /*
     This function is called when the app receives a voip push notification.
     The client checks if it is a valid Nexmo push,
     then reports the call to the system using the providerDelegate.
     */
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        if clientManager.isNexmoPush(with: payload.dictionaryPayload) {
            let pushDict = payload.dictionaryPayload as NSDictionary
            let from = pushDict.value(forKeyPath: Constants.fromKeyPath) as? String
            
            clientManager.pushInfo = (payload, completion)
            providerDelegate.reportCall(callerID: from ?? "Vonage Call")
        }
    }
}
