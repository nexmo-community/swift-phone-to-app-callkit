//
//  ViewController.swift
//  PhoneToApp
//
//  Created by Abdulhakim Ajetunmobi on 06/07/2020.
//  Copyright © 2020 Vonage. All rights reserved.
//

import UIKit
import VonageClientSDKVoice

class ViewController: UIViewController {
    
    private let connectionStatusLabel = UILabel()
    private var call: VGVoiceCall?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        connectionStatusLabel.text = "Connected"
        connectionStatusLabel.textAlignment = .center
        connectionStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(connectionStatusLabel)
        
        view.addConstraints([
            connectionStatusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            connectionStatusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        
        NotificationCenter.default.addObserver(self, selector: #selector(callHandled), name: .handledCallCallKit, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func displayIncomingCallAlert(invite: VGVoiceInvite) {
        let from = invite.from.id ?? "Unknown"
        
        let alert = UIAlertController(title: "Incoming call from", message: from, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Answer", style: .default, handler: { _ in
            invite.answer { error, call in
                if error == nil {
                    self.call = call
                    NotificationCenter.default.post(name: .handledCallApp, object: nil)
                }
            }
        }))
        
        alert.addAction(UIAlertAction(title: "Reject", style: .default, handler: { _ in
            invite.reject { error in
                if error == nil {
                    NotificationCenter.default.post(name: .handledCallApp, object: nil)
                }
            }
        }))
        
        self.present(alert, animated: true, completion: nil)
    }
}

extension ViewController: ClientManagerDelegate {
    /*
     When the Client status changes,
     This function will update the connectionStatusLabel.
     */
    func clientStatusUpdated(_ clientManager: ClientManager, status: String) {
        connectionStatusLabel.text = status
    }
    
    /*
     When the app receives a call invite,
     It will display an alert to allow for the call to be answered.
     */
    func incomingCallInvite(_ clientManager: ClientManager, invite: VGVoiceInvite) {
        DispatchQueue.main.async { [weak self] in
            self?.displayIncomingCallAlert(invite: invite)
        }
    }
    
    /*
     If the call is handled with the CallKit UI,
     the handledCallCallKit notification will call this function.
     This function will check if the incoming call alert is showing and dismiss it.
     */
    @objc func callHandled() {
        DispatchQueue.main.async { [weak self] in
            if self?.presentedViewController != nil {
                self?.dismiss(animated: true, completion: nil)
            }
        }
    }
}
