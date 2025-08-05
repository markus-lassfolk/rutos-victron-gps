# GPS Accuracy Data Collector (PowerShell)
# =========================================
# Collects GPS data directly from Starlink and RUTOS APIs for accuracy analysis

param(
    [int]$Duration = 3600,  # Duration in seconds (default: 1 hour)
    [int]$Interval = 30,    # Interval between readings in seconds
    [string]$StarlinkIP = "192.168.100.1",
    [string]$RutosIP = "192.168.80.1",
    [string]$RutosUser = "admin",
    [string]$RutosPass = "YOUR_RUTOS_PASSWORD_HERE",  # TODO: Replace with your actual RUTOS password
    [string]$LogFile = "gps-accuracy-data.csv"
)

Write-Host "GPS Accuracy Data Collector" -ForegroundColor Green
Write-Host "===========================" -ForegroundColor Green
Write-Host "Duration: $Duration seconds ($([math]::Round($Duration/60, 1)) minutes)" -ForegroundColor Yellow
Write-Host "Interval: $Interval seconds" -ForegroundColor Yellow
Write-Host "Log file: $LogFile" -ForegroundColor Yellow
Write-Host ""

# Initialize data collection arrays
$starlinkData = @()
$rutosData = @()
$combinedData = @()

# Function to get Starlink GPS data
function Get-StarlinkGPS {
    try {
        # Check if grpcurl is available
        $grpcurlPath = Get-Command grpcurl -ErrorAction SilentlyContinue
        if (-not $grpcurlPath) {
            Write-Host "  grpcurl not found - install from https://github.com/fullstorydev/grpcurl/releases" -ForegroundColor Yellow
            return $null
        }

        Write-Host "  Querying Starlink APIs..." -ForegroundColor Gray
        
        # Collect data from multiple Starlink API endpoints
        $locationData = $null
        $statusData = $null
        $diagnosticsData = $null
        
        # 1. Get location data (primary GPS coordinates)
        try {
            $locationCommand = '{"get_location":{}}'
            $locationResult = & grpcurl -plaintext -emit-defaults -d $locationCommand "${StarlinkIP}:9200" SpaceX.API.Device.Device/Handle 2>&1
            if ($LASTEXITCODE -eq 0 -and $locationResult) {
                $locationData = $locationResult | ConvertFrom-Json
            }
        } catch {
            Write-Host "    Location API failed: $($_.Exception.Message)" -ForegroundColor Gray
        }
        
        # 2. Get status data (GPS stats, signal quality)
        try {
            $statusCommand = '{"get_status":{}}'
            $statusResult = & grpcurl -plaintext -emit-defaults -d $statusCommand "${StarlinkIP}:9200" SpaceX.API.Device.Device/Handle 2>&1
            if ($LASTEXITCODE -eq 0 -and $statusResult) {
                $statusData = $statusResult | ConvertFrom-Json
            }
        } catch {
            Write-Host "    Status API failed: $($_.Exception.Message)" -ForegroundColor Gray
        }
        
        # 3. Get diagnostics data (backup location + accuracy info)
        try {
            $diagnosticsCommand = '{"get_diagnostics":{}}'
            $diagnosticsResult = & grpcurl -plaintext -emit-defaults -d $diagnosticsCommand "${StarlinkIP}:9200" SpaceX.API.Device.Device/Handle 2>&1
            if ($LASTEXITCODE -eq 0 -and $diagnosticsResult) {
                $diagnosticsData = $diagnosticsResult | ConvertFrom-Json
            }
        } catch {
            Write-Host "    Diagnostics API failed: $($_.Exception.Message)" -ForegroundColor Gray
        }
        
        # Process and combine the data
        $location = $null
        $gpsStats = $null
        $diagnosticsLocation = $null
        
        # Extract location from get_location (most accurate)
        if ($locationData -and $locationData.getLocation -and $locationData.getLocation.lla) {
            $location = $locationData.getLocation.lla
        }
        
        # Extract GPS stats from get_status
        if ($statusData -and $statusData.dishGetStatus) {
            $gpsStats = $statusData.dishGetStatus.gpsStats
        }
        
        # Extract diagnostics location (fallback)
        if ($diagnosticsData -and $diagnosticsData.dishGetDiagnostics -and $diagnosticsData.dishGetDiagnostics.location) {
            $diagnosticsLocation = $diagnosticsData.dishGetDiagnostics.location
        }
        
        # Determine best location source
        $bestLocation = $location
        if (-not $bestLocation -and $diagnosticsLocation) {
            $bestLocation = $diagnosticsLocation
        }
        
        if ($bestLocation -and ($null -ne $bestLocation.lat -or $null -ne $bestLocation.latitude)) {
            # Use location API format first, fall back to diagnostics format
            $lat = if ($null -ne $bestLocation.lat) { $bestLocation.lat } else { $bestLocation.latitude }
            $lon = if ($null -ne $bestLocation.lon) { $bestLocation.lon } else { $bestLocation.longitude }
            $alt = if ($null -ne $bestLocation.alt) { $bestLocation.alt } else { $bestLocation.altitudeMeters }
            
            # Determine GPS validity and accuracy
            $gpsValid = if ($gpsStats -and $null -ne $gpsStats.gpsValid) { $gpsStats.gpsValid } else { $true }
            $gpsSats = if ($gpsStats -and $null -ne $gpsStats.gpsSats) { $gpsStats.gpsSats } else { $null }
            
            # Calculate accuracy based on available data
            $accuracy = 10.0  # Default fallback
            if ($diagnosticsLocation -and $diagnosticsLocation.uncertaintyMetersValid -and $diagnosticsLocation.uncertaintyMeters) {
                $accuracy = [double]$diagnosticsLocation.uncertaintyMeters
            } elseif ($gpsValid -and $gpsSats) {
                # Estimate accuracy based on satellite count (rough approximation)
                if ($gpsSats -ge 8) { $accuracy = 3.0 }
                elseif ($gpsSats -ge 6) { $accuracy = 5.0 }
                elseif ($gpsSats -ge 4) { $accuracy = 10.0 }
                else { $accuracy = 20.0 }
            }
            
            return @{
                timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                source = "starlink"
                lat = [double]$lat
                lon = [double]$lon
                alt = if ($null -ne $alt) { [double]$alt } else { $null }
                accuracy = $accuracy
                fix = if ($gpsValid) { 1 } else { 0 }
                speed = if ($diagnosticsLocation -and $null -ne $diagnosticsLocation.speedMetersPerSecond) { [double]$diagnosticsLocation.speedMetersPerSecond } else { $null }
                heading = if ($diagnosticsLocation -and $null -ne $diagnosticsLocation.headingDegrees) { [double]$diagnosticsLocation.headingDegrees } else { $null }
                satellites = if ($null -ne $gpsSats) { [int]$gpsSats } else { $null }
                hdop = if ($diagnosticsLocation -and $null -ne $diagnosticsLocation.hdop) { [double]$diagnosticsLocation.hdop } else { $null }
                vdop = if ($diagnosticsLocation -and $null -ne $diagnosticsLocation.vdop) { [double]$diagnosticsLocation.vdop } else { $null }
                time_of_week = if ($diagnosticsLocation -and $null -ne $diagnosticsLocation.timeOfWeek) { [double]$diagnosticsLocation.timeOfWeek } else { $null }
                # Enhanced Starlink-specific fields
                gps_valid = if ($null -ne $gpsValid) { $gpsValid } else { $null }
                no_sats_after_ttff = if ($gpsStats -and $null -ne $gpsStats.noSatsAfterTtff) { [int]$gpsStats.noSatsAfterTtff } else { $null }
                inhibit_gps = if ($gpsStats -and $null -ne $gpsStats.inhibitGps) { $gpsStats.inhibitGps } else { $null }
                snr = if ($statusData -and $statusData.dishGetStatus -and $null -ne $statusData.dishGetStatus.snr) { [double]$statusData.dishGetStatus.snr } else { $null }
                obstruction_fraction = if ($statusData -and $statusData.dishGetStatus -and $statusData.dishGetStatus.obstructionStats -and $null -ne $statusData.dishGetStatus.obstructionStats.fractionObstructed) { [double]$statusData.dishGetStatus.obstructionStats.fractionObstructed } else { $null }
                ping_latency_ms = if ($statusData -and $statusData.dishGetStatus -and $null -ne $statusData.dishGetStatus.popPingLatencyMs) { [double]$statusData.dishGetStatus.popPingLatencyMs } else { $null }
                location_source = if ($location) { "get_location" } else { "get_diagnostics" }
                raw = @{
                    location = $locationData
                    status = $statusData
                    diagnostics = $diagnosticsData
                }
            }
        } else {
            Write-Host "  Starlink: No location data in any API response" -ForegroundColor Yellow
            return $null
        }
    }
    catch {
        Write-Host "  Starlink error: $($_.Exception.Message)" -ForegroundColor Red
    }
    return $null
}

