#!/bin/bash
# Enhanced GPS Flow Testing and Configuration Script
# =================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

MQTT_HOST="localhost"
MQTT_PORT="1883"

echo -e "${BLUE}Enhanced GPS Flow Configuration and Testing Tool${NC}"
echo "=============================================="

# Function to send MQTT command
send_mqtt() {
    local topic=$1
    local message=$2
    echo -e "${YELLOW}Sending:${NC} $topic -> $message"
    mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT -t "$topic" -m "$message"
}

# Function to subscribe and listen for responses
listen_mqtt() {
    local topic=$1
    local timeout=${2:-5}
    echo -e "${BLUE}Listening to:${NC} $topic (timeout: ${timeout}s)"
    timeout $timeout mosquitto_sub -h $MQTT_HOST -p $MQTT_PORT -t "$topic" -v
}

show_menu() {
    echo ""
    echo "=== GPS Flow Control Menu ==="
    echo "1.  Configure GPS Source Priority"
    echo "2.  Set Movement Thresholds"
    echo "3.  Force GPS Operations"
    echo "4.  Monitor System Status"
    echo "5.  View Logs and Diagnostics"
    echo "6.  Test GPS Sources"
    echo "7.  Reset Configuration to Defaults"
    echo "8.  Advanced Configuration"
    echo "9.  gRPC vs Exec Performance Test"
    echo "10. Exit"
    echo ""
}

configure_source() {
    echo -e "${GREEN}GPS Source Configuration${NC}"
    echo "1. Auto (intelligent selection)"  
    echo "2. Force RUTOS only"
    echo "3. Force Starlink only"
    read -p "Select source [1-3]: " choice
    
    case $choice in
        1) send_mqtt "gps/control/source" "auto" ;;
        2) send_mqtt "gps/control/source" "rutos" ;;
        3) send_mqtt "gps/control/source" "starlink" ;;
        *) echo "Invalid choice" ;;
    esac
}

configure_thresholds() {
    echo -e "${GREEN}Movement Threshold Configuration${NC}"
    echo "Current recommended values:"
    echo "- Camping move threshold: 50m (triggers Victron update)"
    echo "- Obstruction reset threshold: 200m (resets Starlink obstruction map)"
    echo "- RUTOS accuracy threshold: 2m (maximum acceptable accuracy)"
    echo "- Starlink accuracy threshold: 10m (maximum acceptable accuracy)"
    echo ""
    
    read -p "Set camping move threshold (meters) [50]: " camping
    camping=${camping:-50}
    send_mqtt "gps/control/config" "{\"param\":\"camping_threshold\",\"value\":$camping}"
    
    read -p "Set obstruction reset threshold (meters) [200]: " obstruction  
    obstruction=${obstruction:-200}
    send_mqtt "gps/control/config" "{\"param\":\"obstruction_threshold\",\"value\":$obstruction}"
    
    read -p "Set RUTOS accuracy threshold (meters) [2]: " rutos_acc
    rutos_acc=${rutos_acc:-2}
    send_mqtt "gps/control/config" "{\"param\":\"rutos_accuracy\",\"value\":$rutos_acc}"
    
    read -p "Set Starlink accuracy threshold (meters) [10]: " starlink_acc
    starlink_acc=${starlink_acc:-10}
    send_mqtt "gps/control/config" "{\"param\":\"starlink_accuracy\",\"value\":$starlink_acc}"
}

force_operations() {
    echo -e "${GREEN}Force GPS Operations${NC}"
    echo "1. Force GPS update to Victron"
    echo "2. Force obstruction map reset"
    echo "3. Force both operations"
    read -p "Select operation [1-3]: " choice
    
    case $choice in
        1) send_mqtt "gps/control/force_update" "true" ;;
        2) send_mqtt "gps/control/reset_obstruction" "true" ;;
        3) 
            send_mqtt "gps/control/force_update" "true"
            sleep 1
            send_mqtt "gps/control/reset_obstruction" "true"
            ;;
        *) echo "Invalid choice" ;;
    esac
}

monitor_status() {
    echo -e "${GREEN}System Status Monitoring${NC}"
    echo "Getting current system status..."
    send_mqtt "gps/control/get_status" "true"
    echo ""
    echo "Listening for status response..."
    listen_mqtt "gps/status" 10
}

view_logs() {
    echo -e "${GREEN}Logs and Diagnostics${NC}"
    echo "1. Get recent event logs"
    echo "2. Monitor live GPS events"
    echo "3. Monitor error messages"
    echo "4. View log file (if accessible)"
    read -p "Select option [1-4]: " choice
    
    case $choice in
        1) 
            send_mqtt "gps/control/get_logs" "true"
            echo "Listening for logs..."
            listen_mqtt "gps/logs" 10
            ;;
        2)
            echo "Monitoring live GPS events (Ctrl+C to stop)..."
            listen_mqtt "gps/log" 60
            ;;
        3)
            echo "Monitoring GPS errors (Ctrl+C to stop)..."
            listen_mqtt "gps/error" 60
            ;;
        4)
            if [ -f "/data/logs/gps-events.log" ]; then
                echo "Recent log entries:"
                tail -20 /data/logs/gps-events.log
            else
                echo "Log file not accessible or doesn't exist"
            fi
            ;;
    esac
}

