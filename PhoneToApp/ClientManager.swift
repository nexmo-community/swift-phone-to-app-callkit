import PushKit
import VonageClientSDKVoice

/*
 This class provides an interface to the `VGVoiceClient` that can
 be accessed across the app. It handles logging in the client
 and updates to the client's status. The JWT is hardcoded but in
 your production app this should be retrieved from your server.
 */

protocol ClientManagerDelegate: AnyObject {
    func clientStatusUpdated(_ clientManager: ClientManager, status: String)
    func incomingCallInvite(_ clientManager: ClientManager, invite: VGVoiceInvite)
}

final class ClientManager: NSObject {
    public var pushToken: Data?
    private var client = VGVoiceClient()
    
    private weak var delegate: ClientManagerDelegate?
    
    static let shared = ClientManager()
    
    static let jwt = "ALICE_JWT"
    
    override init() {
        super.init()
        initializeClient()
    }
    
    func initializeClient() {
        let config = VGClientConfig(region: .US)
        client.setConfig(config)
        client.delegate = self
    }
    
    func login() {
        client.createSession(ClientManager.jwt) { error, sessionId in
            let statusText: String
            
            if error == nil {
                if let token = self.pushToken {
                    self.registerPushIfNeeded(with: token)
                }
                statusText = "Connected"
            } else {
                statusText = error!.localizedDescription
            }
            self.delegate?.clientStatusUpdated(self, status: statusText)
        }
    }
    
    func isVonagePush(with userInfo: [AnyHashable : Any]) -> Bool {
        VGVoiceClient.vonagePushType(userInfo) == .unknown ? false : true
    }
    
    func invalidatePushToken() {
        if let deviceId = UserDefaults.standard.object(forKey: Constants.deviceId) as? String {
            client.unregisterDeviceTokens(byDeviceId: deviceId) { error in
                if error == nil {
                    self.pushToken = nil
                    UserDefaults.standard.removeObject(forKey: Constants.pushToken)
                    UserDefaults.standard.removeObject(forKey: Constants.deviceId)
                }
            }
        }
        
    }
    
    /*
     This function process the payload from the voip push notification.
     This in turn will call didReceive for the app to handle the incoming call.
     */
    func processPushPayload(with payload: [AnyHashable : Any]) -> VGVoicePushInvite? {
        return client.processCallInvitePushData(payload, token: ClientManager.jwt)
    }
    
    // MARK:-  Private
    
    /*
     This function enabled push notifications with the client
     if it has not already been done for the current token.
     */
    private func registerPushIfNeeded(with token: Data) {
        if shouldRegisterToken(with: token) {
            client.registerDevicePushToken(token, userNotificationToken: nil, isSandbox: true) { error, deviceId in
                if error == nil {
                    print("push token registered")
                    UserDefaults.standard.setValue(token, forKey: Constants.pushToken)
                    UserDefaults.standard.setValue(deviceId, forKey: Constants.deviceId)
                } else {
                    print("registration error: \(String(describing: error))")
                    return
                }
            }
        }
    }
    
    /*
     Push tokens only need to be registered once.
     So the token is stored locally and is invalidated if the incoming
     token is new.
     */
    private func shouldRegisterToken(with token: Data) -> Bool {
        let storedToken = UserDefaults.standard.object(forKey: Constants.pushToken) as? Data
        
        if let storedToken = storedToken, storedToken == token {
            return false
        }
        
        invalidatePushToken()
        return true
    }
    
}

// MARK:-  VGVoiceClientDelegate

extension ClientManager: VGVoiceClientDelegate {

    /*
     If the Client receives a call, this function is called.
     For a push enabled device, if the app is not killed
     this function will also be called in addition to the
     `didReceiveIncomingPushWith` function on the `PKPushRegistryDelegate`
    */
    func voiceClient(_ client: VGVoiceClient, didReceive invite: VGVoiceInvite) {
        delegate?.incomingCallInvite(self, invite: invite)
    }
    
    func client(_ client: VGBaseClient, didReceiveSessionErrorWithReason reason: String) {
        delegate?.clientStatusUpdated(self, status: reason)
    }
    
    func voiceClient(_ client: VGVoiceClient, didReceiveHangupFor call: VGVoiceCall, withLegId legId: String, andQuality callQuality: VGRTCQuality) {
        NotificationCenter.default.post(name: .callHungUp, object: nil)
    }
}

// MARK:-  Constants

struct Constants {
    static let deviceId = "VGDeviceID"
    static let pushToken = "VGPushToken"
}

extension Notification.Name {
    static let callHungUp = Notification.Name("CallHungUp")
    static let handledCallCallKit = Notification.Name("CallHandledCallKit")
    static let handledCallApp = Notification.Name("CallHandledApp")
}
