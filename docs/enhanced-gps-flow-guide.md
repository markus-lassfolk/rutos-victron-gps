// Enhanced GPS Flow Configuration Guide
// ===================================

## Key Enhancements Implemented

### 1. Configurable Parameters
All thresholds are now stored in flow context and can be dynamically adjusted:

- `config_rutos_accuracy`: RUTOS accuracy threshold (default: 2m)
- `config_starlink_accuracy`: Starlink accuracy threshold (default: 10m)  
- `config_camping_threshold`: Distance to trigger Victron update (default: 50m)
- `config_obstruction_threshold`: Distance to trigger obstruction reset (default: 200m)
- `config_stationary_time`: Time threshold for stationary detection (default: 5 minutes)
- `config_source_override`: Manual source selection ('auto', 'rutos', 'starlink')

### 2. Smart Movement Logic
The enhanced logic now:
- Distinguishes between camping moves (<1km) and highway driving (>1km)
- Only resets obstruction map for camping moves or after being stationary
- Updates Victron GPS when moving >50m from stored position OR every 5 minutes
- Uses Haversine distance formula for accurate GPS coordinate distance calculation

### 3. Manual Override System via MQTT
Send commands to these topics:

```bash
# Change GPS source priority
mosquitto_pub -h localhost -t "gps/control/source" -m "rutos"
mosquitto_pub -h localhost -t "gps/control/source" -m "starlink" 
mosquitto_pub -h localhost -t "gps/control/source" -m "auto"

# Force GPS update regardless of change detection
mosquitto_pub -h localhost -t "gps/control/force_update" -m "true"

# Force obstruction map reset
mosquitto_pub -h localhost -t "gps/control/reset_obstruction" -m "true"

# Update configuration parameters
mosquitto_pub -h localhost -t "gps/control/config" -m '{"param":"camping_threshold","value":75}'

# Get current system status
mosquitto_pub -h localhost -t "gps/control/get_status" -m "true"

# Get recent log entries
mosquitto_pub -h localhost -t "gps/control/get_logs" -m "true"
```

### 4. Enhanced Error Handling
- Comprehensive error logging with source tracking
- Automatic fallback when sources become unreliable (>3 errors)
- Degraded source detection with automatic recovery after 10 minutes
- Last-known position fallback with degraded accuracy indicators

### 5. Event Logging System
Events are logged in memory and accessible via MQTT commands:
```bash
# Get recent log entries
mosquitto_pub -h localhost -t "gps/control/get_logs" -m "true"

# Listen for log output
mosquitto_sub -h localhost -t "gps/logs"
```

Log entries are in JSON format:
```json
{"ts":"2025-08-05T10:30:00.000Z","level":"info","event":"gps_processing_complete","data":{"source":"rutos","position":"59.123456, 18.654321","accuracy":1.2}}
```

### 6. Victron GPS Position Reading
The flow now reads current Victron GPS position via MQTT topic `R/+/gps/+/Position/+` to:
- Cache the currently stored position in Victron system
- Compare new readings against stored position for intelligent updates
- Only update when significant movement detected

### 7. Fallback System
When both GPS sources fail:
- Falls back to last known position
- Sets gpsFix=0 and hAcc=999 to indicate degraded accuracy
- Maintains system operation with reduced precision

## Usage Examples

### Setting Custom Thresholds
```bash
# Set camping movement threshold to 75 meters
mosquitto_pub -h localhost -t "gps/control/config" -m '{"param":"camping_threshold","value":75}'

# Set obstruction reset threshold to 150 meters  
mosquitto_pub -h localhost -t "gps/control/config" -m '{"param":"obstruction_threshold","value":150}'

# Set RUTOS accuracy requirement to 3 meters
mosquitto_pub -h localhost -t "gps/control/config" -m '{"param":"rutos_accuracy","value":3}'
```

### Manual Source Override
```bash
# Force use RUTOS GPS only
mosquitto_pub -h localhost -t "gps/control/source" -m "rutos"

# Force use Starlink GPS only
mosquitto_pub -h localhost -t "gps/control/source" -m "starlink"

# Return to automatic source selection
mosquitto_pub -h localhost -t "gps/control/source" -m "auto"
```

### Force Operations
```bash
# Force immediate GPS update to Victron
mosquitto_pub -h localhost -t "gps/control/force_update" -m "true"

# Force immediate obstruction map reset
mosquitto_pub -h localhost -t "gps/control/reset_obstruction" -m "true"
```

## Log Levels and Events

### Log Levels:
- `debug`: Detailed processing information
- `info`: Normal operational events  
- `warn`: Warning conditions (fallbacks, degraded sources)
- `error`: Error conditions requiring attention

### Key Events Logged:
- `gps_processing_start`: Beginning of GPS processing cycle
- `source_override_*`: Manual source selection events
- `auto_source_*`: Automatic source selection decisions
- `movement_analysis`: Movement detection results
- `obstruction_reset_triggered`: When obstruction map reset occurs
- `victron_update_triggered`: When Victron GPS update occurs
- `fallback_last_position`: When using fallback position
- `error_occurred`: When GPS source errors happen

## Benefits of Enhanced Logic

1. **Reduced False Positives**: Smart movement detection prevents unnecessary obstruction resets during highway driving
2. **Configurable Operation**: All thresholds can be tuned without editing code
3. **Better Error Recovery**: Automatic degraded source detection and recovery
4. **Comprehensive Logging**: Full audit trail of GPS decisions and events
5. **Manual Control**: Override capabilities for testing and troubleshooting
6. **Intelligent Updates**: Only updates Victron when meaningful position change occurs
7. **System Resilience**: Fallback mechanisms maintain operation during GPS outages
