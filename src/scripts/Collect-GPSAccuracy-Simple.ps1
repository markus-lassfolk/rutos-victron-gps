# GPS Accuracy Data Collector - Alternative Version
# ==================================================
# Works without grpcurl by using alternative Starlink methods

param(
    [int]$Duration = 600,   # Default: 10 minutes for testing
    [int]$Interval = 30,    # Interval between readings in seconds
    [string]$StarlinkIP = "192.168.100.1",
    [string]$RutosIP = "192.168.80.1",
    [string]$RutosUser = "admin",
    [string]$RutosPass = "YOUR_RUTOS_PASSWORD_HERE",  # TODO: Replace with your actual RUTOS password
    [string]$LogFile = "gps-accuracy-data.json"
)

Write-Host "GPS Accuracy Data Collector (Alternative)" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host "Duration: $Duration seconds ($([math]::Round($Duration/60, 1)) minutes)" -ForegroundColor Yellow
Write-Host "Interval: $Interval seconds" -ForegroundColor Yellow
Write-Host ""

# Initialize data collection arrays
$starlinkData = @()
$rutosData = @()

# Function to get Starlink GPS data via web interface
function Get-StarlinkGPS {
    try {
        # Try web interface method first
        $webResponse = Invoke-RestMethod -Uri "http://${StarlinkIP}/api/status" -Method GET -TimeoutSec 5 -ErrorAction SilentlyContinue
        
        if ($webResponse -and $webResponse.location) {
            $loc = $webResponse.location
            if ($loc.lat -and $loc.lon) {
                return @{
                    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    source = "starlink"
                    lat = [double]$loc.lat
                    lon = [double]$loc.lon
                    alt = if ($loc.alt) { [double]$loc.alt } else { 0 }
                    accuracy = if ($loc.accuracy) { [double]$loc.accuracy } else { 10 }
                    fix = 1
                    method = "web_api"
                }
            }
        }
        
        # Try alternative gRPC method if available
        $grpcurlPath = Get-Command grpcurl -ErrorAction SilentlyContinue
        if ($grpcurlPath) {
            $grpcCommand = '{"get_status":{}}'
            $result = & grpcurl -plaintext -d $grpcCommand "${StarlinkIP}:9200" SpaceX.API.Device.Device/Handle 2>$null
            
            if ($result) {
                $data = $result | ConvertFrom-Json
                # Parse gRPC response for location data
                # Note: Structure may vary, this is a placeholder
                if ($data.dishGetStatus) {
                    return @{
                        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                        source = "starlink"
                        lat = 0  # Placeholder - actual parsing needed
                        lon = 0  # Placeholder - actual parsing needed
                        alt = 0
                        accuracy = 10
                        fix = 0
                        method = "grpc_status"
                    }
                }
            }
        }
        
        Write-Host "  Starlink: No location data available" -ForegroundColor Yellow
        return $null
    }
    catch {
        Write-Host "  Starlink error: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function to get RUTOS GPS data (improved error handling)
function Get-RutosGPS {
    try {
        # Login to RUTOS
        $loginBody = @{
            username = $RutosUser
            password = $RutosPass
        } | ConvertTo-Json

        # Handle different PowerShell versions
        $loginParams = @{
            Uri = "https://${RutosIP}/api/login"
            Method = "POST"
            Body = $loginBody
            ContentType = "application/json"
            TimeoutSec = 10
        }
        
        # For PowerShell 6+ try SkipCertificateCheck
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $loginParams.SkipCertificateCheck = $true
        } else {
            # For Windows PowerShell 5.1, ignore SSL errors
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
            # Also try TLS 1.2
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        }
        
        $loginResponse = Invoke-RestMethod @loginParams

        if ($loginResponse.data.token) {
            $headers = @{
                Authorization = "Bearer $($loginResponse.data.token)"
            }

            # Get GPS data
            $gpsParams = @{
                Uri = "https://${RutosIP}/api/gps/position/status"
                Method = "GET"
                Headers = $headers
                TimeoutSec = 10
            }
            
            if ($PSVersionTable.PSVersion.Major -ge 6) {
                $gpsParams.SkipCertificateCheck = $true
            }
            
            $gpsResponse = Invoke-RestMethod @gpsParams

            if ($gpsResponse.data) {
                $data = $gpsResponse.data
                return @{
                    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    source = "rutos"
                    lat = [double]$data.latitude
                    lon = [double]$data.longitude
                    alt = [double]$data.altitude
                    accuracy = if ($data.accuracy) { [double]$data.accuracy } else { $null }
                    fix = [int]$data.fix_status
                    satellites = if ($data.satellites) { [int]$data.satellites } else { $null }
                    speed = if ($data.speed) { [double]$data.speed } else { $null }
                    raw = $data
                }
            }
        }
    }
    catch {
        Write-Host "  RUTOS error: $($_.Exception.Message)" -ForegroundColor Red
    }
    return $null
}

# Function to display statistics
function Show-Statistics {
    param([array]$Data, [string]$Source)
    
    if ($Data.Count -eq 0) {
        Write-Host "No data collected for $Source" -ForegroundColor Yellow
        return
    }

    $accuracies = $Data | Where-Object { $null -ne $_.accuracy } | ForEach-Object { $_.accuracy }
    
    if ($accuracies.Count -eq 0) {
        Write-Host "No accuracy data for $Source" -ForegroundColor Yellow
        return
    }

    $avg = ($accuracies | Measure-Object -Average).Average
    $min = ($accuracies | Measure-Object -Minimum).Minimum  
    $max = ($accuracies | Measure-Object -Maximum).Maximum
    $count = $accuracies.Count
    
    $recommended = [math]::Ceiling($avg * 1.5)

    Write-Host ""
    Write-Host "=== $Source GPS Statistics ===" -ForegroundColor Cyan
    Write-Host "Readings: $count" -ForegroundColor White
    Write-Host "Average accuracy: $($avg.ToString('F2')) meters" -ForegroundColor White
    Write-Host "Min accuracy: $($min.ToString('F2')) meters" -ForegroundColor Green
    Write-Host "Max accuracy: $($max.ToString('F2')) meters" -ForegroundColor Red
    Write-Host "Recommended threshold: $recommended meters" -ForegroundColor Magenta
}

# Main collection loop
$startTime = Get-Date
$endTime = $startTime.AddSeconds($Duration)
$readingCount = 0

Write-Host "Starting data collection..." -ForegroundColor Green
Write-Host "PowerShell version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
Write-Host "Will collect until: $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Yellow
Write-Host "Press Ctrl+C to stop early and see results" -ForegroundColor Yellow
Write-Host ""

try {
    while ((Get-Date) -lt $endTime) {
        $readingCount++
        $currentTime = Get-Date -Format "HH:mm:ss"
        
        Write-Host "[$currentTime] Reading #$readingCount" -ForegroundColor Gray
        
        # Collect RUTOS data first (more reliable)
        $rutosReading = Get-RutosGPS
        if ($rutosReading) {
            $rutosData += $rutosReading
            Write-Host "  RUTOS: $($rutosReading.lat.ToString('F6')), $($rutosReading.lon.ToString('F6')) (±$($rutosReading.accuracy)m) [$($rutosReading.satellites) sats]" -ForegroundColor Green
        } else {
            Write-Host "  RUTOS: No data" -ForegroundColor Red
        }
        
        # Collect Starlink data
        $starlinkReading = Get-StarlinkGPS
        if ($starlinkReading) {
            $starlinkData += $starlinkReading
            Write-Host "  Starlink: $($starlinkReading.lat.ToString('F6')), $($starlinkReading.lon.ToString('F6')) (±$($starlinkReading.accuracy)m)" -ForegroundColor Blue
        } else {
            Write-Host "  Starlink: No data" -ForegroundColor Red
        }
        
        # Wait for next reading
        if ((Get-Date) -lt $endTime) {
            Start-Sleep -Seconds $Interval
        }
    }
}
catch {
    Write-Host ""
    Write-Host "Collection stopped by user" -ForegroundColor Yellow
}

# Show results
Write-Host ""
Write-Host "Data Collection Complete!" -ForegroundColor Green
Write-Host "=========================" -ForegroundColor Green

Show-Statistics -Data $rutosData -Source "RUTOS"
Show-Statistics -Data $starlinkData -Source "STARLINK"

# Generate recommendations
Write-Host ""
Write-Host "Recommended GPS Settings:" -ForegroundColor Magenta
Write-Host "========================" -ForegroundColor Magenta

if ($rutosData.Count -gt 0) {
    $rutosAccuracies = $rutosData | Where-Object { $null -ne $_.accuracy } | ForEach-Object { $_.accuracy }
    if ($rutosAccuracies.Count -gt 0) {
        $rutosAvg = ($rutosAccuracies | Measure-Object -Average).Average
        $rutosThreshold = [math]::Ceiling($rutosAvg * 1.5)
        Write-Host "rutos_accuracy: $rutosThreshold" -ForegroundColor Green
    }
}

if ($starlinkData.Count -gt 0) {
    $starlinkAccuracies = $starlinkData | Where-Object { $null -ne $_.accuracy } | ForEach-Object { $_.accuracy }
    if ($starlinkAccuracies.Count -gt 0) {
        $starlinkAvg = ($starlinkAccuracies | Measure-Object -Average).Average
        $starlinkThreshold = [math]::Ceiling($starlinkAvg * 1.5)
        Write-Host "starlink_accuracy: $starlinkThreshold" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Troubleshooting:" -ForegroundColor Yellow
Write-Host "- For Starlink: Install grpcurl for better data collection" -ForegroundColor Yellow
Write-Host "- For RUTOS: Check IP address and credentials" -ForegroundColor Yellow
Write-Host "- Run with administrator privileges if needed" -ForegroundColor Yellow
