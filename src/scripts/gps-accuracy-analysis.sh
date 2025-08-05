#!/bin/bash
# GPS Accuracy CSV Analysis Commands
# ==================================
# Analyzes GPS accuracy data from CSV file

CSV_FILE="${1:-gps-accuracy-data.csv}"
COMMAND="${2:-stats}"

echo "GPS Accuracy CSV Analyzer (Bash)"
echo "================================"
echo ""

if [ ! -f "$CSV_FILE" ]; then
    echo "Error: CSV file not found: $CSV_FILE"
    echo "Run Collect-GPSAccuracy.ps1 first to collect data."
    exit 1
fi

case "$COMMAND" in
    "stats")
        echo "=== GPS ACCURACY STATISTICS ==="
        echo ""
        
        # Count total entries
        total_entries=$(tail -n +2 "$CSV_FILE" | wc -l)
        starlink_entries=$(tail -n +2 "$CSV_FILE" | grep -c ",starlink,")
        rutos_entries=$(tail -n +2 "$CSV_FILE" | grep -c ",rutos,")
        
        echo "Total readings: $total_entries"
        echo "Starlink readings: $starlink_entries"
        echo "RUTOS readings: $rutos_entries"
        echo ""
        
        # Starlink statistics
        if [ $starlink_entries -gt 0 ]; then
            echo "=== STARLINK GPS Statistics ==="
            starlink_accuracies=$(tail -n +2 "$CSV_FILE" | grep ",starlink," | cut -d',' -f6 | grep -v '^$' | sort -n)
            
            if [ -n "$starlink_accuracies" ]; then
                count=$(echo "$starlink_accuracies" | wc -l)
                min=$(echo "$starlink_accuracies" | head -1)
                max=$(echo "$starlink_accuracies" | tail -1)
                avg=$(echo "$starlink_accuracies" | awk '{sum+=$1} END {printf "%.2f", sum/NR}')
                
                # Calculate recommended threshold (1.5x average, minimum 1)
                recommended=$(echo "$avg" | awk '{printf "%d", ($1 * 1.5 < 1) ? 1 : int($1 * 1.5 + 0.5)}')
                
                echo "Readings: $count"
                echo "Average accuracy: ${avg}m"
                echo "Min accuracy: ${min}m"
                echo "Max accuracy: ${max}m"
                echo "Recommended threshold: ${recommended}m"
            fi
            echo ""
        fi
        
        # RUTOS statistics
        if [ $rutos_entries -gt 0 ]; then
            echo "=== RUTOS GPS Statistics ==="
            rutos_accuracies=$(tail -n +2 "$CSV_FILE" | grep ",rutos," | cut -d',' -f6 | grep -v '^$' | sort -n)
            
            if [ -n "$rutos_accuracies" ]; then
                count=$(echo "$rutos_accuracies" | wc -l)
                min=$(echo "$rutos_accuracies" | head -1)
                max=$(echo "$rutos_accuracies" | tail -1)
                avg=$(echo "$rutos_accuracies" | awk '{sum+=$1} END {printf "%.2f", sum/NR}')
                
                # Calculate recommended threshold (1.5x average, minimum 1)
                recommended=$(echo "$avg" | awk '{printf "%d", ($1 * 1.5 < 1) ? 1 : int($1 * 1.5 + 0.5)}')
                
                echo "Readings: $count"
                echo "Average accuracy: ${avg}m"
                echo "Min accuracy: ${min}m"
                echo "Max accuracy: ${max}m"
                echo "Recommended threshold: ${recommended}m"
            fi
            echo ""
        fi
        ;;
        
    "recommend")
        echo "=== RECOMMENDED SETTINGS ==="
        echo ""
        
        # Get RUTOS recommendation
        rutos_accuracies=$(tail -n +2 "$CSV_FILE" | grep ",rutos," | cut -d',' -f6 | grep -v '^$')
        if [ -n "$rutos_accuracies" ]; then
            rutos_avg=$(echo "$rutos_accuracies" | awk '{sum+=$1} END {printf "%.2f", sum/NR}')
            rutos_threshold=$(echo "$rutos_avg" | awk '{printf "%d", ($1 * 1.5 < 1) ? 1 : int($1 * 1.5 + 0.5)}')
            echo "rutos_accuracy: $rutos_threshold"
        fi
        
        # Get Starlink recommendation
        starlink_accuracies=$(tail -n +2 "$CSV_FILE" | grep ",starlink," | cut -d',' -f6 | grep -v '^$')
        if [ -n "$starlink_accuracies" ]; then
            starlink_avg=$(echo "$starlink_accuracies" | awk '{sum+=$1} END {printf "%.2f", sum/NR}')
            starlink_threshold=$(echo "$starlink_avg" | awk '{printf "%d", ($1 * 1.5 < 1) ? 1 : int($1 * 1.5 + 0.5)}')
            echo "starlink_accuracy: $starlink_threshold"
        fi
        echo ""
        ;;
        
    "recent")
        hours=${3:-24}
        echo "=== RECENT DATA (Last $hours hours) ==="
        echo ""
        
        # Calculate cutoff time (hours ago)
        cutoff_time=$(date -d "$hours hours ago" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -v-${hours}H '+%Y-%m-%d %H:%M:%S')
        
        # Filter recent data
        recent_data=$(tail -n +2 "$CSV_FILE" | awk -F',' -v cutoff="$cutoff_time" '$1 >= cutoff')
        
        if [ -n "$recent_data" ]; then
            recent_starlink=$(echo "$recent_data" | grep ",starlink," | wc -l)
            recent_rutos=$(echo "$recent_data" | grep ",rutos," | wc -l)
            
            echo "Recent readings: Starlink $recent_starlink, RUTOS $recent_rutos"
            
            # Show recent averages
            if [ $recent_starlink -gt 0 ]; then
                recent_starlink_avg=$(echo "$recent_data" | grep ",starlink," | cut -d',' -f6 | grep -v '^$' | awk '{sum+=$1} END {printf "%.2f", sum/NR}')
                echo "Recent Starlink average: ${recent_starlink_avg}m"
            fi
            
            if [ $recent_rutos -gt 0 ]; then
                recent_rutos_avg=$(echo "$recent_data" | grep ",rutos," | cut -d',' -f6 | grep -v '^$' | awk '{sum+=$1} END {printf "%.2f", sum/NR}')
                echo "Recent RUTOS average: ${recent_rutos_avg}m"
            fi
        else
            echo "No recent data found"
        fi
        echo ""
        ;;
        
    "summary")
        echo "=== QUICK SUMMARY ==="
        echo ""
        
        total_entries=$(tail -n +2 "$CSV_FILE" | wc -l)
        starlink_entries=$(tail -n +2 "$CSV_FILE" | grep -c ",starlink,")
        rutos_entries=$(tail -n +2 "$CSV_FILE" | grep -c ",rutos,")
        
        # Get date range
        first_date=$(tail -n +2 "$CSV_FILE" | head -1 | cut -d',' -f1)
        last_date=$(tail -n +2 "$CSV_FILE" | tail -1 | cut -d',' -f1)
        
        echo "Total readings: $total_entries"
        echo "Starlink: $starlink_entries readings"
        echo "RUTOS: $rutos_entries readings"
        echo "Date range: $first_date to $last_date"
        
        # Quick accuracy averages
        if [ $starlink_entries -gt 0 ]; then
            starlink_avg=$(tail -n +2 "$CSV_FILE" | grep ",starlink," | cut -d',' -f6 | grep -v '^$' | awk '{sum+=$1} END {printf "%.1f", sum/NR}')
            echo "Starlink avg accuracy: ${starlink_avg}m"
        fi
        
        if [ $rutos_entries -gt 0 ]; then
            rutos_avg=$(tail -n +2 "$CSV_FILE" | grep ",rutos," | cut -d',' -f6 | grep -v '^$' | awk '{sum+=$1} END {printf "%.1f", sum/NR}')
            echo "RUTOS avg accuracy: ${rutos_avg}m"
        fi
        echo ""
        ;;
        
    *)
        echo "Usage: $0 [csv_file] [command] [options]"
        echo ""
        echo "Commands:"
        echo "  stats     - Show comprehensive statistics (default)"
        echo "  recommend - Get recommended threshold settings"
        echo "  recent    - Show recent data analysis [hours]"
        echo "  summary   - Quick data summary"
        echo ""
        echo "Examples:"
        echo "  $0 gps-accuracy-data.csv stats"
        echo "  $0 gps-accuracy-data.csv recommend"
        echo "  $0 gps-accuracy-data.csv recent 12"
        echo "  $0 gps-accuracy-data.csv summary"
        ;;
esac
