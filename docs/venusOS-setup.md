# VenusOS Configuration Guide

## Overview
This guide covers setting up VenusOS (Cerbo GX/CX) to receive GPS data from RUTOS devices with Starlink fallback.

## Prerequisites
- Victron Cerbo GX or Cerbo CX
- VenusOS v2.90 or later
- Node-RED access enabled
- Network connectivity to RUTOS device

## Installation Steps

### 1. Enable Node-RED on VenusOS
```bash
# SSH to Cerbo GX
ssh root@your-cerbo-ip

# Enable Node-RED service
venus-config
# Navigate to Services -> Node-RED -> Enable
```

### 2. Import GPS Flow
1. Open Node-RED: `http://your-cerbo-ip:1880`
2. Import the flow from `src/victron-gps-flow.json`
3. Configure connection settings for your RUTOS device

### 3. Configure MQTT Settings
```bash
# VenusOS MQTT topics for GPS
/N/your-device-id/gps/Position/Latitude
/N/your-device-id/gps/Position/Longitude
/N/your-device-id/gps/Position/Altitude
/N/your-device-id/gps/Course
/N/your-device-id/gps/Fix
/N/your-device-id/gps/NrOfSatellites
```

### 4. Verify GPS Data Flow
1. Check VenusOS Remote Console
2. Navigate to Device List -> GPS
3. Verify coordinates are updating

## Configuration Options

### GPS Update Frequency
- Default: 30 minutes
- Range: 1-60 minutes
- Configure in Node-RED flow

### Accuracy Thresholds
- RUTOS GPS: < 2 meters for "good" fix
- Starlink GPS: < 10 meters for "good" fix
- Movement threshold: 500 meters for obstruction map reset

### Failover Logic
1. **Primary**: RUTOS GPS (higher accuracy)
2. **Fallback**: Starlink GPS (when RUTOS unavailable)
3. **Validation**: Fix status and accuracy checks

## Troubleshooting
- Check Node-RED logs: `http://your-cerbo-ip:1880`
- Verify MQTT broker: `mosquitto_sub -h localhost -t /N/+/gps/+`
- Test API connectivity to RUTOS device
- Check VenusOS device list for GPS entries
