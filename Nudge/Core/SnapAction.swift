import Cocoa
import Carbon

enum SnapAction: String, CaseIterable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeft, topRight, bottomLeft, bottomRight
    case leftThird, centerThird, rightThird
    case leftTwoThirds, centerTwoThirds, rightTwoThirds
    case maximize, center, restore
    case nextDisplay, previousDisplay

    var displayName: String {
        switch self {
        case .leftHalf: return NSLocalizedString("Left Half", comment: "")
        case .rightHalf: return NSLocalizedString("Right Half", comment: "")
        case .topHalf: return NSLocalizedString("Top Half", comment: "")
        case .bottomHalf: return NSLocalizedString("Bottom Half", comment: "")
        case .topLeft: return NSLocalizedString("Top Left", comment: "")
        case .topRight: return NSLocalizedString("Top Right", comment: "")
        case .bottomLeft: return NSLocalizedString("Bottom Left", comment: "")
        case .bottomRight: return NSLocalizedString("Bottom Right", comment: "")
        case .leftThird: return NSLocalizedString("Left Third", comment: "")
        case .centerThird: return NSLocalizedString("Center Third", comment: "")
        case .rightThird: return NSLocalizedString("Right Third", comment: "")
        case .leftTwoThirds: return NSLocalizedString("Left Two Thirds", comment: "")
        case .centerTwoThirds: return NSLocalizedString("Center Two Thirds", comment: "")
        case .rightTwoThirds: return NSLocalizedString("Right Two Thirds", comment: "")
        case .maximize: return NSLocalizedString("Maximize", comment: "")
        case .center: return NSLocalizedString("Center", comment: "")
        case .restore: return NSLocalizedString("Restore", comment: "")
        case .nextDisplay: return NSLocalizedString("Next Display", comment: "")
        case .previousDisplay: return NSLocalizedString("Previous Display", comment: "")
        }
    }

    var defaultHotkey: Hotkey {
        let ctrlOpt: UInt32 = UInt32(controlKey | optionKey)
        let ctrlOptCmd: UInt32 = UInt32(controlKey | optionKey | cmdKey)
        switch self {
        case .leftHalf:        return Hotkey(modifiers: ctrlOpt, keyCode: UInt32(kVK_LeftArrow))
        case .rightHalf:       return Hotkey(modifiers: ctrlOpt, keyCode: UInt32(kVK_RightArrow))
        case .topHalf:         return Hotkey(modifiers: ctrlOpt, keyCode: UInt32(kVK_UpArrow))
        case .bottomHalf:      return Hotkey(modifiers: ctrlOpt, keyCode: UInt32(kVK_DownArrow))
        case .topLeft:         return Hotkey(modifiers: ctrlOpt, keyCode: UInt32(kVK_ANSI_U))
        case .topRight:        return Hotkey(modifiers: ctrlOpt, keyCode: UInt32(kVK_ANSI_I))
        case .bottomLeft:      return Hotkey(modifiers: ctrlOpt, keyCode: UInt32(kVK_ANSI_J))
        case .bottomRight:     return Hotkey(modifiers: ctrlOpt, keyCode: UInt32(kVK_ANSI_K))
        case .leftThird:       return Hotkey(modifiers: ctrlOpt, keyCode: UInt32(kVK_ANSI_D))
        case .centerThird:     return Hotkey(modifiers: ctrlOpt, keyCode: UInt32(kVK_ANSI_F))
        case .rightThird:      return Hotkey(modifiers: ctrlOpt, keyCode: UInt32(kVK_ANSI_G))
        case .leftTwoThirds:   return Hotkey(modifiers: ctrlOpt, keyCode: UInt32(kVK_ANSI_E))
        case .centerTwoThirds: return Hotkey(modifiers: ctrlOpt, keyCode: UInt32(kVK_ANSI_R))
        case .rightTwoThirds:  return Hotkey(modifiers: ctrlOpt, keyCode: UInt32(kVK_ANSI_T))
        case .maximize:        return Hotkey(modifiers: ctrlOpt, keyCode: UInt32(kVK_Return))
        case .center:          return Hotkey(modifiers: ctrlOpt, keyCode: UInt32(kVK_ANSI_C))
        case .restore:         return Hotkey(modifiers: ctrlOpt, keyCode: UInt32(kVK_Delete))
        case .nextDisplay:     return Hotkey(modifiers: ctrlOptCmd, keyCode: UInt32(kVK_RightArrow))
        case .previousDisplay: return Hotkey(modifiers: ctrlOptCmd, keyCode: UInt32(kVK_LeftArrow))
        }
    }

    /// Whether this action can cycle across monitors when repeated
    var hasCycleDirection: Bool {
        switch self {
        case .leftHalf, .rightHalf, .topHalf, .bottomHalf,
             .topLeft, .topRight, .bottomLeft, .bottomRight,
             .leftThird, .rightThird, .leftTwoThirds, .rightTwoThirds:
            return true
        default:
            return false
        }
    }

    var category: String {
        switch self {
        case .leftHalf, .rightHalf, .topHalf, .bottomHalf: return NSLocalizedString("Halves", comment: "")
        case .topLeft, .topRight, .bottomLeft, .bottomRight: return NSLocalizedString("Quarters", comment: "")
        case .leftThird, .centerThird, .rightThird: return NSLocalizedString("Thirds", comment: "")
        case .leftTwoThirds, .centerTwoThirds, .rightTwoThirds: return NSLocalizedString("Two Thirds", comment: "")
        case .maximize, .center, .restore: return NSLocalizedString("Other", comment: "")
        case .nextDisplay, .previousDisplay: return NSLocalizedString("Display", comment: "")
        }
    }
}
