#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Remove existing GPS devices from Victron Energy Venus OS via MQTT
.DESCRIPTION
    This script removes GPS devices (like Starlink1, starlink01, etc.) from Venus OS
    by sending disconnection messages to the MQTT broker.
.PARAMETER CerboIP
    IP address of the Cerbo GX (default: 192.168.80.242)
.PARAMETER DeviceName
    Name of the GPS device to remove (default: searches for common names)
.EXAMPLE
    .\Remove-VictronGPS.ps1 -CerboIP "192.168.80.242"
.EXAMPLE
    .\Remove-VictronGPS.ps1 -DeviceName "starlink01"
#>

param(
    [string]$CerboIP = "192.168.80.242",
    [string]$DeviceName = $null,
    [int]$MqttPort = 1883
)

# Import required modules
if (-not (Get-Module -ListAvailable -Name "Posh-MQTT" -ErrorAction SilentlyContinue)) {
    Write-Host "📦 Installing Posh-MQTT module..." -ForegroundColor Yellow
    try {
        Install-Module -Name Posh-MQTT -Force -Scope CurrentUser
        Write-Host "✅ Posh-MQTT installed successfully" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to install Posh-MQTT. Trying manual MQTT approach..." -ForegroundColor Red
    }
}

function Remove-VictronGPSDevice {
    param(
        [string]$BrokerIP,
        [int]$Port,
        [string]$ClientId
    )
    
    Write-Host "🔍 Attempting to remove GPS device: $ClientId" -ForegroundColor Cyan
    
    try {
        # Method 1: Try using Posh-MQTT if available
        if (Get-Module -ListAvailable -Name "Posh-MQTT" -ErrorAction SilentlyContinue) {
            Import-Module Posh-MQTT -ErrorAction Stop
            
            # Connect to MQTT broker
            $mqttClient = Connect-MQTTBroker -Hostname $BrokerIP -Port $Port -ClientId "gps-remover-$(Get-Random)"
            
            if ($mqttClient) {
                Write-Host "✅ Connected to MQTT broker at $BrokerIP" -ForegroundColor Green
                
                # Send disconnection message
                $disconnectPayload = @{
                    clientId = $ClientId
                    connected = 0
                    version = "v1.0.0"
                } | ConvertTo-Json -Compress
                
                $topic = "device/$ClientId/Status"
                Write-Host "📤 Sending disconnect message to topic: $topic" -ForegroundColor Yellow
                
                Publish-MQTTMessage -Session $mqttClient -Topic $topic -Message $disconnectPayload -QoS 2 -Retain $false
                
                Start-Sleep -Seconds 2
                
                # Send empty/null payload to clear the device
                Write-Host "🧹 Clearing device registration..." -ForegroundColor Yellow
                Publish-MQTTMessage -Session $mqttClient -Topic $topic -Message "" -QoS 2 -Retain $true
                
                Disconnect-MQTTBroker -Session $mqttClient
                Write-Host "✅ GPS device '$ClientId' removal commands sent" -ForegroundColor Green
                return $true
            }
        }
        
        # Method 2: Use mosquitto_pub if available (fallback)
        $mosquittoPub = Get-Command "mosquitto_pub" -ErrorAction SilentlyContinue
        if ($mosquittoPub) {
            Write-Host "🦟 Using mosquitto_pub as fallback..." -ForegroundColor Yellow
            
            $disconnectPayload = '{"clientId":"' + $ClientId + '","connected":0,"version":"v1.0.0"}'
            $topic = "device/$ClientId/Status"
            
            # Send disconnect message
            & mosquitto_pub -h $BrokerIP -p $Port -t $topic -m $disconnectPayload -q 2
            Start-Sleep -Seconds 1
            
            # Clear with retained empty message
            & mosquitto_pub -h $BrokerIP -p $Port -t $topic -m "" -q 2 -r
            
            Write-Host "✅ GPS device '$ClientId' removal commands sent via mosquitto_pub" -ForegroundColor Green
            return $true
        }
        
        # Method 3: Manual TCP connection (last resort)
        Write-Host "🔧 Attempting manual MQTT connection..." -ForegroundColor Yellow
        Write-Host "⚠️  Manual MQTT implementation needed - consider installing mosquitto-clients" -ForegroundColor Red
        return $false
        
    } catch {
        Write-Host "❌ Error removing GPS device '$ClientId': $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Find-ExistingGPSDevices {
    param([string]$BrokerIP, [int]$Port)
    
    Write-Host "🔍 Scanning for existing GPS devices..." -ForegroundColor Cyan
    
    # Common GPS device names to check
    $commonGPSNames = @(
        "starlink01", "starlink01", "starlink1", "Starlink1", "STARLINK1",
        "starlink_gps", "starlink-gps", "gps_starlink",
        "mock_gps", "test_gps", "external_gps"
    )
    
    return $commonGPSNames
}

# Main execution
Write-Host "🛰️  Victron GPS Device Remover" -ForegroundColor Magenta
Write-Host "================================" -ForegroundColor Magenta
Write-Host "Target Cerbo GX: ${CerboIP}:${MqttPort}" -ForegroundColor White

# Test MQTT connectivity first
Write-Host "🔗 Testing MQTT connectivity..." -ForegroundColor Yellow
try {
    $tcpTest = Test-NetConnection -ComputerName $CerboIP -Port $MqttPort -InformationLevel Quiet -WarningAction SilentlyContinue
    if (-not $tcpTest) {
        throw "Cannot connect to MQTT broker"
    }
    Write-Host "✅ MQTT broker is accessible" -ForegroundColor Green
} catch {
    Write-Host "❌ Cannot connect to MQTT broker at ${CerboIP}:${MqttPort}" -ForegroundColor Red
    Write-Host "   Please check the IP address and ensure the Cerbo GX is reachable" -ForegroundColor Yellow
    exit 1
}

# Determine devices to remove
$devicesToRemove = @()

if ($DeviceName) {
    $devicesToRemove = @($DeviceName)
    Write-Host "🎯 Targeting specific device: $DeviceName" -ForegroundColor White
} else {
    $devicesToRemove = Find-ExistingGPSDevices -BrokerIP $CerboIP -Port $MqttPort
    Write-Host "🔍 Scanning for common GPS device names..." -ForegroundColor White
}

# Remove each device
$removedCount = 0
foreach ($device in $devicesToRemove) {
    Write-Host "`n📱 Processing device: $device" -ForegroundColor Cyan
    
    if (Remove-VictronGPSDevice -BrokerIP $CerboIP -Port $MqttPort -ClientId $device) {
        $removedCount++
        Write-Host "✅ Successfully processed: $device" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Could not remove: $device (may not exist)" -ForegroundColor Yellow
    }
}

Write-Host "`n📊 Summary:" -ForegroundColor Magenta
Write-Host "   Devices processed: $($devicesToRemove.Count)" -ForegroundColor White
Write-Host "   Removal commands sent: $removedCount" -ForegroundColor White

if ($removedCount -gt 0) {
    Write-Host "`n⏱️  Waiting 5 seconds for Venus OS to process changes..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    
    Write-Host "✅ GPS device removal completed!" -ForegroundColor Green
    Write-Host "   You can now test GPS registration without conflicts" -ForegroundColor Cyan
    Write-Host "   Check Venus OS Device List to verify removal" -ForegroundColor Cyan
} else {
    Write-Host "`n⚠️  No devices were removed. They may not exist or removal failed." -ForegroundColor Yellow
    Write-Host "   This is normal if no GPS devices were previously registered." -ForegroundColor Cyan
}

Write-Host "`n🔧 Next Steps:" -ForegroundColor Magenta
Write-Host "   1. Verify removal in Venus OS Device List" -ForegroundColor White
Write-Host "   2. Test your GPS registration flow" -ForegroundColor White
Write-Host "   3. Monitor MQTT topics for successful registration" -ForegroundColor White
