#!/bin/bash
# GPS Control Test Script
# ======================

echo "Testing GPS Control System..."

# Test 1: Get system status
echo "1. Getting system status..."
mosquitto_pub -h localhost -t "gps/control/get_status" -m "true"
sleep 2

# Test 2: Get logs
echo "2. Getting logs..."
mosquitto_pub -h localhost -t "gps/control/get_logs" -m "true"
sleep 2

# Test 3: Test source override
echo "3. Testing source override to RUTOS..."
mosquitto_pub -h localhost -t "gps/control/source" -m "rutos"
sleep 2

# Test 4: Return to auto
echo "4. Returning to auto source selection..."
mosquitto_pub -h localhost -t "gps/control/source" -m "auto"
sleep 2

# Test 5: Adjust camping threshold
echo "5. Setting camping threshold to 25m..."
mosquitto_pub -h localhost -t "gps/control/config" -m '{"param":"camping_threshold","value":25}'
sleep 2

# Test 6: Get updated status
echo "6. Getting updated status..."
mosquitto_pub -h localhost -t "gps/control/get_status" -m "true"

echo ""
echo "Test commands sent. In another terminal, run:"
echo "mosquitto_sub -h localhost -t 'gps/status' -t 'gps/logs'"
echo "to see the responses."
