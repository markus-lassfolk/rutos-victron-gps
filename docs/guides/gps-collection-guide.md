# GPS Accuracy Collection Guide
# =============================

## Prerequisites

1. **grpcurl installed** (for Starlink data collection)
   - Download from: https://github.com/fullstorydev/grpcurl/releases
   - Add to your PATH

2. **PowerShell 7+** (for cross-platform compatibility)
   - Download from: https://github.com/PowerShell/PowerShell/releases

3. **Network access** to both Starlink (192.168.100.1) and RUTOS (192.168.80.1)

## Usage Examples

### Basic Collection (1 hour, every 30 seconds)
```powershell
.\Collect-GPSAccuracy.ps1
```

### Custom Duration and Interval
```powershell
# Collect for 2 hours, every 60 seconds
.\Collect-GPSAccuracy.ps1 -Duration 7200 -Interval 60

# Quick 10-minute test, every 15 seconds
.\Collect-GPSAccuracy.ps1 -Duration 600 -Interval 15
```

### Custom Credentials
```powershell
.\Collect-GPSAccuracy.ps1 -RutosUser "admin" -RutosPass "yourpassword"
```

### Custom IP Addresses
```powershell
.\Collect-GPSAccuracy.ps1 -StarlinkIP "192.168.100.1" -RutosIP "192.168.80.1"
```

## Output

The script will:
1. **Show live GPS readings** from both sources
2. **Calculate real-time statistics** (accuracy, coordinates)
3. **Save detailed data** to JSON file for further analysis
4. **Provide recommended thresholds** based on collected data

## Sample Output

```
GPS Accuracy Data Collector
===========================
Duration: 3600 seconds (60.0 minutes)
Interval: 30 seconds

[14:30:15] Reading #1
  Starlink: 60.671234, 16.818567 (±8.2m)
  RUTOS: 60.671245, 16.818543 (±1.4m)

[14:30:45] Reading #2
  Starlink: 60.671231, 16.818571 (±7.8m)
  RUTOS: 60.671247, 16.818541 (±1.2m)

=== STARLINK GPS Statistics ===
Readings: 120
Average accuracy: 8.45 meters
Min accuracy: 5.20 meters
Max accuracy: 15.30 meters
Moving average (last 10): 8.12 meters
Recommended threshold: 13 meters

=== RUTOS GPS Statistics ===
Readings: 118
Average accuracy: 1.67 meters
Min accuracy: 0.80 meters
Max accuracy: 3.20 meters
Moving average (last 10): 1.52 meters
Recommended threshold: 3 meters

Recommended GPS Settings:
========================
rutos_accuracy: 3
starlink_accuracy: 13
```

## Troubleshooting

### grpcurl Not Found
```
Install grpcurl:
1. Download from GitHub releases
2. Extract to a folder in your PATH
3. Test: grpcurl --version
```

### Network Connection Issues
```
Make sure you're connected to both networks:
- Starlink: 192.168.100.0/24
- RUTOS: 192.168.80.0/24
```

### Certificate Errors (RUTOS)
```
The script uses -SkipCertificateCheck for HTTPS requests to RUTOS.
This is normal for local API access.
```

## Data Analysis

The collected JSON file contains:
- **Raw GPS readings** from both sources
- **Timestamps** for all readings
- **Accuracy measurements** over time
- **Collection metadata** (duration, intervals, etc.)

Use this data to:
1. **Optimize your GPS thresholds** in Node-RED
2. **Understand accuracy patterns** throughout the day
3. **Compare source reliability** in different conditions
