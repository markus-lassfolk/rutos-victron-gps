#!/bin/bash
# GPS Accuracy Analysis Script
# ============================
# This script monitors GPS accuracy from both sources and provides statistics

echo "GPS Accuracy Monitoring & Analysis"
echo "=================================="

# Create analysis log file
ANALYSIS_LOG="/tmp/gps-accuracy-analysis.log"
echo "$(date): Starting GPS accuracy analysis" >> "$ANALYSIS_LOG"

echo "Monitoring GPS accuracy... Press Ctrl+C to stop and see analysis"
echo "Logs being written to: $ANALYSIS_LOG"
echo ""

# Function to calculate statistics
calculate_stats() {
    local source=$1
    local log_file=$2
    
    echo "=== $source GPS Accuracy Statistics ===" 
    
    # Extract accuracy values for this source
    accuracies=$(grep "\"source\":\"$source\"" "$log_file" | grep -o '"hAcc":[0-9.]*' | cut -d: -f2 | head -100)
    
    if [ -z "$accuracies" ]; then
        echo "No data found for $source"
        return
    fi
    
    # Calculate basic stats using awk
    echo "$accuracies" | awk '
    BEGIN { count=0; sum=0; min=999; max=0 }
    { 
        count++; 
        sum+=$1; 
        if($1 < min) min=$1; 
        if($1 > max) max=$1;
        values[count] = $1
    }
    END { 
        avg = sum/count;
        printf "Count: %d readings\n", count;
        printf "Average: %.2f meters\n", avg;
        printf "Min: %.2f meters\n", min;
        printf "Max: %.2f meters\n", max;
        
        # Calculate recommended thresholds
        recommended = avg + (avg * 0.5);  # 50% buffer above average
        printf "Recommended threshold: %.0f meters (avg + 50%% buffer)\n", recommended;
        
        # Calculate moving average (last 10 readings)
        if(count >= 10) {
            ma_sum = 0;
            for(i = count-9; i <= count; i++) {
                ma_sum += values[i];
            }
            printf "Moving average (last 10): %.2f meters\n", ma_sum/10;
        }
    }'
    echo ""
}

# Trap Ctrl+C to show analysis
trap 'echo ""; echo "Analyzing collected data..."; echo ""; calculate_stats "rutos" "$ANALYSIS_LOG"; calculate_stats "starlink" "$ANALYSIS_LOG"; echo "Full log available at: $ANALYSIS_LOG"; exit 0' INT

# Monitor GPS logs and extract accuracy data
mosquitto_sub -h localhost -t "gps/logs" | while read -r line; do
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Parse the GPS data if it contains accuracy info
    if echo "$line" | grep -q '"event":"gps_processing_complete"'; then
        # Extract accuracy and source info
        accuracy=$(echo "$line" | grep -o '"accuracy":[0-9.]*' | cut -d: -f2)
        source=$(echo "$line" | grep -o '"source":"[^"]*"' | cut -d: -f2 | tr -d '"')
        
        if [ -n "$accuracy" ] && [ -n "$source" ]; then
            # Log to analysis file
            echo "$timestamp: {\"source\":\"$source\", \"hAcc\":$accuracy}" >> "$ANALYSIS_LOG"
            
            # Show live data
            printf "%s: %s GPS accuracy: %s meters\n" "$timestamp" "$source" "$accuracy"
        fi
    fi
done
