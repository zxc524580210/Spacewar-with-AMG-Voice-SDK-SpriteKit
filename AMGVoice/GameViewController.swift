//
//  GameViewController.swift
//  AMGVoice
//
//  Created by GongYuhua on 2017/3/2.
//  Copyright © 2017年 Agora. All rights reserved.
//

import UIKit
import SpriteKit
import AVFoundation

class GameViewController: UIViewController {
    
    @IBOutlet weak var roomNameLabel: UILabel!
    @IBOutlet weak var sceneView: SKView!
    @IBOutlet weak var settingsButton: UIButton!
    @IBOutlet weak var muteAudioButton: UIButton!
    @IBOutlet weak var callButton: UIButton!
    @IBOutlet weak var commanderButton: UIButton!
    
    var roomName: String!
    var gameProfile = GameProfile.free()
    
    fileprivate lazy var backgroundPlayer: AVAudioPlayer = {
        let player = try! AVAudioPlayer(contentsOf: self.backgroundMusicURL)
        player.numberOfLoops = -1
        return player
    }()
    fileprivate lazy var backgroundMusicURL: URL = {
        let fileURL = Bundle.main.url(forResource: "space", withExtension: "mp3")!
        return fileURL
    }()
    fileprivate var gameScene: GameScene?
    
    //MARK: engine
    fileprivate var agoraKit: AgoraRtcEngineKitForGaming!
    fileprivate var isInAgoraAudio = false {
        didSet {
            callButton?.setImage(isInAgoraAudio ? #imageLiteral(resourceName: "btn_speaker_blue") : #imageLiteral(resourceName: "btn_speaker"), for: .normal)
            muteAudioButton?.isHidden = !isInAgoraAudio
            commanderButton?.isHidden = !isInAgoraAudio || gameProfile.isFree()
            if !isInAgoraAudio {
                isAudioMuted = false
                isCommander = gameProfile.isCommander()
            }
        }
    }
    fileprivate var isAudioMuted = false {
        didSet {
            muteAudioButton?.setImage(isAudioMuted ? #imageLiteral(resourceName: "btn_mute_blue") : #imageLiteral(resourceName: "btn_mute"), for: .normal)
        }
    }
    fileprivate var isCommander = false {
        didSet {
            commanderButton?.setImage(isCommander ? #imageLiteral(resourceName: "btn_commder_blue") : #imageLiteral(resourceName: "btn_commder"), for: .normal)
        }
    }
    
    fileprivate var pitch: CGFloat = 1
    fileprivate var voice: CGFloat = 100
    fileprivate var bgm: CGFloat = 100
    fileprivate var effect: CGFloat = 100
    fileprivate var useAudioMixing = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        roomNameLabel.text = roomName
        
        sceneView.showsFPS = true
        sceneView.showsNodeCount = true
        sceneView.ignoresSiblingOrder = true
        
        loadAgoraKit()
        playBackGroundMusic(fromTime: 0)
        
        NotificationCenter.default.addObserver(forName: .UIApplicationWillEnterForeground, object: nil, queue: nil) { [weak self] _ in
            self?.agoraKit.resume();
        }
        
        NotificationCenter.default.addObserver(forName: .UIApplicationDidEnterBackground, object: nil, queue: nil) { [weak self] _ in
            self?.agoraKit.pause();
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let scene = GameScene(size: sceneView.bounds.size)
        scene.scaleMode = .resizeFill
        scene.eventDelegate = self
        sceneView.presentScene(scene)
        
        gameScene = scene
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let segueId = segue.identifier else {
            return
        }
        
        switch segueId {
        case "gameVCPopSettingsVC":
            let settingsVC = segue.destination as! AudioSettingsViewController
            settingsVC.delegate = self
            settingsVC.pitch = pitch
            settingsVC.voice = voice
            settingsVC.bgm = bgm
            settingsVC.effect = effect
            settingsVC.useAudioMixing = useAudioMixing
            settingsVC.isSliderEnabled = isInAgoraAudio
            settingsVC.popoverPresentationController?.sourceView = settingsButton
            settingsVC.popoverPresentationController?.delegate = self
        default: return
        }
    }
    
    @IBAction func doMutePressed(_ sender: UIButton) {
        isAudioMuted = !isAudioMuted
        agoraKit.muteLocalAudioStream(isAudioMuted)
    }
    
    @IBAction func doCallPressed(_ sender: UIButton) {
        if isInAgoraAudio {
            leaveChannel()
        } else {
            joinChannel()
        }
        
        isInAgoraAudio = !isInAgoraAudio
    }
    
    @IBAction func doCommanderPressed(_ sender: UIButton) {
        isCommander = !isCommander
        if isInAgoraAudio {
            let role: AgoraRtcClientRole = isCommander ? .clientRole_Broadcaster : .clientRole_Audience
            agoraKit?.setClientRole(role)
        }
    }
    
    @IBAction func doClosePressed(_ sender: UIButton) {
        leaveGame()
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
}

private extension GameViewController {
    func playBackGroundMusic(fromTime time: TimeInterval) {
        backgroundPlayer.currentTime = time
        backgroundPlayer.play()
    }
    
    func switchBackGroundMusicToPlayer() {
        guard !backgroundPlayer.isPlaying else {
            return
        }
        
        var current: TimeInterval = 0
        
        if let position = agoraKit?.getAudioMixingCurrentPosition() {
            current = TimeInterval(position) / 1000
        }
        agoraKit?.stopAudioMixing()
        
        playBackGroundMusic(fromTime: current)
    }
    
    func switchBackGroundMusicToAudioMixing() {
        guard backgroundPlayer.isPlaying else {
            return
        }
        
        let current = backgroundPlayer.currentTime
        backgroundPlayer.stop()
        
        agoraKit?.startAudioMixing(backgroundMusicURL.path, loopback: true, replace: false, cycle: -1, playTime: Int(current*1000))
    }
    
    func leaveGame() {
        if isInAgoraAudio {
            leaveChannel()
        }
        
        backgroundPlayer.stop()
        let _ = navigationController?.popViewController(animated: true)
    }
}

//MARK: Agora SDK
private extension GameViewController {
    func loadAgoraKit() {
        agoraKit = AgoraRtcEngineKitForGaming.sharedEngine(withAppId:KeyCenter.appId, delegate: self)!
        agoraKit.setLogFile(FileCenter.audioLogFilePath())
        agoraKit.setLogFilter(AgoraRtcLogFilter.logFilter_Debug.rawValue)
        
        agoraKit.setChannelProfile(gameProfile.channelProfile)
        agoraKit.enableAudioVolumeIndication(200, smooth: 3)
        
        isCommander = gameProfile.isCommander()
    }
    
    func joinChannel() {
        let code = agoraKit.joinChannel(roomName, info: nil, uid: 0)
        
        if code != 0 {
            DispatchQueue.main.async(execute: {
                self.gameScene?.alertString("Join channel failed: \(code)")
            })
        }
        
        if let role = gameProfile.clientRole {
            agoraKit?.setClientRole(role)
        }
    }
    
    func leaveChannel() {
        switchBackGroundMusicToPlayer()
        
        agoraKit.leaveChannel()
        resumeAudioSettingsToDefalutValue()
        gameScene?.removeAllSpeakers()
    }
    
    func resumeAudioSettingsToDefalutValue() {
        pitch = 1
        voice = 100
        bgm = 100
        effect = 100
    }
}

extension GameViewController: AgoraRtcEngineKitForGamingDelegate {
    func rtcEngine(_ engine: AgoraRtcEngineKitForGaming!, didJoinChannel channel: String!, withUid uid: UInt, elapsed: Int) {
        if useAudioMixing {
            switchBackGroundMusicToAudioMixing()
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKitForGaming!, didJoinedOfUid uid: UInt, elapsed: Int) {
        gameScene?.addSpeaker(of: uid)
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKitForGaming!, didOfflineOfUid uid: UInt, reason: AgoraRtcUserOfflineReason) {
        gameScene?.removeSpeaker(of: uid)
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKitForGaming!, reportAudioVolumeIndicationOfSpeakers speakers: [Any]!, totalVolume: Int) {
        guard let speakers = speakers as? [AgoraRtcAudioVolumeInfo] else {
            return
        }
        
        for speaker in speakers {
            let uid = speaker.uid
            if uid != 0 {
                gameScene?.showVolume(speaker.volume, of: uid)
            }
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKitForGaming!, didOccurWarning warningCode: AgoraRtcWarningCode) {
        let code = warningCode.rawValue
        let msg = AgoraRtcEngineKitForGaming.getErrorDescription(code)!
        gameScene?.alertString("Engine occur warning: \(code) \(msg)")
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKitForGaming!, didOccurError errorCode: AgoraRtcErrorCode) {
        let code = errorCode.rawValue
        let msg = AgoraRtcEngineKitForGaming.getErrorDescription(code)!
        gameScene?.alertString("Engine occur error: \(code) \(msg)")
    }
}


extension GameViewController: GameSceneDelegate {
    func gameScene(scene: GameScene, didMoveSpeakerOfUid uid: UInt, pan : CGFloat, gain: CGFloat) {
        print("didMoveSpeakerOfUid: \(uid), pan: \(pan), gain: \(gain)")
        agoraKit?.setRemoteVoicePosition(uid, pan: Double(pan), gain: Double(gain))
    }
    
    func gameSceneShouldPlayCollideSound(scene: GameScene) -> Bool {
        return !isInAgoraAudio
    }
    
    func gameScene(scene: GameScene, didCollideAtPan pan: CGFloat) {
        let path = Bundle.main.path(forResource: "boom", ofType: "mp3")!
        agoraKit?.playEffect(0, filePath: path, loop: false, pitch: 1, pan: Double(pan), gain: 100)
    }
}

extension GameViewController: AudioSettingsVCDelegate {
    func audioSettingsVC(audioSettingsVC: AudioSettingsViewController, didChangePitchValueTo pitch: CGFloat) {
        self.pitch = pitch
        agoraKit?.setLocalVoicePitch(Double(pitch))
    }
    
    func audioSettingsVC(audioSettingsVC: AudioSettingsViewController, didChangeVoiceValueTo voice: CGFloat) {
        self.voice = voice
        agoraKit?.adjustRecordingSignalVolume(Int(voice))
    }
    
    func audioSettingsVC(audioSettingsVC: AudioSettingsViewController, didChangeBgmValueTo bgm: CGFloat) {
        self.bgm = bgm
        agoraKit?.adjustAudioMixingVolume(Int(bgm))
    }
    
    func audioSettingsVC(audioSettingsVC: AudioSettingsViewController, didChangeEffectValueTo effect: CGFloat) {
        self.effect = effect
        agoraKit?.setEffectsVolume(Double(effect))
    }
    
    func audioSettingsVC(audioSettingsVC: AudioSettingsViewController, didChangeUseAudioMixingTo useAudioMixing: Bool) {
        guard self.useAudioMixing != useAudioMixing else {
            return
        }
        
        self.useAudioMixing = useAudioMixing
        if isInAgoraAudio {
            if useAudioMixing {
                switchBackGroundMusicToAudioMixing()
            } else {
                switchBackGroundMusicToPlayer()
            }
        }
    }
}

extension GameViewController: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
}
