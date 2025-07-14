# Troubleshooting Guide

## Common Issues and Solutions

### GPS Data Not Updating in VenusOS

#### Symptoms
- GPS coordinates stuck or not changing
- "No GPS fix" in VenusOS console
- Empty GPS data in device list

#### Solutions
1. **Check Node-RED Flow**
   ```bash
   # Access Node-RED: http://your-cerbo-ip:1880
   # Look for error messages in debug panel
   # Verify flow is deployed and running
   ```

2. **Verify RUTOS API Connectivity**
   ```bash
   # Test from VenusOS
   curl -u username:password http://192.168.80.1/api/gps/position/status
   ```

3. **Check MQTT Topics**
   ```bash
   # Monitor MQTT on VenusOS
   mosquitto_sub -h localhost -t '/N/+/gps/+'
   ```

### RUTOS GPS Service Issues

#### Symptoms
- No GPS fix on RUTOS device
- API returns null/empty data
- GPS coordinates showing 0,0

#### Solutions
1. **GPS Service Configuration**
   - Verify GPS service is enabled in RUTOS
   - Check antenna connection
   - Allow 15+ minutes for initial fix

2. **Antenna Issues**
   - Ensure clear sky view
   - Check coaxial cable connections
   - Test with different antenna location

3. **Device Positioning**
   - Avoid metal structures blocking GPS
   - Move device outdoors for testing
   - Check for interference sources

### Starlink Fallback Not Working

#### Symptoms
- GPS fails when RUTOS unavailable
- No fallback to Starlink coordinates
- Error messages about Starlink API

#### Solutions
1. **Starlink API Connectivity**
   ```bash
   # Test Starlink gRPC connection
   grpcurl -plaintext 192.168.100.1:9200 SpaceX.API.Device.Device/Handle
   ```

2. **Network Routing**
   - Verify Starlink dish IP (usually 192.168.100.1)
   - Check network routing to Starlink subnet
   - Test from VenusOS terminal

3. **Fallback Logic**
   - Review Node-RED flow conditions
   - Check accuracy thresholds
   - Verify timeout settings

### Performance Issues

#### Symptoms
- Slow GPS updates
- High CPU usage on VenusOS
- Node-RED flow timeouts

#### Solutions
1. **Update Frequency**
   - Reduce GPS polling frequency (30+ minutes)
   - Implement smart polling (only when needed)
   - Cache GPS data between updates

2. **Network Optimization**
   - Use static IPs for all devices
   - Reduce network latency
   - Optimize API call timeouts

3. **Resource Management**
   - Monitor VenusOS CPU/memory usage
   - Optimize Node-RED flows
   - Remove unnecessary debug nodes

### Data Accuracy Issues

#### Symptoms
- GPS coordinates jumping/inconsistent
- Poor accuracy readings
- Frequent source switching

#### Solutions
1. **Quality Filtering**
   - Increase accuracy thresholds
   - Implement coordinate smoothing
   - Add fix status validation

2. **Source Prioritization**
   - Prefer RUTOS over Starlink
   - Add minimum satellite count requirements
   - Implement GPS age validation

3. **Environmental Factors**
   - Improve antenna placement
   - Account for multipath interference
   - Consider differential GPS if available

## Debug Tools and Commands

### VenusOS Debugging
```bash
# Check VenusOS GPS service
dbus -y com.victronenergy.gps

# Monitor MQTT traffic
mosquitto_sub -h localhost -t '#' | grep gps

# Check system logs
tail -f /var/log/messages | grep gps
```

### RUTOS Debugging
```bash
# GPS service status
/etc/init.d/gps status

# GPS device info
cat /dev/ttyUSB0  # or appropriate GPS device

# System logs
logread | grep gps
```

### Node-RED Debugging
```bash
# Access debug panel: http://your-cerbo-ip:1880
# Add debug nodes to flow
# Monitor function node outputs
# Check error handling paths
```

## Error Codes and Messages

### Common Error Messages
- **"GPS API timeout"**: Network connectivity issue to RUTOS
- **"Invalid GPS data format"**: API response parsing error
- **"No GPS fix available"**: Neither RUTOS nor Starlink has valid GPS
- **"MQTT publish failed"**: VenusOS MQTT broker issue

### Resolution Steps
1. Check network connectivity
2. Verify API credentials
3. Test individual components
4. Review Node-RED flow logic
5. Check VenusOS system resources

## Getting Help

### Log Collection
When reporting issues, collect:
```bash
# VenusOS logs
journalctl -u node-red-venus

# RUTOS logs
logread > /tmp/rutos-logs.txt

# Node-RED flow export
# Export from Node-RED interface
```

### Support Resources
- [VenusOS Documentation](https://github.com/victronenergy/venus/wiki)
- [RUTOS Manual](https://wiki.teltonika-networks.com/)
- [Node-RED Documentation](https://nodered.org/docs/)
- [Project Repository](https://github.com/markus-lassfolk/rutos-victron-gps)
