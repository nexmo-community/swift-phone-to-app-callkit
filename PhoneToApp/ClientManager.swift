import PushKit
import NexmoClient

typealias PushInfo = (payload: PKPushPayload, completion: () -> Void)

/*
 This class provides an interface to the Nexmo Client that can
 be accessed across the app. It handles logging the client in
 and updated to the client's status. The JWT is hardcoded but in
 your production app this should be retrieved from your server.
 */
final class ClientManager: NSObject {
    public var pushToken: Data?
    public var pushInfo: PushInfo?
    
    static let shared = ClientManager()
    
    static let jwt = "ALICE_JWT"
    
    override init() {
        super.init()
        initializeClient()
    }
    
    func initializeClient() {
        NXMClient.shared.setDelegate(self)
    }
    
    func login() {
        guard !NXMClient.shared.isConnected() else { return }
        NXMClient.shared.login(withAuthToken: ClientManager.jwt)
    }
    
    func isNexmoPush(with userInfo: [AnyHashable : Any]) -> Bool {
        return NXMClient.shared.isNexmoPush(userInfo: userInfo)
    }
    
    func invalidatePushToken() {
        self.pushToken = nil
        UserDefaults.standard.removeObject(forKey: Constants.pushToken)
        NXMClient.shared.disablePushNotifications(nil)
    }
    
    // MARK:-  Private
    
    /*
     This function process the payload from the voip push notification.
     This in turn will call didReceive for the app to handle the incoming call.
     */
    private func processNexmoPushPayload(with pushInfo: PushInfo) {
        guard let _ = NXMClient.shared.processNexmoPushPayload(pushInfo.payload.dictionaryPayload) else {
            print("Nexmo push processing error")
            return
        }
        pushInfo.completion()
        self.pushInfo = nil
    }
    
    /*
     This function enabled push notifications with the client
     if it has not already been done for the current token.
     */
    private func enableNXMPushIfNeeded(with token: Data) {
        if shouldRegisterToken(with: token) {
            NXMClient.shared.enablePushNotifications(withPushKitToken: token, userNotificationToken: nil, isSandbox: true) { error in
                if error != nil {
                    print("registration error: \(String(describing: error))")
                    return
                }
                print("push token registered")
                UserDefaults.standard.setValue(token, forKey: Constants.pushToken)
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

// MARK:-  NXMClientDelegate

extension ClientManager: NXMClientDelegate {
    
    /*
     When the status of the client changes, this function is called.
     The status is sent via the clientStatus notification.
     */
    func client(_ client: NXMClient, didChange status: NXMConnectionStatus, reason: NXMConnectionStatusReason) {
        let statusText: String
        
        switch status {
        case .connected:
            if let token = pushToken {
                enableNXMPushIfNeeded(with: token)
            }
            if let pushInfo = pushInfo {
                processNexmoPushPayload(with: pushInfo)
            }
            statusText = "Connected"
        case .disconnected:
            statusText = "Disconnected"
        case .connecting:
            statusText = "Connecting"
        @unknown default:
            statusText = "Unknown"
        }
        
        NotificationCenter.default.post(name: .clientStatus, object: statusText)
    }
    
    /*
     If the Nexmo client receives and error, this function is called.
     The status is sent via the clientStatus notification.
     */
    func client(_ client: NXMClient, didReceiveError error: Error) {
        NotificationCenter.default.post(name: .clientStatus, object: error.localizedDescription)
    }
    
    /*
     If the Nexmo client receives a call, this function is called.
     This is trigged by processing an incoming push notification.
     The call is sent via the incomingCall notification.
     */
    func client(_ client: NXMClient, didReceive call: NXMCall) {
        NotificationCenter.default.post(name: .incomingCall, object: call)
    }
}

// MARK:-  Constants

struct Constants {
    static let pushToken = "NXMPushToken"
    static let fromKeyPath = "nexmo.push_info.from_user.name"
}

extension Notification.Name {
    static let clientStatus = Notification.Name("Status")
    static let incomingCall = Notification.Name("Call")
    static let handledCallCallKit = Notification.Name("CallHandledCallKit")
    static let handledCallApp = Notification.Name("CallHandledApp")
}
