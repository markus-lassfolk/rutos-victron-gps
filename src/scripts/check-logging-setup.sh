#!/bin/bash
# Check Node-RED logging permissions and suggest fix
# ===================================================

echo "Checking Node-RED file logging setup..."

# Check what user Node-RED is running as (BusyBox compatible)
echo "1. Node-RED process info:"
ps | grep node-red | grep -v grep

echo -e "\n2. Finding Node-RED user:"
NODERED_PID=$(ps | grep node-red | grep -v grep | awk '{print $1}' | head -n1)
if [ -n "$NODERED_PID" ]; then
    # Try to get user info (might not work on all systems)
    NODERED_USER=$(ls -l /proc/$NODERED_PID 2>/dev/null | awk '{print $3}' | head -n1)
    echo "Node-RED PID: $NODERED_PID"
    echo "Trying to determine user..."
    
    # Alternative method - check process owner
    if [ -f "/proc/$NODERED_PID/status" ]; then
        grep -E "^(Name|Uid)" /proc/$NODERED_PID/status
    fi
else
    echo "Node-RED process not found!"
fi

echo -e "\n3. Testing write permissions as current user ($(whoami)):"

# Check common writable locations
dirs=("/tmp" "/var/log" "/home/root" "/data" "/opt/victronenergy")
for dir in "${dirs[@]}"; do
    if [ -d "$dir" ]; then
        # Test actual write permission
        test_file="$dir/gps-test-$$"
        if touch "$test_file" 2>/dev/null; then
            rm -f "$test_file"
            echo "✅ $dir - writable"
        else
            echo "❌ $dir - not writable"
        fi
    else
        echo "❓ $dir - doesn't exist"
    fi
done

echo -e "\n4. Recommended approach:"
echo "Since you're root, Node-RED likely runs as 'nodered' or 'nobody' user."
echo "Try: su nodered -c 'touch /tmp/test && rm /tmp/test && echo /tmp works'"
echo "Or:  su nobody -c 'touch /tmp/test && rm /tmp/test && echo /tmp works'"

echo -e "\n5. Quick fix for file logging:"
echo "Use /tmp/gps-events.log - it should work for any user"
