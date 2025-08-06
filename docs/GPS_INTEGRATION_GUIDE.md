# Victron GPS Failover with Node-RED, RUTOS, and Starlink

This project provides a robust solution for ensuring a Victron Cerbo GX (or Cerbo CX) has a consistent and accurate GPS location, which is critical for features like Solar Forecast. It uses Node-RED running on the Cerbo to pull GPS data from two independent sources—a Teltonika RUTX50 router and a Starlink dish—and intelligently selects the best source to publish to the Victron system.

## The Goal

The Victron system's solar forecast relies on knowing the vessel or vehicle's precise location. While the Cerbo can have its own GPS, this project creates a redundant system for mobile setups (RVs, boats) where multiple GPS sources are often available. By using the high-quality GPS from a cellular router (RUTX50) as the primary source and the Starlink dish's GPS as a reliable backup, we ensure the system never loses its location, even if one device is offline.

## How It Works

The solution consists of four integrated Node-RED flows that work together:

**Main GPS Integration Flow:**
- **Trigger:** Every 30 seconds, polls GPS sources for location data
- **Dual Data Fetching:** Simultaneously queries RUTOS API and Starlink gRPC for GPS data
- **Intelligent Source Selection:** Prioritizes RUTOS GPS for accuracy (~0.4m) with automatic Starlink fallback (~5-7m)
- **Quality Assessment:** Analyzes GPS fix status, accuracy, and satellite count to select optimal source
- **MQTT Publishing:** Formats and publishes GPS data to Venus OS via local MQTT broker

**GPS Device Registration Flow:**
- **Auto-Discovery:** Automatically discovers VRM Portal ID and GPS device instances
- **Smart Registration:** Registers GPS device with Venus OS D-Bus system
- **Reboot Handling:** Handles Venus OS reboots and automatically re-registers GPS device
- **Instance Management:** Manages GPS device instances to avoid conflicts

**MQTT Diagnostic Flow:**
- **Traffic Monitoring:** Monitors all GPS-related MQTT traffic for debugging
- **Device Discovery:** Scans and reports available GPS devices and instances
- **Troubleshooting:** Provides diagnostic information for system issues

**GPS Device Management Flow:**
- **Device Cleanup:** Removes conflicting or duplicate GPS device registrations
- **System Maintenance:** Provides utilities for GPS device management
- **Conflict Resolution:** Resolves GPS instance conflicts automatically

**Advanced Features:**
- **Movement Detection:** Calculates distance using Haversine formula to detect position changes
- **Obstruction Map Reset:** Automatically resets Starlink obstruction map when moved >500m
- **Data-Driven Configuration:** Uses intelligent thresholds based on real GPS performance data

![image](https://github.com/user-attachments/assets/b883022b-914e-468d-8f7f-7b9fa44cc08c)


## Prerequisites

### 1. Hardware

- A Victron Cerbo GX or Cerbo CX.
- A Teltonika RUTX50 router (or another RUTOS device with an active GPS and accessible API).
- A Starlink dish running in Bypass Mode.

### 2. Victron Cerbo GX / Venus OS

- You must be running a **Venus OS Large** image. (Instructions: https://www.victronenergy.com/live/venus-os:large) 
- Enable MQTT on LAN (SSL and plain text) in `Settings -> Services`.

### 3. Node-RED

No special community nodes are required. The flow uses default nodes (http request, exec, mqtt, function, etc.).

Install `grpcurl` via SSH:

```sh
curl -fL https://github.com/fullstorydev/grpcurl/releases/download/v1.9.3/grpcurl_1.9.3_linux_armv7.tar.gz -o /tmp/grpcurl.tar.gz
tar -zxvf /tmp/grpcurl.tar.gz -C /usr/bin/ grpcurl
chmod +x /usr/bin/grpcurl
rm /tmp/grpcurl.tar.gz
```

### 4. Teltonika RUTX50 Router

- The API must be accessible from the Cerbo GX.
- Enable GPS on the router via WebUI or SSH:

```sh
uci set gps.gpsd.enabled='1'
uci commit gps
/etc/init.d/gpsd restart
```

### 5. Starlink Dish

- Must be in Bypass Mode.
- Ensure the RUTX50 has a static route to `192.168.100.1` for API access.

## Solution Architecture

This solution consists of four integrated Node-RED flows located in `src/flows/`:

1. **`enhanced-victron-gps-control.json`** - Core GPS integration flow with dual-source management
2. **`gps-registration-verification-module.json`** - Automatic GPS device registration system  
3. **`mqtt-gps-diagnostics.json`** - MQTT diagnostic and monitoring tools
4. **`fixed-gps-scanner-remover.json`** - GPS device management utilities

The flows work together to provide a complete, robust GPS integration solution with automatic failover, device discovery, and comprehensive diagnostics.

## Installation and Configuration

### 1. Import Node-RED Flows

1. Navigate to Node-RED: `http://<cerbo-ip-address>:1880`
2. Click ☰ → Import
3. Import each of the four flow files:
   - `enhanced-victron-gps-control.json` - Main GPS integration
   - `gps-registration-verification-module.json` - GPS device registration  
   - `mqtt-gps-diagnostics.json` - MQTT diagnostics
   - `fixed-gps-scanner-remover.json` - GPS device management

### 2. Configure Secure Credentials

**Method 1: Node-RED Context Store (Recommended)**

1. Create a temporary function node in Node-RED
2. Paste this code:

```js
flow.set('rutos_credentials', {
    username: 'admin',  // Your RUTOS router username
    password: 'your_secure_password'  // Your RUTOS router password
});
node.log('Credentials stored securely');
return {payload: 'Credentials configured'};
```

3. Deploy and inject once to store credentials
4. **Delete the temporary function node** - credentials remain stored securely
5. The flows will automatically use these stored credentials

**Method 2: Environment Variables**

On Venus OS command line:
```bash
export RUTOS_USERNAME="admin"
export RUTOS_PASSWORD="your_password"
systemctl restart nodered
```

### 3. Verify Network Configuration

- **RUTOS Router**: Ensure HTTP request nodes point to your router IP (default: `192.168.80.1`)
- **Starlink**: Verify Starlink gRPC endpoint uses `192.168.100.1:9200`  
- **MQTT Broker**: Confirm MQTT nodes target your Venus OS IP address
- **Network Connectivity**: Test connectivity between Venus OS and both GPS sources

### 4. Deploy and Verify

1. Click **Deploy** in Node-RED
2. Monitor the Debug sidebar for:
   - `✅ Using credentials from flow context store`
   - GPS data from both RUTOS and Starlink sources
   - GPS device registration messages
   - MQTT publication confirmations

3. Check Venus OS device list for newly registered GPS device
4. Verify position updates appear in VRM Portal

The system will automatically:
- Poll GPS sources every 30 seconds
- Select the most accurate GPS source
- Register GPS device with Venus OS
- Handle Venus OS reboots and reconfigurations

---

Enjoy a rock-solid GPS system that ensures Victron accuracy even in mobile, roaming environments.
