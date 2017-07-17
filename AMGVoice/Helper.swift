//
//  Helper.swift
//  AMGVoice
//
//  Created by GongYuhua on 2017/3/15.
//  Copyright © 2017年 Agora. All rights reserved.
//

func + (left: CGPoint, right: CGPoint) -> CGPoint {
    return CGPoint(x: left.x + right.x, y: left.y + right.y)
}

func - (left: CGPoint, right: CGPoint) -> CGPoint {
    return CGPoint(x: left.x - right.x, y: left.y - right.y)
}

func * (point: CGPoint, scalar: CGFloat) -> CGPoint {
    return CGPoint(x: point.x * scalar, y: point.y * scalar)
}

func / (point: CGPoint, scalar: CGFloat) -> CGPoint {
    return CGPoint(x: point.x / scalar, y: point.y / scalar)
}

#if !(arch(x86_64) || arch(arm64))
fileprivate func sqrt(a: CGFloat) -> CGFloat {
    return CGFloat(sqrtf(Float(a)))
}
#endif

extension CGPoint {
    func length() -> CGFloat {
        return sqrt(x*x + y*y)
    }
    
    func normalized() -> CGPoint {
        return self / length()
    }
}

extension CGFloat {
    func displayString() -> String {
        return String(format: "%.1f", self)
    }
}

struct GameProfile {
    let channelProfile: AgoraRtcChannelProfile
    let clientRole: AgoraRtcClientRole?
    
    init(channelProfile: AgoraRtcChannelProfile, clientRole: AgoraRtcClientRole?) {
        self.channelProfile = channelProfile
        self.clientRole = clientRole
    }
    
    static let all: [GameProfile] = [GameProfile.free(),
                                     GameProfile.commander(),
                                     GameProfile.audience()]
    
    static func free() -> GameProfile {
        return GameProfile(channelProfile: .channelProfile_Game_Free_Mode, clientRole: nil)
    }
    
    static func commander() -> GameProfile {
        return GameProfile(channelProfile: .channelProfile_Game_Command_Mode, clientRole: .clientRole_Broadcaster)
    }
    
    static func audience() -> GameProfile {
        return GameProfile(channelProfile: .channelProfile_Game_Command_Mode, clientRole: .clientRole_Audience)
    }
    
    func description() -> String {
        let profile = channelProfile.description()
        let role = clientRole?.description()
        
        if let role = role {
            return role
        } else {
            return profile
        }
    }
    
    func isFree() -> Bool {
        return channelProfile == .channelProfile_Game_Free_Mode
    }
    
    func isCommander() -> Bool {
        return clientRole == .clientRole_Broadcaster
    }
}

extension AgoraRtcChannelProfile {
    func description() -> String {
        switch self {
        case .channelProfile_Game_Free_Mode:    return "Free Mode"
        case .channelProfile_Game_Command_Mode: return "Command Mode"
        default: return ""
        }
    }
}

extension AgoraRtcClientRole {
    func description() -> String {
        switch self {
        case .clientRole_Broadcaster:   return "Commander"
        case .clientRole_Audience:      return "Audience"
        }
    }
}
