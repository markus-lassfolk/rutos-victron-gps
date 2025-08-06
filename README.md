# RUTOS Victron GPS Integration

![RUTOS](https://img.shields.io/badge/RUTOS-Compatible-green)
![VenusOS](https://img.shields.io/badge/VenusOS-Compatible-blue)
![Status](https://img.shields.io/badge/Status-Production_Ready-brightgreen)

A robust GPS integration solution for Victron Energy systems using Node-RED, designed for Venus OS environments with RUTOS-based routers and Starlink connectivity.

## 🌟 Features

- **Dual GPS Sources**: RUTOS GPS (high precision ~0.4m) + Starlink GPS (backup ~5-7m)
- **Automatic GPS Registration**: Self-registering GPS device on Venus OS
- **Smart Source Selection**: Always uses the most accurate available GPS source
- **Automatic Device Discovery**: Handles Victron system reboots and changes
- **Movement Detection**: Intelligent position change detection using Haversine distance
- **MQTT Communication**: Native integration with Venus OS via MQTT
- **Diagnostic Tools**: Built-in GPS device management and diagnostics

## 📋 Requirements

- **Venus OS** system (Victron Energy)
- **Node-RED** installed on Venus OS
- **RUTOS-based router** with GPS capability
- **MQTT broker** access on Venus OS (typically built-in)
- **Network connectivity** to both router and Starlink (if available)

## 📁 Solution Components

### Core Node-RED Flows

1. **`enhanced-victron-gps-control.json`** - Main GPS integration flow
   - Dual GPS source management (RUTOS + Starlink)
   - Smart GPS selection logic based on accuracy
   - MQTT publishing to Venus OS
   - Movement detection and position filtering
   - Data-driven accuracy thresholds

2. **`gps-registration-verification-module.json`** - GPS device registration
   - Automatic GPS device registration with Venus OS
   - VRM Portal ID discovery and learning
   - GPS instance management and discovery
   - Handle Venus OS reboots and reconfigurations

3. **`mqtt-gps-diagnostics.json`** - MQTT diagnostic tools
   - GPS topic monitoring and debugging
   - Device discovery and verification
   - MQTT traffic analysis
   - Troubleshooting utilities

4. **`fixed-gps-scanner-remover.json`** - GPS device management
   - Scan for existing GPS devices
   - Remove orphaned or conflicting GPS devices
   - Device cleanup and maintenance utilities

## 🚀 Quick Start

### 1. Import Node-RED Flows

1. **Access Node-RED** on your Venus OS system (typically `http://venus-os-ip:1880`)
2. **Import flows** using the Node-RED import function:
   - Click the hamburger menu → Import
   - Select "Upload file" for each `.json` flow file in `src/flows/`
   - Import all four core flows

### 2. Configure Network Settings

Update the following network settings in all flows:

- **Venus OS MQTT Broker**: Update to your Venus OS IP address
- **RUTOS Router**: Default `192.168.1.1` (update if different)
- **Starlink Terminal**: Default `192.168.100.1` (if available)

### 3. Configure Authentication

**Method 1: Node-RED Context Store (Recommended)**

Create a temporary function node with this code, inject once, then delete:

```javascript
// Set RUTOS router credentials
flow.set('rutos_credentials', {
    username: 'your_router_username',
    password: 'your_router_password'
});

node.log('✅ Credentials stored in Node-RED context');
return {payload: 'Credentials configured'};
```

**Method 2: Environment Variables**

On Venus OS command line:

```bash
export RUTOS_USERNAME="your_username"
export RUTOS_PASSWORD="your_password"
systemctl restart nodered
```

### 4. Deploy and Test

1. **Deploy all flows** in Node-RED
2. **Monitor debug output** for GPS data flow
3. **Check Venus OS** - GPS device should appear in device list
4. **Verify in VRM Portal** - Position updates should appear

## 🛠️ Configuration

### GPS Accuracy Thresholds

The system uses optimized thresholds based on real-world testing:

- **RUTOS Accuracy**: 1m threshold (typical: 0.4-0.5m accuracy)
- **Starlink Accuracy**: 7m threshold (typical: 5-6m accuracy)
- **Position Change**: 6m minimum distance for position updates
- **Altitude Change**: 18m minimum change for altitude updates
- **Speed Threshold**: 0.1 m/s minimum for speed-based updates

### Network Endpoints

Default configuration:
- **RUTOS Router**: `http://192.168.1.1/cgi-bin/luci/rpc/uci`
- **Starlink gRPC**: `http://192.168.100.1:9200`
- **Venus OS MQTT**: `localhost:1883` (from Node-RED context)

## 📖 Documentation

- **[GPS Integration Guide](docs/GPS_INTEGRATION_GUIDE.md)** - Comprehensive setup guide
- **[RUTOS Setup](docs/rutos-setup.md)** - Router configuration instructions
- **[Venus OS Setup](docs/venusOS-setup.md)** - Venus OS specific configuration
- **[Troubleshooting](docs/troubleshooting.md)** - Common issues and solutions

## 🔧 How It Works

### GPS Source Selection Logic

1. **Primary**: RUTOS GPS (when available and accurate < 1m)
2. **Fallback**: Starlink GPS (when RUTOS unavailable or inaccurate)
3. **Intelligent Switching**: Automatic source switching based on real-time accuracy

### Automatic Device Registration

- **Discovery**: Finds Venus OS portal ID automatically
- **Registration**: Creates GPS device with unique instance
- **Persistence**: Survives Venus OS reboots and updates
- **Conflict Resolution**: Handles multiple GPS device scenarios

### Movement Detection

- **Haversine Distance**: Accurate distance calculations accounting for Earth curvature
- **Smart Filtering**: Reduces unnecessary updates from GPS jitter
- **Configurable Thresholds**: Customizable for different use cases
- **Status Monitoring**: Real-time accuracy and connection status

## 🚨 Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| **GPS not appearing in Venus OS** | Registration failure | Check MQTT connectivity and portal ID |
| **Authentication errors** | Wrong credentials | Verify RUTOS username/password |
| **Position not updating** | Threshold too high | Check movement detection settings |
| **JSON parsing errors** | Network timeout | Check network connectivity to sources |

### Debug Tools

The diagnostic flows provide:

- **MQTT Traffic Monitor** - See all GPS-related MQTT messages
- **Device Scanner** - Find existing GPS devices and conflicts
- **Connection Tester** - Test individual GPS source connections
- **Data Flow Tracer** - Follow GPS data through the entire pipeline

### Log Analysis

Monitor Node-RED debug output for:
- `✅` GPS data successfully processed
- `⚠️` Fallback to secondary GPS source
- `❌` Connection or authentication failures
- `🔍` Device discovery and registration events

## 🔒 Security Considerations

- **Credential Storage**: Use Node-RED context store (encrypted) instead of hardcoded values
- **Network Security**: Ensure MQTT and HTTP connections are on trusted networks
- **Access Control**: Restrict Node-RED interface access to authorized users
- **Updates**: Keep Venus OS and Node-RED updated for security patches

## 🤝 Contributing

Contributions welcome! Areas for improvement:
- Additional GPS source integrations
- Enhanced error handling and recovery
- Performance optimizations
- Documentation improvements
- Testing on additional hardware configurations

## 📄 License

Open source under MIT License. See individual files for specific licensing.

## 📊 Performance

Typical performance metrics:
- **GPS Update Rate**: Every 10-30 seconds (configurable)
- **Position Accuracy**: 0.4-0.5m (RUTOS), 5-7m (Starlink)
- **Network Latency**: <100ms for local RUTOS, <500ms for Starlink
- **Resource Usage**: Minimal impact on Venus OS performance

---

**Production Ready**: This solution is actively used in marine and mobile installations with Victron Energy systems.
