// KeymapMenu.swift - Apply the active keymap to the main menu (I13 T06).
//
// The keymap is the single source for shortcut display: menu items whose command
// the active scheme binds show that scheme's accelerator (so switching schemes
// visibly re-labels the menu and the new shortcut triggers the command through
// the normal menu key-equivalent path). Items whose command is not registered are
// disabled. Non-representable chords (numpad keys) leave the item's existing
// (hardcoded) accelerator untouched.

import AppKit
import PCFoundation

enum KeymapMenu {
    /// Convert a KeyChord to a menu key-equivalent + modifier mask, or nil when the
    /// key token cannot be represented as an NSMenuItem key equivalent (numpad keys).
    static func keyEquivalent(for chord: KeyChord) -> (String, NSEvent.ModifierFlags)? {
        guard let char = character(for: chord.key) else { return nil }
        var mask: NSEvent.ModifierFlags = []
        if chord.ctrl { mask.insert(.control) }
        if chord.alt { mask.insert(.option) }
        if chord.shift { mask.insert(.shift) }
        if chord.cmd { mask.insert(.command) }
        return (char, mask)
    }

    private static func character(for key: String) -> String? {
        // Single letter or digit.
        if key.count == 1, let c = key.first, c.isLetter || c.isNumber {
            return key.lowercased()
        }
        // Function keys F1..F12.
        if key.hasPrefix("F"), let n = Int(key.dropFirst()), (1...12).contains(n) {
            return String(UnicodeScalar(0xF704 + (n - 1))!)
        }
        switch key {
        case "ENTER": return "\r"
        case "TAB": return "\t"
        case "SPACE": return " "
        case "ESC": return "\u{1b}"
        case "BACKSPACE": return "\u{8}"
        case "DELETE": return String(UnicodeScalar(0xF728)!)   // NSDeleteFunctionKey
        case "INSERT": return String(UnicodeScalar(0xF727)!)
        case "LEFT": return String(UnicodeScalar(0xF702)!)
        case "RIGHT": return String(UnicodeScalar(0xF703)!)
        case "UP": return String(UnicodeScalar(0xF700)!)
        case "DOWN": return String(UnicodeScalar(0xF701)!)
        case "HOME": return String(UnicodeScalar(0xF729)!)
        case "END": return String(UnicodeScalar(0xF72B)!)
        case "PGUP": return String(UnicodeScalar(0xF72C)!)
        case "PGDN": return String(UnicodeScalar(0xF72D)!)
        default: return nil   // NUM+/-/*// and anything else: not representable
        }
    }

    /// Convert a key-down NSEvent to a KeyChord, or nil if the key isn't representable.
    static func chord(from event: NSEvent) -> KeyChord? {
        guard let token = keyToken(from: event) else { return nil }
        let f = event.modifierFlags
        return KeyChord(ctrl: f.contains(.control), alt: f.contains(.option),
                        shift: f.contains(.shift), cmd: f.contains(.command), key: token)
    }

    private static func keyToken(from event: NSEvent) -> String? {
        guard let chars = event.charactersIgnoringModifiers, let scalar = chars.unicodeScalars.first else { return nil }
        // Letters / digits.
        if chars.count == 1, let c = chars.first, c.isLetter || c.isNumber { return chars.uppercased() }
        switch scalar.value {
        case 0xF704...0xF70F: return "F\(scalar.value - 0xF704 + 1)"   // F1..F12
        case 0xF700: return "UP"
        case 0xF701: return "DOWN"
        case 0xF702: return "LEFT"
        case 0xF703: return "RIGHT"
        case 0xF727: return "INSERT"
        case 0xF728, 0x7F: return "DELETE"
        case 0xF729: return "HOME"
        case 0xF72B: return "END"
        case 0xF72C: return "PGUP"
        case 0xF72D: return "PGDN"
        case 0x0D, 0x03: return "ENTER"
        case 0x09: return "TAB"
        case 0x20: return "SPACE"
        case 0x1B: return "ESC"
        case 0x08: return "BACKSPACE"
        default: return nil
        }
    }

    /// Walk the menu tree: sync accelerators from `keymap`, and disable items whose
    /// cm_ command is not in `registered`. `menu.autoenablesItems` must be false for
    /// the disabling to take effect (the caller sets it).
    static func apply(_ keymap: Keymap, to menu: NSMenu, registered: Set<String>) {
        menu.autoenablesItems = false
        for item in menu.items {
            if let submenu = item.submenu {
                apply(keymap, to: submenu, registered: registered)
            }
            guard let cmd = item.representedObject as? String else { continue }
            if cmd.hasPrefix("cm_"), !registered.contains(cmd) {
                item.isEnabled = false
            } else {
                item.isEnabled = true
            }
            if let chord = keymap.chord(for: cmd), let (char, mask) = keyEquivalent(for: chord) {
                item.keyEquivalent = char
                item.keyEquivalentModifierMask = mask
            }
        }
    }
}
