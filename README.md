# xcode-helper

Helper tools for Xcode project management.

## Installation

```bash
brew tap lromyl/tap
brew install xcode-helper
```

## Commands

### Link - Framework Linking for Debugging

Enable local framework linking to debug framework source code directly in your main app.

#### Enable Linking

```bash
xcode-helper link enable subscription
```

This will:
1. Remap framework paths in the source project to use shared dependencies
2. Replace the xcframework with a nested xcodeproj reference in the target project
3. Allow you to set breakpoints and debug framework source code

**Options:**
- `--path <dir>` - Override working directory (default: current directory)
- `--dry-run` - Preview changes without applying
- `--verbose` - Show detailed output

#### Disable Linking

```bash
xcode-helper link disable subscription
```

This will restore the original project configuration:
1. Restore original framework paths in the source project
2. Replace the nested xcodeproj with the original xcframework reference

#### Check Status

```bash
xcode-helper link status
```

Shows the current linking state for the project.

## Supported Mappings

- `subscription` - pd-mob-subscription-ios framework

## Requirements

- macOS 13+
- Xcode
- Run from a parent directory containing both the source and target repositories

## Example Usage

```bash
# From ~/Repos (containing pd-mob-b2c-ios and pd-mob-subscription-ios)
cd ~/Repos

# Enable debugging
xcode-helper link enable subscription

# Open Xcode and debug
open pd-mob-b2c-ios/Volo.xcworkspace

# When done, disable linking
xcode-helper link disable subscription
```

## Known Limitations

- Does not work reliably with Tuist-generated projects (use `tuist generate` to restore if issues occur)
- Requires both source and target repositories to be siblings in the same directory
