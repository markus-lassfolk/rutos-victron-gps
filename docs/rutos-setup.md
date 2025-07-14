# RUTOS Setup Guide

## Overview
Configure your Teltonika RUTOS device to provide GPS data for VenusOS integration.

## Compatible Devices
- RUTX09, RUTX11, RUTX14, RUTX50
- Any RUTOS device with GPS and API access

## GPS Configuration

### 1. Enable GPS Service
1. Access RUTOS WebUI: `http://192.168.1.1`
2. Navigate to **Services → GPS**
3. Enable GPS service
4. Configure update interval (recommended: 30 seconds)

### 2. API Access Setup
```bash
# Enable API access
Services → API → Enable API
Network → Firewall → Allow API port (typically 80/443)
```

### 3. User Authentication
1. Create API user or use admin credentials
2. Note username/password for Node-RED configuration
3. Test API access: `curl http://your-rutos-ip/api/gps/position/status`

## Network Configuration

### 1. Static IP (Recommended)
```bash
# Set static IP for reliability
Network → Interfaces → LAN
IP Address: 192.168.80.1
Netmask: 255.255.255.0
```

### 2. Port Forwarding (if needed)
```bash
# Allow GPS API access from VenusOS
Network → Firewall → Port Forwards
External Port: 80
Internal Port: 80
Internal IP: 192.168.80.1
Protocol: TCP
```

### 3. Wireless Configuration
For mobile setups using cellular:
```bash
Network → Mobile → Configuration
APN: your-carrier-apn
Username/Password: as required
Connection Type: Auto
```

## GPS Antenna Setup

### 1. External Antenna (Recommended)
- Use high-quality GPS antenna
- Mount with clear sky view
- Use proper coaxial cable (low loss)

### 2. Antenna Testing
```bash
# Check GPS status
Status → GPS
# Look for:
# - Fix Type: 3D Fix
# - Satellites: 4+ satellites
# - HDOP: < 2.0
```

## API Testing

### Test GPS Data Retrieval
```bash
# Test RUTOS GPS API
curl -u username:password http://192.168.80.1/api/gps/position/status

# Expected response format:
{
  "latitude": 60.1699,
  "longitude": 24.9384,
  "altitude": 26,
  "accuracy": 1.5,
  "fix_status": 3,
  "satellites": 8,
  "speed": 0
}
```

## Security Configuration

### 1. Change Default Passwords
```bash
System → Administration → Password
# Set strong admin password
```

### 2. API Security
```bash
# Use HTTPS if available
Services → API → Enable HTTPS
# Use API keys instead of basic auth (if supported)
```

### 3. Firewall Rules
```bash
# Restrict API access to VenusOS IP only
Network → Firewall → Traffic Rules
Source IP: your-venus-ip
Destination Port: 80
Action: Accept
```

## Troubleshooting

### GPS Not Working
1. Check antenna connection
2. Verify GPS service enabled
3. Wait for initial fix (can take 15+ minutes)
4. Check satellite view obstruction

### API Access Issues
1. Verify credentials
2. Check firewall rules
3. Test with curl/browser
4. Review RUTOS logs

### Poor GPS Accuracy
1. Improve antenna placement
2. Check for interference
3. Allow longer settling time
4. Consider external antenna upgrade
