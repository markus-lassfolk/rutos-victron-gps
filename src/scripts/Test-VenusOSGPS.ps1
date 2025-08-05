# Venus OS GPS Diagnostic Tool
# ============================
# Diagnoses GPS registration issues on Cerbo GX at 192.168.80.242

param(
    [string]$CerboIP = "192.168.80.242",
    [string]$Command = "test_all",
    [switch]$Verbose
)

Write-Host "Venus OS GPS Diagnostic Tool" -ForegroundColor Green
Write-Host "============================" -ForegroundColor Green
Write-Host "Target Cerbo GX: $CerboIP" -ForegroundColor Yellow
Write-Host ""

# Function to test MQTT broker connectivity
function Test-MQTTBroker {
    param([string]$IP)
    
    Write-Host "=== TESTING MQTT BROKER CONNECTIVITY ===" -ForegroundColor Cyan
    Write-Host "Testing connection to $IP:1883..." -ForegroundColor White
    
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connectTask = $tcpClient.ConnectAsync($IP, 1883)
        $timeout = 5000 # 5 seconds
        
        if ($connectTask.Wait($timeout)) {
            Write-Host "✅ MQTT Broker is accessible on $IP:1883" -ForegroundColor Green
            $tcpClient.Close()
            return $true
        } else {
            Write-Host "❌ MQTT Broker connection timed out" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "❌ MQTT Broker connection failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to check Venus OS web interface
function Test-VenusOSWeb {
    param([string]$IP)
    
    Write-Host "=== TESTING VENUS OS WEB INTERFACE ===" -ForegroundColor Cyan
    Write-Host "Testing web interface at http://$IP..." -ForegroundColor White
    
    try {
        $response = Invoke-WebRequest -Uri "http://$IP" -TimeoutSec 10 -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            Write-Host "✅ Venus OS web interface is accessible" -ForegroundColor Green
            Write-Host "   Status: $($response.StatusCode)" -ForegroundColor White
            return $true
        } else {
            Write-Host "⚠️  Venus OS responded with status: $($response.StatusCode)" -ForegroundColor Yellow
            return $false
        }
    } catch {
        Write-Host "❌ Venus OS web interface not accessible: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to test SSH connectivity (for advanced diagnostics)
function Test-SSHConnectivity {
    param([string]$IP)
    
    Write-Host "=== TESTING SSH CONNECTIVITY ===" -ForegroundColor Cyan
    Write-Host "Testing SSH on $IP:22..." -ForegroundColor White
    
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connectTask = $tcpClient.ConnectAsync($IP, 22)
        $timeout = 5000 # 5 seconds
        
        if ($connectTask.Wait($timeout)) {
            Write-Host "✅ SSH is accessible on $IP:22" -ForegroundColor Green
            Write-Host "   You can SSH for advanced diagnostics: ssh root@$IP" -ForegroundColor Cyan
            $tcpClient.Close()
            return $true
        } else {
            Write-Host "❌ SSH connection timed out" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "❌ SSH connection failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to create MQTT diagnostic commands
function Get-MQTTDiagnosticCommands {
    param([string]$IP)
    
    Write-Host "=== MQTT DIAGNOSTIC COMMANDS ===" -ForegroundColor Cyan
    Write-Host "Use these mosquitto commands to test MQTT connectivity:" -ForegroundColor White
    Write-Host ""
    
    Write-Host "1. Listen to ALL GPS topics:" -ForegroundColor Yellow
    Write-Host "   mosquitto_sub -h $IP -t 'N/+/gps/+/+' -v" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "2. Listen to device announcements:" -ForegroundColor Yellow
    Write-Host "   mosquitto_sub -h $IP -t 'N/+/system/0/Serial' -v" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "3. Listen to device scanning:" -ForegroundColor Yellow
    Write-Host "   mosquitto_sub -h $IP -t 'N/+/+/+/DeviceInstance' -v" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "4. Test GPS registration (manual):" -ForegroundColor Yellow
    Write-Host "   mosquitto_pub -h $IP -t 'N/b827ebfffe7fec6b/gps/1/Position' -m '{\"value\":{\"Latitude\":0,\"Longitude\":0}}'" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "5. Check for existing GPS devices:" -ForegroundColor Yellow
    Write-Host "   mosquitto_sub -h $IP -t 'N/+/gps/+/Position' -v" -ForegroundColor Green
    Write-Host ""
}

# Function to generate Node-RED MQTT diagnostic flow
function Create-MQTTDiagnosticFlow {
    param([string]$IP)
    
    Write-Host "=== CREATING MQTT DIAGNOSTIC FLOW ===" -ForegroundColor Cyan
    Write-Host "Generating Node-RED flow for comprehensive MQTT testing..." -ForegroundColor White
    
    $diagnosticFlow = @"
[
    {
        "id": "mqtt_diagnostic_tab",
        "type": "tab",
        "label": "MQTT GPS Diagnostics",
        "disabled": false,
        "info": "Comprehensive MQTT GPS diagnostic flow for Cerbo GX at $IP"
    },
    {
        "id": "listen_all_gps",
        "type": "mqtt in",
        "z": "mqtt_diagnostic_tab",
        "name": "Listen ALL GPS Topics",
        "topic": "N/+/gps/+/+",
        "qos": "0",
        "datatype": "auto",
        "broker": "diagnostic_broker",
        "nl": false,
        "rap": true,
        "rh": 0,
        "inputs": 0,
        "x": 160,
        "y": 80,
        "wires": [["gps_debug"]]
    },
    {
        "id": "listen_device_serial",
        "type": "mqtt in",
        "z": "mqtt_diagnostic_tab",
        "name": "Listen Device Serial",
        "topic": "N/+/system/0/Serial",
        "qos": "0",
        "datatype": "auto",
        "broker": "diagnostic_broker",
        "nl": false,
        "rap": true,
        "rh": 0,
        "inputs": 0,
        "x": 160,
        "y": 140,
        "wires": [["device_debug"]]
    },
    {
        "id": "listen_device_instances",
        "type": "mqtt in",
        "z": "mqtt_diagnostic_tab",
        "name": "Listen Device Instances",
        "topic": "N/+/+/+/DeviceInstance",
        "qos": "0",
        "datatype": "auto",
        "broker": "diagnostic_broker",
        "nl": false,
        "rap": true,
        "rh": 0,
        "inputs": 0,
        "x": 160,
        "y": 200,
        "wires": [["instance_debug"]]
    },
    {
        "id": "test_gps_registration",
        "type": "inject",
        "z": "mqtt_diagnostic_tab",
        "name": "Test GPS Registration",
        "props": [{"p": "payload"}],
        "repeat": "",
        "crontab": "",
        "once": false,
        "onceDelay": 0.1,
        "topic": "",
        "payload": "{\"value\":{\"Latitude\":60.1699,\"Longitude\":24.9384,\"Altitude\":10}}",
        "payloadType": "json",
        "x": 160,
        "y": 300,
        "wires": [["gps_register_out"]]
    },
    {
        "id": "gps_register_out",
        "type": "mqtt out",
        "z": "mqtt_diagnostic_tab",
        "name": "Send Test GPS Data",
        "topic": "N/b827ebfffe7fec6b/gps/1/Position",
        "qos": "0",
        "retain": "false",
        "respTopic": "",
        "contentType": "",
        "userProps": "",
        "correl": "",
        "expiry": "",
        "broker": "diagnostic_broker",
        "x": 420,
        "y": 300,
        "wires": []
    },
    {
        "id": "gps_debug",
        "type": "debug",
        "z": "mqtt_diagnostic_tab",
        "name": "GPS Topics Debug",
        "active": true,
        "tosidebar": true,
        "console": false,
        "tostatus": false,
        "complete": "true",
        "targetType": "full",
        "statusVal": "",
        "statusType": "auto",
        "x": 420,
        "y": 80,
        "wires": []
    },
    {
        "id": "device_debug",
        "type": "debug",
        "z": "mqtt_diagnostic_tab",
        "name": "Device Debug",
        "active": true,
        "tosidebar": true,
        "console": false,
        "tostatus": false,
        "complete": "true",
        "targetType": "full",
        "statusVal": "",
        "statusType": "auto",
        "x": 420,
        "y": 140,
        "wires": []
    },
    {
        "id": "instance_debug",
        "type": "debug",
        "z": "mqtt_diagnostic_tab",
        "name": "Instance Debug",
        "active": true,
        "tosidebar": true,
        "console": false,
        "tostatus": false,
        "complete": "true",
        "targetType": "full",
        "statusVal": "",
        "statusType": "auto",
        "x": 420,
        "y": 200,
        "wires": []
    },
    {
        "id": "diagnostic_broker",
        "type": "mqtt-broker",
        "name": "Cerbo GX Diagnostics",
        "broker": "$IP",
        "port": "1883",
        "clientid": "gps-diagnostics",
        "autoConnect": true,
        "usetls": false,
        "protocolVersion": "4",
        "keepalive": "60",
        "cleansession": true,
        "autoUnsubscribe": true,
        "birthTopic": "",
        "birthQos": "0",
        "birthRetain": "false",
        "birthPayload": "",
        "birthMsg": {},
        "closeTopic": "",
        "closeQos": "0",
        "closeRetain": "false",
        "closePayload": "",
        "closeMsg": {},
        "willTopic": "",
        "willQos": "0",
        "willRetain": "false",
        "willPayload": "",
        "willMsg": {},
        "userProps": "",
        "sessionExpiry": ""
    }
]
"@
    
    $flowPath = "c:\GitHub\rutos-victron-gps\temp\mqtt-gps-diagnostics.json"
    $diagnosticFlow | Out-File -FilePath $flowPath -Encoding UTF8
    Write-Host "✅ Diagnostic flow created: $flowPath" -ForegroundColor Green
    Write-Host "   Import this into Node-RED to monitor all GPS MQTT traffic" -ForegroundColor Cyan
}

# Function to check device ID format
function Test-DeviceIDFormat {
    param([string]$IP)
    
    Write-Host "=== DEVICE ID ANALYSIS ===" -ForegroundColor Cyan
    Write-Host "Current registration uses device ID: b827ebfffe7fec6b" -ForegroundColor White
    Write-Host "This appears to be a Raspberry Pi MAC-based ID" -ForegroundColor White
    Write-Host ""
    Write-Host "To find the correct device ID:" -ForegroundColor Yellow
    Write-Host "1. Check Venus OS web interface at http://$IP" -ForegroundColor Green
    Write-Host "2. Look for VRM Portal ID or System Serial" -ForegroundColor Green
    Write-Host "3. Monitor MQTT for actual device announcements" -ForegroundColor Green
    Write-Host ""
}

# Main diagnostic function
function Start-GPSDiagnostics {
    param([string]$IP)
    
    Write-Host "Starting comprehensive GPS diagnostics..." -ForegroundColor Yellow
    Write-Host ""
    
    # Test basic connectivity
    $mqttOK = Test-MQTTBroker -IP $IP
    $webOK = Test-VenusOSWeb -IP $IP
    $sshOK = Test-SSHConnectivity -IP $IP
    
    Write-Host ""
    
    # Analyze device ID
    Test-DeviceIDFormat -IP $IP
    
    # Generate diagnostic tools
    Get-MQTTDiagnosticCommands -IP $IP
    Create-MQTTDiagnosticFlow -IP $IP
    
    Write-Host ""
    Write-Host "=== DIAGNOSTIC SUMMARY ===" -ForegroundColor Magenta
    Write-Host "MQTT Broker: $(if($mqttOK){'✅ OK'}else{'❌ FAILED'})" -ForegroundColor $(if($mqttOK){'Green'}else{'Red'})
    Write-Host "Web Interface: $(if($webOK){'✅ OK'}else{'❌ FAILED'})" -ForegroundColor $(if($webOK){'Green'}else{'Red'})
    Write-Host "SSH Access: $(if($sshOK){'✅ OK'}else{'❌ FAILED'})" -ForegroundColor $(if($sshOK){'Green'}else{'Red'})
    Write-Host ""
    
    if ($mqttOK) {
        Write-Host "🎯 NEXT STEPS:" -ForegroundColor Cyan
        Write-Host "1. Import the diagnostic flow: mqtt-gps-diagnostics.json" -ForegroundColor White
        Write-Host "2. Deploy and watch for ANY GPS MQTT traffic" -ForegroundColor White
        Write-Host "3. Check if device ID 'b827ebfffe7fec6b' is correct" -ForegroundColor White
        Write-Host "4. Test manual GPS registration with diagnostic flow" -ForegroundColor White
    } else {
        Write-Host "🚨 CRITICAL ISSUE:" -ForegroundColor Red
        Write-Host "Cannot connect to MQTT broker on $IP:1883" -ForegroundColor Red
        Write-Host "Check Cerbo GX network settings and MQTT service" -ForegroundColor Red
    }
}

# Execute based on command
switch ($Command.ToLower()) {
    "test_all" { Start-GPSDiagnostics -IP $CerboIP }
    "mqtt" { Test-MQTTBroker -IP $CerboIP }
    "web" { Test-VenusOSWeb -IP $CerboIP }
    "ssh" { Test-SSHConnectivity -IP $CerboIP }
    "commands" { Get-MQTTDiagnosticCommands -IP $CerboIP }
    "flow" { Create-MQTTDiagnosticFlow -IP $CerboIP }
    default { 
        Write-Host "Usage: .\Test-VenusOSGPS.ps1 -Command [test_all|mqtt|web|ssh|commands|flow]" -ForegroundColor Yellow
        Write-Host "Default: test_all" -ForegroundColor White
    }
}
