import CallKit
import AVFoundation
import VonageClientSDKVoice

struct PushCall {
    var invite: VGVoicePushInvite?
    var call: VGVoiceCall?
}

final class ProviderDelegate: NSObject {
    private let provider: CXProvider
    private let callController = CXCallController()
    private var activeCall: PushCall? = PushCall()
    
    override init() {
        provider = CXProvider(configuration: ProviderDelegate.providerConfiguration)
        super.init()
        provider.setDelegate(self, queue: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(callHandled), name: .handledCallApp, object:nil)
        NotificationCenter.default.addObserver(self, selector: #selector(callHungUp), name: .callHungUp, object:nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    static var providerConfiguration: CXProviderConfiguration = {
        let providerConfiguration = CXProviderConfiguration(localizedName: "Vonage Call")
        providerConfiguration.supportsVideo = false
        providerConfiguration.maximumCallsPerCallGroup = 1
        providerConfiguration.supportedHandleTypes = [.generic, .phoneNumber]
        return providerConfiguration
    }()
    
    /*
     This function, called when the voip push notification arrives,
     reports the incoming call to the system. This triggers the CallKit UI.
     */
    func reportCall(invite: VGVoicePushInvite, completion: @escaping () -> Void) {
        if let callUUID = invite.callUUID {
            activeCall?.invite = invite
            let update = CXCallUpdate()
            update.localizedCallerName = invite.from ?? "Vonage call"
            update.hasVideo = false
            
            provider.reportNewIncomingCall(with: callUUID, update: update) { error in
                if error == nil {
                    completion()
                }
            }
        }
    }
    
    func reportFailedCall(completion: @escaping () -> Void) {
        let uuid = UUID()
        provider.reportNewIncomingCall(with: uuid, update: .init()) { error in
            completion()
            self.endCallWithUUID(uuid)
        }
    }
    
    private func endCallWithUUID(_ uuid: UUID) {
        let action = CXEndCallAction(call: uuid)
        hangup(action: action)
    }
    
    private func hangup(action: CXEndCallAction) {
        if activeCall?.call == nil {
            endCallTransaction(action: action)
        } else {
            activeCall?.call?.hangup({ error in
                if error == nil {
                    self.endCallTransaction(action: action)
                }
            })
        }
    }
    
    /*
     When a call is ended,
     the callController.request function completes the action.
     */
    private func endCallTransaction(action: CXEndCallAction) {
        self.callController.request(CXTransaction(action: action)) { error in
            if error == nil {
                self.activeCall = PushCall()
                action.fulfill()
            } else {
                action.fail()
            }
        }
    }
    
    /*
     If the app is in the foreground and the call is answered via the
     ViewController alert, there is no need to display the CallKit UI.
     */
    @objc private func callHandled() {
        provider.invalidate()
    }
    
    /*
     This is ends the call if the `didReceiveHangupFor` function on the
     `VGVoiceCallDelegate` is called.
     */
    @objc private func callHungUp() {
        if let callUUID = activeCall?.invite?.callUUID {
            activeCall?.call = nil
            endCallWithUUID(callUUID)
        }
    }
}

extension ProviderDelegate: CXProviderDelegate {
    
    func providerDidReset(_ provider: CXProvider) {
        activeCall = PushCall()
    }
    
    /*
     When the call is answered via the CallKit UI, this function is called.     
     The handledCallCallKit notification is sent so that the ViewController
     knows that the call has been handled by CallKit and can dismiss the alert.
     */
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        NotificationCenter.default.post(name: .handledCallCallKit, object: nil)
        activeCall?.invite?.answer({ error, call in
            if error == nil {
                self.activeCall?.call = call
                action.fulfill()
            } else {
                action.fail()
            }
        })
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        hangup(action: action)
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        VGVoiceClient.enableAudio(audioSession)
        
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        VGVoiceClient.disableAudio(audioSession)
    }
}
