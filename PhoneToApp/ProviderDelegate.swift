import CallKit
import NexmoClient
import AVFoundation

struct PushCall {
    var call: NXMCall?
    var uuid: UUID?
    var answerAction: CXAnswerCallAction?
}

final class ProviderDelegate: NSObject {
    private let provider: CXProvider
    private let callController = CXCallController()
    private var activeCall: PushCall? = PushCall()
    
    override init() {
        provider = CXProvider(configuration: ProviderDelegate.providerConfiguration)
        super.init()
        provider.setDelegate(self, queue: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(callReceived(_:)), name: .incomingCall, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(callHandled), name: .handledCallApp, object:nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    static var providerConfiguration: CXProviderConfiguration = {
        let providerConfiguration = CXProviderConfiguration(localizedName: "Vonage Call")
        providerConfiguration.supportsVideo = false
        providerConfiguration.maximumCallsPerCallGroup = 1
        providerConfiguration.supportedHandleTypes = [.generic]
        return providerConfiguration
    }()
}

extension ProviderDelegate: NXMCallDelegate {
    /*
     The NXMCallDelegate keeps track of the call.
     Particularly, when the call receives an error
     or enters an end state hangup is called.
     */
    func call(_ call: NXMCall, didReceive error: Error) {
        print(error)
        hangup()
    }
    
    func call(_ call: NXMCall, didUpdate callMember: NXMMember, with status: NXMCallMemberStatus) {
        switch status {
        case .cancelled, .failed, .timeout, .rejected, .completed:
            hangup()
        default:
            break
        }
    }
    
    func call(_ call: NXMCall, didUpdate callMember: NXMMember, isMuted muted: Bool) {}
    
    /*
     When a call is ended,
     the callController.request function completes the action.
     */
    private func hangup() {
        if let uuid = activeCall?.uuid {
            activeCall?.call?.hangup()
            activeCall = PushCall()
            
            let action = CXEndCallAction(call: uuid)
            let transaction = CXTransaction(action: action)
            
            callController.request(transaction) { error in
                if let error = error {
                    print(error)
                }
            }
        }
    }
}

extension ProviderDelegate: CXProviderDelegate {
    
    func providerDidReset(_ provider: CXProvider) {
        activeCall = PushCall()
    }
    
    /*
     When the call is answered via the CallKit UI, this function is called.
     If the device is locked, the client needs time to reinitialize,
     so the CXAnswerCallAction is stored for later, as calling fulfill will
     trigger the provider:didActivateAudioSession: function and pickup the call.
     
     The handledCallCallKit notification is sent so that the ViewController
     knows that the call has been handled by CallKit and can dismiss the alert.
     */
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        NotificationCenter.default.post(name: .handledCallCallKit, object: nil)
        configureAudioSession()
        activeCall?.answerAction = action
        
        if activeCall?.call != nil {
            action.fulfill()
        }
    }
    
    private func answerCall(with action: CXAnswerCallAction) {
        activeCall?.call?.answer(nil)
        activeCall?.call?.setDelegate(self)
        activeCall?.uuid = action.callUUID
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        hangup()
        action.fulfill()
    }
    
    /*
     When the CXAnswerCallAction is fulfilled CallKit activates the audio session,
     here make sure that the NXMCall object is ready and answer the call.
     */
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        assert(activeCall?.answerAction != nil, "Call not ready - see provider(_:perform:CXAnswerCallAction)")
        assert(activeCall?.call != nil, "Call not ready - see callReceived")
        answerCall(with: activeCall!.answerAction!)
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        hangup()
    }
    
    /*
     This function, called when the voip push notification arrives,
     reports the incoming call to the system. This triggers the CallKit UI.
     */
    func reportCall(callerID: String) {
        let update = CXCallUpdate()
        let callerUUID = UUID()
        
        update.remoteHandle = CXHandle(type: .generic, value: callerID)
        update.localizedCallerName = callerID
        update.hasVideo = false
        
        provider.reportNewIncomingCall(with: callerUUID, update: update) { [weak self] error in
            guard error == nil else { return }
            self?.activeCall?.uuid = callerUUID
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
     This function is called with the incomingCall notification.
     If the device is locked, it will fulfil the CXAnswerCallAction.
     This will tell CallKit to activate the audio session.
     */
    @objc private func callReceived(_ notification: NSNotification) {
        if let call = notification.object as? NXMCall {
            activeCall?.call = call
            activeCall?.answerAction?.fulfill()
        }
    }
    
    /*
     When the device is locked, the AVAudioSession needs to be configured.
     You can read more about this issue here https://forums.developer.apple.com/thread/64544
     */
    private func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSession.Category.playAndRecord, mode: .default)
            try audioSession.setMode(AVAudioSession.Mode.voiceChat)
        } catch {
            print(error)
        }
    }
}