# Function to get RUTOS GPS data
function Get-RutosGPS {
    try {
        # Login to RUTOS
        $loginBody = @{
            username = $RutosUser
            password = $RutosPass
        } | ConvertTo-Json

        # Handle certificate check based on PowerShell version
        $requestParams = @{
            Uri = "https://${RutosIP}/api/login"
            Method = "POST"
            Body = $loginBody
            ContentType = "application/json"
        }
        
        # Try to add SkipCertificateCheck if available (PowerShell 6+)
        try {
            $requestParams.SkipCertificateCheck = $true
            $loginResponse = Invoke-RestMethod @requestParams
        }
        catch {
            # Fallback for older PowerShell versions - ignore certificate errors
            if ($_.Exception.Message -match "SkipCertificateCheck") {
                # For Windows PowerShell 5.1, ignore SSL certificate errors
                [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
                $requestParams.Remove('SkipCertificateCheck')
                $loginResponse = Invoke-RestMethod @requestParams
            } else {
                throw
            }
        }

        if ($loginResponse.data.token) {
            $headers = @{
                Authorization = "Bearer $($loginResponse.data.token)"
            }

            # Get GPS data with same certificate handling
            $gpsParams = @{
                Uri = "https://${RutosIP}/api/gps/position/status"
                Method = "GET"
                Headers = $headers
            }
            
            try {
                $gpsParams.SkipCertificateCheck = $true
                $gpsResponse = Invoke-RestMethod @gpsParams
            }
            catch {
                if ($_.Exception.Message -match "SkipCertificateCheck") {
                    $gpsParams.Remove('SkipCertificateCheck')
                    $gpsResponse = Invoke-RestMethod @gpsParams
                } else {
                    throw
                }
            }

            if ($gpsResponse.data) {
                $data = $gpsResponse.data
                return @{
                    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    source = "rutos"
                    lat = if ($null -ne $data.latitude) { [double]$data.latitude } else { $null }
                    lon = if ($null -ne $data.longitude) { [double]$data.longitude } else { $null }
                    alt = if ($null -ne $data.altitude) { [double]$data.altitude } else { $null }
                    accuracy = if ($null -ne $data.accuracy) { [double]$data.accuracy } else { $null }
                    fix = if ($null -ne $data.fix_status) { [int]$data.fix_status } else { 0 }
                    satellites = if ($null -ne $data.satellites) { [int]$data.satellites } else { $null }
                    speed = if ($null -ne $data.speed) { [double]$data.speed } else { $null }
                    heading = if ($null -ne $data.course) { [double]$data.course } else { $null }
                    hdop = if ($null -ne $data.hdop) { [double]$data.hdop } else { $null }
                    vdop = if ($null -ne $data.vdop) { [double]$data.vdop } else { $null }
                    pdop = if ($null -ne $data.pdop) { [double]$data.pdop } else { $null }
                    signal_strength = if ($null -ne $data.signal_strength) { [double]$data.signal_strength } else { $null }
                    gps_time = if ($data.gps_time) { $data.gps_time } else { $null }
                    raw = $data
                }
            }
        }
    }
    catch {
        Write-Host "RUTOS error: $($_.Exception.Message)" -ForegroundColor Red
    }
    return $null
}

# Function to calculate statistics
function Get-Statistics {
    param([array]$Data, [string]$Source)
    
    if ($Data.Count -eq 0) {
        Write-Host "No data collected for $Source" -ForegroundColor Yellow
        return
    }

    $accuracies = $Data | Where-Object { $null -ne $_.accuracy } | ForEach-Object { $_.accuracy }
    $altitudes = $Data | Where-Object { $null -ne $_.alt } | ForEach-Object { $_.alt }
    $speeds = $Data | Where-Object { $null -ne $_.speed } | ForEach-Object { $_.speed }
    $satellites = $Data | Where-Object { $null -ne $_.satellites } | ForEach-Object { $_.satellites }
    
    if ($accuracies.Count -eq 0) {
        Write-Host "No accuracy data for $Source" -ForegroundColor Yellow
        return
    }

    # Accuracy statistics
    $avg = ($accuracies | Measure-Object -Average).Average
    $min = ($accuracies | Measure-Object -Minimum).Minimum
    $max = ($accuracies | Measure-Object -Maximum).Maximum
    $count = $accuracies.Count
    
    # Calculate moving average (last 10 readings)
    $movingAvg = if ($count -ge 10) {
        ($accuracies[-10..-1] | Measure-Object -Average).Average
    } else {
        ($accuracies | Measure-Object -Average).Average
    }
    
    $recommended = [math]::Ceiling($avg * 1.5)

    Write-Host ""
    Write-Host "=== $Source GPS Statistics ===" -ForegroundColor Cyan
    Write-Host "Readings: $count" -ForegroundColor White
    Write-Host "Average accuracy: $($avg.ToString('F2')) meters" -ForegroundColor White
    Write-Host "Min accuracy: $($min.ToString('F2')) meters" -ForegroundColor Green
    Write-Host "Max accuracy: $($max.ToString('F2')) meters" -ForegroundColor Red
    Write-Host "Moving average (last 10): $($movingAvg.ToString('F2')) meters" -ForegroundColor Yellow
    Write-Host "Recommended threshold: $recommended meters" -ForegroundColor Magenta
    
    # Altitude statistics
    if ($altitudes.Count -gt 0) {
        $altAvg = ($altitudes | Measure-Object -Average).Average
        $altMin = ($altitudes | Measure-Object -Minimum).Minimum
        $altMax = ($altitudes | Measure-Object -Maximum).Maximum
        Write-Host "Altitude range: $($altMin.ToString('F1')) - $($altMax.ToString('F1'))m (avg: $($altAvg.ToString('F1'))m)" -ForegroundColor Cyan
    }
    
    # Speed statistics
    if ($speeds.Count -gt 0) {
        $speedAvg = ($speeds | Measure-Object -Average).Average
        $speedMax = ($speeds | Measure-Object -Maximum).Maximum
        Write-Host "Speed range: 0 - $($speedMax.ToString('F1'))m/s (avg: $($speedAvg.ToString('F1'))m/s)" -ForegroundColor Cyan
    }
    
    # Satellite statistics
    if ($satellites.Count -gt 0) {
        $satAvg = ($satellites | Measure-Object -Average).Average
        $satMin = ($satellites | Measure-Object -Minimum).Minimum
        $satMax = ($satellites | Measure-Object -Maximum).Maximum
        Write-Host "Satellites: $satMin - $satMax (avg: $($satAvg.ToString('F1')))" -ForegroundColor Cyan
    }
    
    # Fix status analysis
    $fixStats = $Data | Group-Object -Property fix | Sort-Object Name
    if ($fixStats.Count -gt 0) {
        $fixInfo = $fixStats | ForEach-Object { "Fix $($_.Name): $($_.Count)" }
        Write-Host "Fix status: $($fixInfo -join ', ')" -ForegroundColor Cyan
    }
    
    # Starlink-specific statistics
    if ($Source -like "*STARLINK*") {
        $snrValues = $Data | Where-Object { $null -ne $_.snr } | ForEach-Object { $_.snr }
        $obstructionValues = $Data | Where-Object { $null -ne $_.obstruction_fraction } | ForEach-Object { $_.obstruction_fraction * 100 }
        $latencyValues = $Data | Where-Object { $null -ne $_.ping_latency_ms } | ForEach-Object { $_.ping_latency_ms }
        
        if ($snrValues.Count -gt 0) {
            $snrAvg = ($snrValues | Measure-Object -Average).Average
            $snrMin = ($snrValues | Measure-Object -Minimum).Minimum
            Write-Host "SNR: $($snrMin.ToString('F1')) - avg $($snrAvg.ToString('F1'))dB" -ForegroundColor Cyan
        }
        
        if ($obstructionValues.Count -gt 0) {
            $obsAvg = ($obstructionValues | Measure-Object -Average).Average
            $obsMax = ($obstructionValues | Measure-Object -Maximum).Maximum
            Write-Host "Obstruction: avg $($obsAvg.ToString('F2'))%, max $($obsMax.ToString('F2'))%" -ForegroundColor Cyan
        }
        
        if ($latencyValues.Count -gt 0) {
            $latAvg = ($latencyValues | Measure-Object -Average).Average
            $latMin = ($latencyValues | Measure-Object -Minimum).Minimum
            Write-Host "Ping latency: $($latMin.ToString('F0')) - avg $($latAvg.ToString('F0'))ms" -ForegroundColor Cyan
        }
        
        # Location source breakdown
        $locationSources = $Data | Where-Object { $_.location_source } | Group-Object -Property location_source
        if ($locationSources.Count -gt 0) {
            $sourceInfo = $locationSources | ForEach-Object { "$($_.Name): $($_.Count)" }
            Write-Host "Location sources: $($sourceInfo -join ', ')" -ForegroundColor Cyan
        }
    }
}

# Function to save single reading to CSV file
function Save-Reading {
    param([hashtable]$Reading)
    
    # Create CSV header if file doesn't exist
    if (-not (Test-Path $LogFile)) {
        $header = "timestamp,source,lat,lon,alt,accuracy,fix,satellites,speed,heading,hdop,vdop,pdop,time_of_week,signal_strength,gps_time,gps_valid,no_sats_after_ttff,inhibit_gps,snr,obstruction_fraction,ping_latency_ms,location_source"
        Add-Content -Path $LogFile -Value $header -Encoding UTF8
        Write-Host "Created new CSV file: $LogFile" -ForegroundColor Green
    }
    
    # Build CSV line with all fields (using empty string for null values)
    $csvLine = "$($Reading.timestamp),$($Reading.source),$($Reading.lat),$($Reading.lon),$($Reading.alt),$($Reading.accuracy),$($Reading.fix),$($Reading.satellites),$($Reading.speed),$($Reading.heading),$($Reading.hdop),$($Reading.vdop),$($Reading.pdop),$($Reading.time_of_week),$($Reading.signal_strength),$($Reading.gps_time),$($Reading.gps_valid),$($Reading.no_sats_after_ttff),$($Reading.inhibit_gps),$($Reading.snr),$($Reading.obstruction_fraction),$($Reading.ping_latency_ms),$($Reading.location_source)"
    Add-Content -Path $LogFile -Value $csvLine -Encoding UTF8
}

# Function to save data to CSV file (batch mode for final statistics)
function Save-Data {
    # Create CSV header if file doesn't exist
    if (-not (Test-Path $LogFile)) {
        $header = "timestamp,source,lat,lon,alt,accuracy,fix,satellites,speed,heading,hdop,vdop,pdop,time_of_week,signal_strength,gps_time,gps_valid,no_sats_after_ttff,inhibit_gps,snr,obstruction_fraction,ping_latency_ms,location_source"
        Add-Content -Path $LogFile -Value $header -Encoding UTF8
        Write-Host "Created new CSV file: $LogFile" -ForegroundColor Green
    }
    
    # Convert each reading to CSV format and append
    $newEntries = 0
    foreach ($reading in $combinedData) {
        # Build CSV line with all fields (using empty string for null values)
        $csvLine = "$($reading.timestamp),$($reading.source),$($reading.lat),$($reading.lon),$($reading.alt),$($reading.accuracy),$($reading.fix),$($reading.satellites),$($reading.speed),$($reading.heading),$($reading.hdop),$($reading.vdop),$($reading.pdop),$($reading.time_of_week),$($reading.signal_strength),$($reading.gps_time),$($reading.gps_valid),$($reading.no_sats_after_ttff),$($reading.inhibit_gps),$($reading.snr),$($reading.obstruction_fraction),$($reading.ping_latency_ms),$($reading.location_source)"
        Add-Content -Path $LogFile -Value $csvLine -Encoding UTF8
        $newEntries++
    }
    
    Write-Host "Added $newEntries new entries to: $LogFile" -ForegroundColor Green
}

# Function to load existing CSV data for statistics
function Load-ExistingData {
    if (Test-Path $LogFile) {
        try {
            $csvData = Import-Csv -Path $LogFile
            $existingStarlink = @()
            $existingRutos = @()
            
            foreach ($row in $csvData) {
                $entry = @{
                    timestamp = $row.timestamp
                    source = $row.source
                    lat = if ($row.lat -and $row.lat -ne "") { [double]$row.lat } else { $null }
                    lon = if ($row.lon -and $row.lon -ne "") { [double]$row.lon } else { $null }
                    alt = if ($row.alt -and $row.alt -ne "") { [double]$row.alt } else { $null }
                    accuracy = if ($row.accuracy -and $row.accuracy -ne "") { [double]$row.accuracy } else { $null }
                    fix = if ($row.fix -and $row.fix -ne "") { [int]$row.fix } else { 0 }
                    satellites = if ($row.satellites -and $row.satellites -ne "") { [int]$row.satellites } else { $null }
                    speed = if ($row.speed -and $row.speed -ne "") { [double]$row.speed } else { $null }
                    heading = if ($row.heading -and $row.heading -ne "") { [double]$row.heading } else { $null }
                    hdop = if ($row.hdop -and $row.hdop -ne "") { [double]$row.hdop } else { $null }
                    vdop = if ($row.vdop -and $row.vdop -ne "") { [double]$row.vdop } else { $null }
                    pdop = if ($row.pdop -and $row.pdop -ne "") { [double]$row.pdop } else { $null }
                }
                
                if ($row.source -eq "starlink") {
                    $existingStarlink += $entry
                } elseif ($row.source -eq "rutos") {
                    $existingRutos += $entry
                }
            }
            
            Write-Host "Loaded existing data: $($existingStarlink.Count) Starlink, $($existingRutos.Count) RUTOS entries" -ForegroundColor Cyan
            return @{
                starlink = $existingStarlink
                rutos = $existingRutos
            }
        }
        catch {
            Write-Host "Warning: Could not load existing CSV data - $($_.Exception.Message)" -ForegroundColor Yellow
            return @{ starlink = @(); rutos = @() }
        }
    }
    return @{ starlink = @(); rutos = @() }
}

# Main collection loop
$startTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$endTime = (Get-Date).AddSeconds($Duration)
$readingCount = 0

# Load existing data for comprehensive statistics
$existingData = Load-ExistingData
$allStarlinkData = $existingData.starlink
$allRutosData = $existingData.rutos

Write-Host "Starting data collection..." -ForegroundColor Green
Write-Host "Will collect data until: $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Yellow
Write-Host "Press Ctrl+C to stop early and see results" -ForegroundColor Yellow
Write-Host ""

try {
    while ((Get-Date) -lt $endTime) {
        $readingCount++
        $currentTime = Get-Date -Format "HH:mm:ss"
        
        Write-Host "[$currentTime] Reading #$readingCount" -ForegroundColor Gray
        
        # Collect Starlink data
        $starlinkReading = Get-StarlinkGPS
        if ($starlinkReading) {
            $starlinkData += $starlinkReading
            $combinedData += $starlinkReading
            $allStarlinkData += $starlinkReading
            
            # Save immediately to CSV
            Save-Reading -Reading $starlinkReading
            
            # Format common fields (aligned)
            $starCoords = "$($starlinkReading.lat.ToString('F6')), $($starlinkReading.lon.ToString('F6'))"
            $starAccuracy = "(±$($starlinkReading.accuracy.ToString('F1'))m)"
            $starAlt = if ($null -ne $starlinkReading.alt) { "Alt:$($starlinkReading.alt.ToString('F1'))m" } else { "Alt:--.-m" }
            $starSats = if ($null -ne $starlinkReading.satellites) { "Sats:$($starlinkReading.satellites)" } else { "Sats:--" }
            
            # Format Starlink-specific extras
            $starExtras = @()
            if ($null -ne $starlinkReading.speed) { $starExtras += "Speed:$($starlinkReading.speed.ToString('F1'))m/s" }
            if ($null -ne $starlinkReading.snr) { $starExtras += "SNR:$($starlinkReading.snr.ToString('F1'))dB" }
            if ($null -ne $starlinkReading.obstruction_fraction) { $starExtras += "Obs:$($($starlinkReading.obstruction_fraction * 100).ToString('F1'))%" }
            if ($null -ne $starlinkReading.ping_latency_ms) { $starExtras += "Ping:$($starlinkReading.ping_latency_ms.ToString('F0'))ms" }
            $starExtraStr = if ($starExtras.Count -gt 0) { " | " + ($starExtras -join " ") } else { "" }
            
            Write-Host "  Starlink: $starCoords $starAccuracy $starAlt $starSats$starExtraStr" -ForegroundColor Blue
        } else {
            Write-Host "  Starlink: No data" -ForegroundColor Red
        }
        
        # Collect RUTOS data  
        $rutosReading = Get-RutosGPS
        if ($rutosReading) {
            $rutosData += $rutosReading
            $combinedData += $rutosReading
            $allRutosData += $rutosReading
            
            # Save immediately to CSV
            Save-Reading -Reading $rutosReading
            
            # Format common fields (aligned with Starlink)
            $rutosCoords = "$($rutosReading.lat.ToString('F6')), $($rutosReading.lon.ToString('F6'))"
            $rutosAccuracy = "(±$($rutosReading.accuracy.ToString('F1'))m)"
            $rutosAlt = if ($null -ne $rutosReading.alt) { "Alt:$($rutosReading.alt.ToString('F1'))m" } else { "Alt:--.-m" }
            $rutosSats = if ($null -ne $rutosReading.satellites) { "Sats:$($rutosReading.satellites)" } else { "Sats:--" }
            
            # Format RUTOS-specific extras
            $rutosExtras = @()
            if ($null -ne $rutosReading.speed) { $rutosExtras += "Speed:$($rutosReading.speed.ToString('F1'))m/s" }
            if ($null -ne $rutosReading.fix) { $rutosExtras += "Fix:$($rutosReading.fix)" }
            if ($null -ne $rutosReading.hdop) { $rutosExtras += "HDOP:$($rutosReading.hdop.ToString('F1'))" }
            if ($null -ne $rutosReading.signal_strength) { $rutosExtras += "Signal:$($rutosReading.signal_strength.ToString('F1'))" }
            $rutosExtraStr = if ($rutosExtras.Count -gt 0) { " | " + ($rutosExtras -join " ") } else { "" }
            
            Write-Host "  RUTOS:    $rutosCoords $rutosAccuracy $rutosAlt $rutosSats$rutosExtraStr" -ForegroundColor Green
        } else {
            Write-Host "  RUTOS:    No data" -ForegroundColor Red
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

# Show final statistics
Write-Host ""
Write-Host "Data Collection Complete!" -ForegroundColor Green
Write-Host "=========================" -ForegroundColor Green

Write-Host ""
Write-Host "=== SESSION STATISTICS ===" -ForegroundColor Yellow
Get-Statistics -Data $starlinkData -Source "STARLINK (This Session)"
Get-Statistics -Data $rutosData -Source "RUTOS (This Session)"

Write-Host ""
Write-Host "=== CUMULATIVE STATISTICS ===" -ForegroundColor Yellow
Get-Statistics -Data $allStarlinkData -Source "STARLINK (All Data)"
Get-Statistics -Data $allRutosData -Source "RUTOS (All Data)"

Write-Host ""
Write-Host "Recommended GPS Settings (Based on All Data):" -ForegroundColor Magenta
Write-Host "=============================================" -ForegroundColor Magenta

if ($allRutosData.Count -gt 0) {
    $rutosAvg = ($allRutosData | Where-Object { $null -ne $_.accuracy } | ForEach-Object { $_.accuracy } | Measure-Object -Average).Average
    $rutosThreshold = [math]::Ceiling($rutosAvg * 1.5)
    Write-Host "rutos_accuracy: $rutosThreshold (based on $($allRutosData.Count) total readings)" -ForegroundColor Green
}

if ($allStarlinkData.Count -gt 0) {
    $starlinkAvg = ($allStarlinkData | Where-Object { $null -ne $_.accuracy } | ForEach-Object { $_.accuracy } | Measure-Object -Average).Average
    $starlinkThreshold = [math]::Ceiling($starlinkAvg * 1.5)
    Write-Host "starlink_accuracy: $starlinkThreshold (based on $($allStarlinkData.Count) total readings)" -ForegroundColor Green
}

Write-Host ""
Write-Host "Run this script periodically to refine your accuracy thresholds!" -ForegroundColor Cyan
