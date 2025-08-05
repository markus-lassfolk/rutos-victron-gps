# RUTOS Victron GPS Integration

![RUTOS](https://img.shields.io/badge/RUTOS-Compatible-green)
![VenusOS](https://img.shields.io/badge/VenusOS-Compatible-blue)
![Status](https://img.shields.io/badge/Status-Production_Ready-brightgreen)

## 🎯 Project Overview

This repository contains **production-ready Node-RED flows** for GPS integration with Victron Venus OS systems, supporting both Starlink and RUTOS GPS sources with intelligent accuracy-based source selection.

Provides real-time GPS data integration for Victron Energy systems by:
- Automatically selecting the most accurate GPS source (RUTOS or Starlink)
- Registering GPS devices with Venus OS via MQTT
- Publishing GPS coordinates, altitude, speed, and fix status
- Monitoring GPS data quality and connection health
- Managing GPS device lifecycle (registration/removal)

## 🚀 Key Features

- **Multi-source GPS:** Intelligently selects between RUTOS (~1m accuracy) and Starlink (~7m accuracy)
- **Data-driven thresholds:** Uses real-world measurements for accuracy filtering
- **Automatic registration:** Discovers and registers GPS devices with Venus OS
- **Smart movement detection:** Haversine distance calculations for precise movement tracking
- **Manual overrides:** MQTT control interface for source selection and configuration
- **Comprehensive diagnostics:** Real-time monitoring and health checks
- **Error handling:** Fallback mechanisms and degraded source detection

## 📁 Repository Structure

```
rutos-victron-gps/
├── src/
│   ├── flows/                     # Working Node-RED flows (PRODUCTION READY)
│   │   ├── enhanced-victron-gps-control.json
│   │   ├── mqtt-gps-diagnostics.json  
│   │   ├── gps-registration-verification-module.json
│   │   ├── fixed-gps-scanner-remover.json
│   │   └── README.md              # Flow documentation
│   ├── scripts/                   # Utility scripts and tools
│   │   ├── GPS accuracy analysis scripts
│   │   ├── Test and control scripts  
│   │   └── PowerShell utilities
│   ├── config/                    # Configuration files
│   └── package.json               # Node-RED dependencies
├── docs/                          # Documentation
│   ├── GPS_INTEGRATION_GUIDE.md   # Setup and integration guide
│   ├── rutos-setup.md            # RUTOS GPS configuration  
│   ├── venusOS-setup.md          # Venus OS setup instructions
│   ├── troubleshooting.md        # Common issues and solutions
│   ├── reference/                # Reference documentation
│   └── guides/                   # Additional guides
├── assets/                       # Images and media
├── temp/                         # Development files and archives
└── README.md                     # This file
```

## 🏗️ System Architecture

```
GPS Sources:
┌─────────────┐    ┌─────────────┐
│   Starlink  │    │    RUTOS    │
│ gRPC:9200   │    │ HTTPS API   │
│ ~7m accuracy│    │ ~1m accuracy│
└──────┬──────┘    └──────┬──────┘
       │                  │
       └─────────┬────────┘
                 │
┌────────────────▼────────────────┐
│   Enhanced GPS Control Flow    │
│   • Source selection logic     │
│   • Data validation           │  
│   • Movement detection        │
└────────────────┬────────────────┘
                 │
┌────────────────▼────────────────┐
│   GPS Registration Module      │
│   • Device discovery           │
│   • Venus OS registration      │
│   • VRM Portal ID learning     │
└────────────────┬────────────────┘
                 │
┌────────────────▼────────────────┐
│     Victron Venus OS           │  
│     Cerbo GX: 192.168.80.242   │
│     MQTT Broker                 │
└─────────────────────────────────┘
```

## 📋 Quick Start

### Prerequisites
- RUTOS device (RUTX09, RUTX11, RUTX14, etc.)
- VenusOS system (Cerbo GX, Venus GX, etc.)
- Network connectivity between devices

### Installation
```bash
# Clone repository
git clone https://github.com/markus-lassfolk/rutos-victron-gps.git
cd rutos-victron-gps

# Deploy to RUTOS device
scp src/victron-gps-flow.json root@your-rutos-ip:/etc/
```

## 📖 Documentation

- [GPS Integration Guide](docs/GPS_INTEGRATION_GUIDE.md)
- [VenusOS Configuration](docs/venusOS-setup.md)
- [RUTOS Setup](docs/rutos-setup.md)
- [Troubleshooting](docs/troubleshooting.md)

## 🔧 Configuration

The integration uses Node-RED flows for data processing:

```json
{
  "id": "victron-gps-flow",
  "type": "tab",
  "label": "VenusOS GPS Integration"
}
```

## 🤝 Related Projects

- [RUTOS Starlink Solution](https://github.com/markus-lassfolk/rutos-starlink-victron) - Main Starlink monitoring and failover
- [VenusOS Documentation](https://github.com/victronenergy/venus/wiki)

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Victron Energy for VenusOS
- Teltonika for RUTOS platform
- SpaceX for Starlink connectivity

---
*Part of the RUTOS ecosystem for enhanced connectivity and monitoring*
