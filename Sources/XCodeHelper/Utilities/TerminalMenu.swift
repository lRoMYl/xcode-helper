import Foundation

/// Interactive terminal menu with arrow-key navigation
struct TerminalMenu {
    let title: String
    let options: [String]
    let allowCustomInput: Bool

    init(title: String, options: [String], allowCustomInput: Bool = true) {
        self.title = title
        self.options = options
        self.allowCustomInput = allowCustomInput
    }

    /// Run the interactive menu and return the selected value
    func run() -> String? {
        // Save terminal state and enable raw mode
        var originalTermios = termios()
        tcgetattr(STDIN_FILENO, &originalTermios)

        var raw = originalTermios
        raw.c_lflag &= ~UInt(ICANON | ECHO)
        raw.c_cc.16 = 1  // VMIN
        raw.c_cc.17 = 0  // VTIME
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)

        defer {
            // Restore terminal state
            tcsetattr(STDIN_FILENO, TCSAFLUSH, &originalTermios)
        }

        var selectedIndex = 0
        let customOptionIndex = options.count

        while true {
            render(selectedIndex: selectedIndex)

            guard let key = readKey() else { continue }

            switch key {
            case .up:
                if selectedIndex > 0 {
                    selectedIndex -= 1
                }
            case .down:
                let maxIndex = allowCustomInput ? customOptionIndex : options.count - 1
                if selectedIndex < maxIndex {
                    selectedIndex += 1
                }
            case .enter:
                clearMenu()
                if allowCustomInput && selectedIndex == customOptionIndex {
                    return promptCustomInput()
                }
                return options[selectedIndex]
            case .escape, .ctrlC:
                clearMenu()
                return nil
            default:
                break
            }
        }
    }

    private func render(selectedIndex: Int) {
        // Move cursor to start and clear
        print("\u{1B}[H\u{1B}[J", terminator: "")

        // Print title
        print("\u{1B}[1m\(title)\u{1B}[0m")
        print("Use ↑/↓ arrows to navigate, Enter to select, Esc to cancel\n")

        // Print options
        for (index, option) in options.enumerated() {
            if index == selectedIndex {
                print("\u{1B}[36m❯ \(option)\u{1B}[0m")
            } else {
                print("  \(option)")
            }
        }

        // Print custom input option if allowed
        if allowCustomInput {
            if selectedIndex == options.count {
                print("\u{1B}[36m❯ [Type custom value...]\u{1B}[0m")
            } else {
                print("  [Type custom value...]")
            }
        }

        fflush(stdout)
    }

    private func clearMenu() {
        print("\u{1B}[H\u{1B}[J", terminator: "")
        fflush(stdout)
    }

    private func promptCustomInput() -> String? {
        // Restore echo for input
        var termios = termios()
        tcgetattr(STDIN_FILENO, &termios)
        termios.c_lflag |= UInt(ICANON | ECHO)
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &termios)

        print("Enter custom value: ", terminator: "")
        fflush(stdout)

        guard let input = readLine(), !input.isEmpty else {
            return nil
        }
        return input
    }

    private enum Key {
        case up, down, enter, escape, ctrlC, other
    }

    private func readKey() -> Key? {
        var buffer = [UInt8](repeating: 0, count: 3)
        let bytesRead = read(STDIN_FILENO, &buffer, 3)

        guard bytesRead > 0 else { return nil }

        // Ctrl+C
        if buffer[0] == 3 {
            return .ctrlC
        }

        // Escape
        if buffer[0] == 27 {
            if bytesRead == 1 {
                return .escape
            }
            // Arrow keys: ESC [ A/B/C/D
            if bytesRead >= 3 && buffer[1] == 91 {
                switch buffer[2] {
                case 65: return .up
                case 66: return .down
                default: return .other
                }
            }
        }

        // Enter
        if buffer[0] == 10 || buffer[0] == 13 {
            return .enter
        }

        return .other
    }
}
