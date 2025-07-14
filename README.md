# VenusOS GPS Integration for RUTOS

![RUTOS](https://img.shields.io/badge/RUTOS-Compatible-green)
![VenusOS](https://img.shields.io/badge/VenusOS-Compatible-blue)
![License](https://img.shields.io/badge/License-MIT-yellow)

## 🎯 Overview

This repository provides GPS integration between RUTOS devices and VenusOS systems, with Starlink fallback positioning for enhanced reliability in mobile/marine applications.

## 🚀 Features

- **VenusOS Integration**: Direct GPS data flow to Victron Energy systems
- **RUTOS Compatibility**: Optimized for Teltonika RUTOS devices
- **Starlink Fallback**: Automatic positioning fallback using Starlink satellite data
- **Real-time Updates**: Continuous GPS coordinate streaming
- **Maritime/Mobile Ready**: Designed for boats, RVs, and remote installations

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
