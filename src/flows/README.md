# Working Node-RED GPS Flows

This directory contains the **4 verified working Node-RED flows** for GPS integration with Victron Venus OS systems.

## 🚀 Active Flows (In Use)

### 1. Enhanced Victron GPS Control
**File:** `enhanced-victron-gps-control.json`  
**Description:** Main GPS processing flow with intelligent source selection and data-driven thresholds.

**Features:**
- Data-driven accuracy thresholds (RUTOS: 1m, Starlink: 7m, Position: 6m, Altitude: 18m)
- Always-use-most-accurate GPS source selection
- Smart movement detection with Haversine distance calculations  
- Enhanced error handling with fallback logic
- Manual override system
- File logging with accuracy tracking
- GPS stability monitoring (6m threshold)
- Configurable parameters via MQTT

**MQTT Topics for Control:**
- `gps/control/source` - Set source override: 'auto', 'rutos', 'starlink'
- `gps/control/force_update` - Force GPS update
- `gps/control/config` - Set configuration parameters

### 2. MQTT GPS Diagnostics  
**File:** `mqtt-gps-diagnostics.json`  
**Description:** Comprehensive MQTT monitoring and diagnostics for GPS data streams.

**Features:**
- Real-time MQTT topic monitoring for GPS data
- Device discovery and serial number detection
- GPS data validation and verification
- Performance monitoring
- Test GPS data injection for validation

**Target:** Cerbo GX at 192.168.80.242

### 3. GPS Registration & Verification Module
**File:** `gps-registration-verification-module.json`  
**Description:** Standalone GPS device registration system for Venus OS integration.

**Features:**
- Automatic Cerbo GX device ID discovery
- GPS device registration with Venus OS
- VRM Portal ID and GPS instance learning
- GPS data reception verification
- Status monitoring and health checks
- Comprehensive registration status reporting

**Global Variables Provided:**
- `global.vrm_portal_id` - VRM Portal ID for GPS publishing
- `flow.gps_instance` - GPS device instance number  
- `flow.gps_publishing_enabled` - Ready state for GPS publishing
- `flow.discovered_device_id` - Cerbo GX device ID
- `flow.gps_client_id` - Registered GPS client ID

### 4. Fixed GPS Scanner & Remover
**File:** `fixed-gps-scanner-remover.json`  
**Description:** GPS device discovery, management, and cleanup utility.

**Features:**
- Enhanced GPS device scanning and discovery
- Device connection status monitoring
- Selective GPS device removal
- Device registry maintenance
- Real-time device status tracking

## 📋 GPS Data Sources

The flows support multiple GPS data sources:

1. **Starlink** - Retrieved via gRPC from `192.168.100.1:9200`
   - Typical accuracy: ~7m
   - Uses SpaceX.API.Device.Device/Handle for location data

2. **RUTOS** - Retrieved via HTTPS API from `192.168.80.1`  
   - Typical accuracy: ~1m
   - Requires authentication with admin credentials

## 🔧 Installation & Usage

1. **Import flows:** Import each JSON file into your Node-RED instance
2. **Configure MQTT broker:** Update MQTT broker settings to point to your Cerbo GX (typically `192.168.80.242`)
3. **Update credentials:** Set RUTOS admin credentials in the RUTOS login node
4. **Deploy:** Deploy the flows and monitor the debug output

## 📊 Flow Dependencies

```
GPS Registration & Verification Module
    ↓ (provides global variables)
Enhanced Victron GPS Control
    ↓ (publishes GPS data)
MQTT GPS Diagnostics
    ↓ (monitors data flow)
Fixed GPS Scanner & Remover
    ↓ (maintains device registry)
```

## 🎯 MQTT Broker Configuration

**Primary Cerbo GX MQTT Broker:** `192.168.80.242:1883`
- Client ID: Various (auto-generated)
- Protocol: MQTT v4
- QoS: 2 (for critical GPS data)

## 💡 Usage Tips

1. **Start with Registration Module:** Always deploy the GPS Registration & Verification Module first
2. **Monitor Status:** Watch debug outputs for registration status and health checks  
3. **Check Variables:** Ensure `global.vrm_portal_id` and `flow.gps_instance` are set before GPS publishing
4. **Use Diagnostics:** Use the MQTT GPS Diagnostics flow to troubleshoot data flow issues
5. **Manual Override:** Use MQTT control topics to manually override source selection or force updates

## 📝 Notes

- All flows are production-tested and working
- Flows include comprehensive error handling and logging
- GPS accuracy thresholds are data-driven based on real-world measurements  
- Supports both automatic and manual GPS source selection
- Includes fallback mechanisms for GPS source failures

---

*Last Updated: August 6, 2025*  
*Repository: rutos-victron-gps*  
*Owner: markus-lassfolk*
