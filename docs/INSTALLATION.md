# Installation Guide

Complete installation instructions for the RUTOS Victron GPS Integration solution.

## 📋 Prerequisites

Before installing, ensure you have:

- **Venus OS** device with network connectivity
- **Node-RED** installed and running on Venus OS
- **RUTOS-based router** with GPS capability
- **Administrative access** to both Venus OS and router
- **Network connectivity** between all components

## 🚀 Installation Steps

### 1. Download Solution Files

Download or clone the solution files to your local machine:

```bash
# Option 1: Download from GitHub
wget https://github.com/your-repo/rutos-victron-gps/archive/main.zip
unzip main.zip

# Option 2: Clone repository
git clone https://github.com/your-repo/rutos-victron-gps.git
```

### 2. Transfer Files to Venus OS

**Option A: SCP Transfer**
```bash
scp src/flows/*.json root@<venus-os-ip>:/data/node-red/
```

**Option B: USB Transfer**
1. Copy flow files to USB drive
2. Insert USB into Venus OS device  
3. Copy files from `/media/usb0/` to `/data/node-red/`

**Option C: Direct Download on Venus OS**
```bash
# On Venus OS command line:
cd /data/node-red/
wget https://raw.githubusercontent.com/your-repo/rutos-victron-gps/main/src/flows/enhanced-victron-gps-control.json
wget https://raw.githubusercontent.com/your-repo/rutos-victron-gps/main/src/flows/gps-registration-verification-module.json
wget https://raw.githubusercontent.com/your-repo/rutos-victron-gps/main/src/flows/mqtt-gps-diagnostics.json  
wget https://raw.githubusercontent.com/your-repo/rutos-victron-gps/main/src/flows/fixed-gps-scanner-remover.json
```

### 3. Import Node-RED Flows

1. **Access Node-RED Interface**
   - Open browser to `http://<venus-os-ip>:1880`
   - Login if authentication is enabled

2. **Import Each Flow**
   - Click hamburger menu (☰) → Import
   - Select "Upload file" tab
   - Choose first flow file (`enhanced-victron-gps-control.json`)
   - Click "Import"
   - Repeat for remaining three flow files

3. **Verify Import**
   - Check that 4 new tabs appear in Node-RED
   - No error messages should appear
   - All nodes should show as properly configured

### 4. Configure Network Settings

Update network settings in each flow:

1. **MQTT Broker Configuration**
   - Double-click any MQTT node
   - Update server address to your Venus OS IP
   - Ensure port is 1883 (default)
   - Set client ID to unique value

2. **HTTP Request Endpoints**
   - RUTOS Router: `http://192.168.1.1/cgi-bin/luci/rpc/uci`
   - Starlink (if available): `http://192.168.100.1:9200`
   - Update IP addresses if your network uses different ranges

### 5. Configure Authentication

**Method 1: Node-RED Context Store (Recommended)**

1. Create temporary function node
2. Paste this code:
```javascript
flow.set('rutos_credentials', {
    username: 'admin',  // Your router username
    password: 'your_password_here'  // Your router password
});
node.log('Credentials stored');
return {payload: 'OK'};
```
3. Deploy and inject once
4. Delete the temporary function node
5. Credentials are now securely stored

**Method 2: Environment Variables**

On Venus OS command line:
```bash
export RUTOS_USERNAME="admin"
export RUTOS_PASSWORD="your_password"
systemctl restart nodered
```

### 6. Deploy and Test

1. **Deploy Flows**
   - Click "Deploy" button in Node-RED
   - Wait for successful deployment message

2. **Initial Test**
   - Check debug panel for GPS data
   - Look for successful authentication messages
   - Verify GPS device registration

3. **Verify Integration**
   - Check Venus OS device list for new GPS device
   - Monitor VRM Portal for position updates
   - Test both GPS sources (RUTOS and Starlink)

## 🔧 Configuration Options

### GPS Accuracy Thresholds

Default values (adjust if needed):
```javascript
// In Configuration Manager function:
config_rutos_accuracy: 1,      // RUTOS accuracy threshold (meters)
config_starlink_accuracy: 7,   // Starlink accuracy threshold (meters)  
config_position_eps: 6,        // Position change threshold (meters)
config_altitude_threshold: 18  // Altitude change threshold (meters)
```

### Update Intervals

Default timing (adjust for your needs):
```javascript
// GPS polling intervals:
rutos_interval: 30000,      // Poll RUTOS every 30 seconds
starlink_interval: 60000,   // Poll Starlink every 60 seconds
movement_check: 10000       // Check movement every 10 seconds
```

## 🚨 Troubleshooting Installation

### Common Issues

**Flow Import Fails**
- Check JSON file integrity
- Ensure sufficient disk space
- Restart Node-RED if necessary

**MQTT Connection Issues**
- Verify Venus OS IP address
- Check MQTT broker status: `systemctl status mosquitto`
- Test connectivity: `mosquitto_pub -h localhost -t test -m "hello"`

**Authentication Failures**
- Verify router credentials are correct
- Check network connectivity to router
- Test manual login to router web interface

**GPS Not Appearing**
- Check MQTT traffic with diagnostic flow
- Verify portal ID discovery
- Look for GPS instance conflicts

### Getting Help

If you encounter issues:

1. **Check Debug Output** - Enable all debug nodes and monitor messages
2. **Review Logs** - Check Node-RED logs and Venus OS system logs  
3. **Test Components** - Use diagnostic flows to isolate issues
4. **Consult Documentation** - Review troubleshooting guide
5. **Community Support** - Post issues with debug output and configuration details

## ✅ Installation Verification

### Checklist

- [ ] All 4 flows imported successfully
- [ ] MQTT broker configuration updated
- [ ] Router credentials configured
- [ ] Flows deployed without errors
- [ ] GPS data visible in debug output
- [ ] GPS device registered in Venus OS
- [ ] Position updates in VRM Portal

### Success Indicators

You should see:
- `✅ Using credentials from flow context store` in debug output
- `✅ GPS Device Found! Portal: xxx, Instance: x` messages
- GPS coordinates updating in debug panel
- New GPS device in Venus OS device list
- Position tracking in VRM Portal

## 🔄 Updates and Maintenance

### Updating the Solution

1. Download updated flow files
2. Import new versions (will replace existing)
3. Review configuration changes
4. Deploy and test

### Backup Configuration

Regular backup of:
```bash
# Node-RED flows and configuration
cp /data/home/nodered/.node-red/flows.json /backup/
cp /data/home/nodered/.node-red/flows_cred.json /backup/

# GPS configuration
# Credentials stored in Node-RED context are included in flows backup
```

---

**Installation Complete!** Your RUTOS Victron GPS integration should now be operational.