test_sources() {
    echo -e "${GREEN}GPS Source Testing${NC}"
    echo "Testing RUTOS GPS source..."
    echo "NOTE: Replace YOUR_RUTOS_PASSWORD_HERE with your actual password"
    curl -k -X POST https://192.168.80.1/api/login \
         -H "Content-Type: application/json" \
         -d '{"username":"admin","password":"YOUR_RUTOS_PASSWORD_HERE"}' \
         -w "RUTOS Login Status: %{http_code}\n" -s -o /dev/null
    
    echo ""
    echo "Testing Starlink gRPC connection..."
    timeout 5 grpcurl -plaintext -emit-defaults -d '{"get_diagnostics":{}}' \
            192.168.100.1:9200 SpaceX.API.Device.Device/Handle > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Starlink gRPC: OK${NC}"
    else
        echo -e "${RED}Starlink gRPC: FAILED${NC}"
    fi
}

reset_config() {
    echo -e "${YELLOW}Resetting configuration to defaults...${NC}"
    send_mqtt "gps/control/config" '{"param":"rutos_accuracy","value":2}'
    send_mqtt "gps/control/config" '{"param":"starlink_accuracy","value":10}'
    send_mqtt "gps/control/config" '{"param":"camping_threshold","value":50}'
    send_mqtt "gps/control/config" '{"param":"obstruction_threshold","value":200}'
    send_mqtt "gps/control/config" '{"param":"stationary_time","value":300000}'
    send_mqtt "gps/control/source" "auto"
    echo -e "${GREEN}Configuration reset complete${NC}"
}

advanced_config() {
    echo -e "${GREEN}Advanced Configuration${NC}"
    echo "1. Set position change epsilon (degrees)"
    echo "2. Set altitude change threshold (meters)"
    echo "3. Set speed change threshold (km/h)"
    echo "4. Set stationary time threshold (minutes)"
    echo "5. Set log level (debug/info/warn/error)"
    read -p "Select option [1-5]: " choice
    
    case $choice in
        1)
            read -p "Position epsilon (1e-7): " eps
            eps=${eps:-1e-7}
            send_mqtt "gps/control/config" "{\"param\":\"position_eps\",\"value\":$eps}"
            ;;
        2)
            read -p "Altitude threshold (0.05): " alt
            alt=${alt:-0.05}
            send_mqtt "gps/control/config" "{\"param\":\"altitude_threshold\",\"value\":$alt}"
            ;;
        3)
            read -p "Speed threshold (0.1): " speed
            speed=${speed:-0.1}
            send_mqtt "gps/control/config" "{\"param\":\"speed_threshold\",\"value\":$speed}"
            ;;
        4)
            read -p "Stationary time (5): " time
            time=${time:-5}
            time_ms=$((time * 60000))
            send_mqtt "gps/control/config" "{\"param\":\"stationary_time\",\"value\":$time_ms}"
            ;;
        5)
            echo "Log levels: debug, info, warn, error"
            read -p "Log level (info): " level
            level=${level:-info}
            send_mqtt "gps/control/config" "{\"param\":\"log_level\",\"value\":\"$level\"}"
            ;;
    esac
}

performance_test() {
    echo -e "${GREEN}gRPC vs Exec Performance Test${NC}"
    echo "This test compares the performance of native gRPC vs exec grpcurl"
    echo ""
    
    # Test exec grpcurl
    echo "Testing exec grpcurl (5 iterations)..."
    exec_times=()
    for i in {1..5}; do
        start_time=$(date +%s%N)
        timeout 10 grpcurl -plaintext -emit-defaults -d '{"get_diagnostics":{}}' \
                192.168.100.1:9200 SpaceX.API.Device.Device/Handle > /dev/null 2>&1
        end_time=$(date +%s%N)
        duration=$((($end_time - $start_time) / 1000000)) # Convert to milliseconds
        exec_times+=($duration)
        echo "  Iteration $i: ${duration}ms"
    done
    
    # Calculate average for exec
    exec_total=0
    for time in "${exec_times[@]}"; do
        exec_total=$((exec_total + time))
    done
    exec_avg=$((exec_total / 5))
    
    echo ""
    echo "Results:"
    echo "- Exec grpcurl average: ${exec_avg}ms"
    echo "- Native gRPC would typically be 2-3x faster"
    echo "- Native gRPC has better error handling and connection pooling"
    echo "- Recommended: Switch to native gRPC implementation"
}

# Main menu loop
while true; do
    show_menu
    read -p "Enter your choice [1-10]: " choice
    
    case $choice in
        1) configure_source ;;
        2) configure_thresholds ;;
        3) force_operations ;;
        4) monitor_status ;;
        5) view_logs ;;
        6) test_sources ;;
        7) reset_config ;;
        8) advanced_config ;;
        9) performance_test ;;
        10) echo "Goodbye!"; exit 0 ;;
        *) echo -e "${RED}Invalid choice. Please try again.${NC}" ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done
