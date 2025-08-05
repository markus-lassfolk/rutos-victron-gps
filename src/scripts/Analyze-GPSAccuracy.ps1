# GPS Accuracy CSV Analyzer (PowerShell)
# ======================================
# Analyzes GPS accuracy data from CSV file collected by Collect-GPSAccuracy.ps1

param(
    [string]$CsvFile = "gps-accuracy-data.csv",
    [string]$Command = "stats",
    [int]$Hours = 24,  # For recent data analysis
    [switch]$ShowCharts
)

Write-Host "GPS Accuracy CSV Analyzer" -ForegroundColor Green
Write-Host "=========================" -ForegroundColor Green
Write-Host ""

# Function to calculate distance between two GPS coordinates using Haversine formula
function Get-DistanceHaversine {
    param(
        [double]$lat1,
        [double]$lon1, 
        [double]$lat2,
        [double]$lon2
    )
    
    # Convert degrees to radians
    $lat1Rad = $lat1 * [math]::PI / 180
    $lon1Rad = $lon1 * [math]::PI / 180
    $lat2Rad = $lat2 * [math]::PI / 180
    $lon2Rad = $lon2 * [math]::PI / 180
    
    # Haversine formula
    $dLat = $lat2Rad - $lat1Rad
    $dLon = $lon2Rad - $lon1Rad
    
    $a = [math]::Sin($dLat/2) * [math]::Sin($dLat/2) + 
         [math]::Cos($lat1Rad) * [math]::Cos($lat2Rad) * 
         [math]::Sin($dLon/2) * [math]::Sin($dLon/2)
    
    $c = 2 * [math]::Atan2([math]::Sqrt($a), [math]::Sqrt(1-$a))
    
    # Earth radius in meters
    $earthRadius = 6371000
    
    return $earthRadius * $c
}

# Function to analyze hourly GPS jitter for each source independently
function Get-HourlyGPSJitter {
    param([hashtable]$Data)
    
    Write-Host "=== HOURLY GPS JITTER ANALYSIS ===" -ForegroundColor Yellow
    Write-Host "==================================" -ForegroundColor Yellow
    Write-Host ""
    
    # Analyze Starlink hourly jitter
    Write-Host "STARLINK HOURLY JITTER:" -ForegroundColor Cyan
    Write-Host "=======================" -ForegroundColor Cyan
    
    $starlinkHourly = $Data.starlink | Where-Object { $null -ne $_.lat -and $null -ne $_.lon } |
                      Group-Object { $_.timestamp.ToString("yyyy-MM-dd HH") } |
                      Sort-Object Name
    
    $starlinkJitter = @()
    foreach ($hourGroup in $starlinkHourly) {
        if ($hourGroup.Count -ge 2) {
            $coords = $hourGroup.Group | ForEach-Object { @{ lat = $_.lat; lon = $_.lon; timestamp = $_.timestamp } }
            
            # Find min/max coordinates in this hour
            $latitudes = $coords | ForEach-Object { $_.lat }
            $longitudes = $coords | ForEach-Object { $_.lon }
            
            $minLat = ($latitudes | Measure-Object -Minimum).Minimum
            $maxLat = ($latitudes | Measure-Object -Maximum).Maximum
            $minLon = ($longitudes | Measure-Object -Minimum).Minimum
            $maxLon = ($longitudes | Measure-Object -Maximum).Maximum
            
            # Calculate jitter distance using Haversine formula
            $jitterDistance = Get-DistanceHaversine -lat1 $minLat -lon1 $minLon -lat2 $maxLat -lon2 $maxLon
            
            $starlinkJitter += @{
                hour = $hourGroup.Name
                readings = $hourGroup.Count
                jitter_meters = $jitterDistance
                lat_range = $maxLat - $minLat
                lon_range = $maxLon - $minLon
                avg_accuracy = if ($hourGroup.Group | Where-Object { $null -ne $_.accuracy }) {
                    ($hourGroup.Group | Where-Object { $null -ne $_.accuracy } | ForEach-Object { $_.accuracy } | Measure-Object -Average).Average
                } else { $null }
            }
        }
    }
    
    if ($starlinkJitter.Count -gt 0) {
        $slJitterStats = $starlinkJitter | ForEach-Object { $_.jitter_meters } | Measure-Object -Average -Minimum -Maximum
        $slJitterSorted = $starlinkJitter | ForEach-Object { $_.jitter_meters } | Sort-Object
        $slJitterP95 = $slJitterSorted[[math]::Floor($slJitterSorted.Count * 0.95)]
        
        Write-Host "Hours analyzed: $($starlinkJitter.Count)" -ForegroundColor White
        Write-Host "Average hourly jitter: $($slJitterStats.Average.ToString('F1'))m" -ForegroundColor White
        Write-Host "Min hourly jitter: $($slJitterStats.Minimum.ToString('F1'))m" -ForegroundColor Green
        Write-Host "Max hourly jitter: $($slJitterStats.Maximum.ToString('F1'))m" -ForegroundColor Red
        Write-Host "95th percentile jitter: $($slJitterP95.ToString('F1'))m" -ForegroundColor Yellow
        
        Write-Host ""
        Write-Host "Worst Starlink Jitter Hours:" -ForegroundColor Red
        $worstStarlink = $starlinkJitter | Sort-Object jitter_meters -Descending | Select-Object -First 3
        foreach ($hour in $worstStarlink) {
            Write-Host "$($hour.hour): $($hour.jitter_meters.ToString('F1'))m jitter ($($hour.readings) readings, avg accuracy: $($hour.avg_accuracy.ToString('F1'))m)" -ForegroundColor Red
        }
    } else {
        Write-Host "Insufficient Starlink data for hourly jitter analysis" -ForegroundColor Yellow
    }
    Write-Host ""
    
    # Analyze RUTOS hourly jitter
    Write-Host "RUTOS HOURLY JITTER:" -ForegroundColor Cyan
    Write-Host "====================" -ForegroundColor Cyan
    
    $rutosHourly = $Data.rutos | Where-Object { $null -ne $_.lat -and $null -ne $_.lon } |
                   Group-Object { $_.timestamp.ToString("yyyy-MM-dd HH") } |
                   Sort-Object Name
    
    $rutosJitter = @()
    foreach ($hourGroup in $rutosHourly) {
        if ($hourGroup.Count -ge 2) {
            $coords = $hourGroup.Group | ForEach-Object { @{ lat = $_.lat; lon = $_.lon; timestamp = $_.timestamp } }
            
            # Find min/max coordinates in this hour
            $latitudes = $coords | ForEach-Object { $_.lat }
            $longitudes = $coords | ForEach-Object { $_.lon }
            
            $minLat = ($latitudes | Measure-Object -Minimum).Minimum
            $maxLat = ($latitudes | Measure-Object -Maximum).Maximum
            $minLon = ($longitudes | Measure-Object -Minimum).Minimum
            $maxLon = ($longitudes | Measure-Object -Maximum).Maximum
            
            # Calculate jitter distance using Haversine formula
            $jitterDistance = Get-DistanceHaversine -lat1 $minLat -lon1 $minLon -lat2 $maxLat -lon2 $maxLon
            
            $rutosJitter += @{
                hour = $hourGroup.Name
                readings = $hourGroup.Count
                jitter_meters = $jitterDistance
                lat_range = $maxLat - $minLat
                lon_range = $maxLon - $minLon
                avg_accuracy = if ($hourGroup.Group | Where-Object { $null -ne $_.accuracy }) {
                    ($hourGroup.Group | Where-Object { $null -ne $_.accuracy } | ForEach-Object { $_.accuracy } | Measure-Object -Average).Average
                } else { $null }
            }
        }
    }
    
    if ($rutosJitter.Count -gt 0) {
        $rtJitterStats = $rutosJitter | ForEach-Object { $_.jitter_meters } | Measure-Object -Average -Minimum -Maximum
        $rtJitterSorted = $rutosJitter | ForEach-Object { $_.jitter_meters } | Sort-Object
        $rtJitterP95 = $rtJitterSorted[[math]::Floor($rtJitterSorted.Count * 0.95)]
        
        Write-Host "Hours analyzed: $($rutosJitter.Count)" -ForegroundColor White
        Write-Host "Average hourly jitter: $($rtJitterStats.Average.ToString('F1'))m" -ForegroundColor White
        Write-Host "Min hourly jitter: $($rtJitterStats.Minimum.ToString('F1'))m" -ForegroundColor Green
        Write-Host "Max hourly jitter: $($rtJitterStats.Maximum.ToString('F1'))m" -ForegroundColor Red
        Write-Host "95th percentile jitter: $($rtJitterP95.ToString('F1'))m" -ForegroundColor Yellow
        
        Write-Host ""
        Write-Host "Worst RUTOS Jitter Hours:" -ForegroundColor Red
        $worstRutos = $rutosJitter | Sort-Object jitter_meters -Descending | Select-Object -First 3
        foreach ($hour in $worstRutos) {
            Write-Host "$($hour.hour): $($hour.jitter_meters.ToString('F1'))m jitter ($($hour.readings) readings, avg accuracy: $($hour.avg_accuracy.ToString('F1'))m)" -ForegroundColor Red
        }
    } else {
        Write-Host "Insufficient RUTOS data for hourly jitter analysis" -ForegroundColor Yellow
    }
    Write-Host ""
    
    # Compare source stability
    if ($starlinkJitter.Count -gt 0 -and $rutosJitter.Count -gt 0) {
        Write-Host "SOURCE STABILITY COMPARISON:" -ForegroundColor Magenta
        Write-Host "============================" -ForegroundColor Magenta
        
        $slAvgJitter = ($starlinkJitter | ForEach-Object { $_.jitter_meters } | Measure-Object -Average).Average
        $rtAvgJitter = ($rutosJitter | ForEach-Object { $_.jitter_meters } | Measure-Object -Average).Average
        
        if ($slAvgJitter -lt $rtAvgJitter) {
            $improvement = (($rtAvgJitter - $slAvgJitter) / $rtAvgJitter * 100)
            Write-Host "Starlink is more stable: $($slAvgJitter.ToString('F1'))m vs $($rtAvgJitter.ToString('F1'))m avg jitter" -ForegroundColor Green
            Write-Host "Starlink has $($improvement.ToString('F1'))% less jitter than RUTOS" -ForegroundColor Green
        } else {
            $improvement = (($slAvgJitter - $rtAvgJitter) / $slAvgJitter * 100)
            Write-Host "RUTOS is more stable: $($rtAvgJitter.ToString('F1'))m vs $($slAvgJitter.ToString('F1'))m avg jitter" -ForegroundColor Green
            Write-Host "RUTOS has $($improvement.ToString('F1'))% less jitter than Starlink" -ForegroundColor Green
        }
        Write-Host ""
    }
    
    # Return jitter analysis for use in recommendations
    return @{
        starlink = @{
            hours = $starlinkJitter.Count
            avgJitter = if ($starlinkJitter.Count -gt 0) { ($starlinkJitter | ForEach-Object { $_.jitter_meters } | Measure-Object -Average).Average } else { $null }
            maxJitter = if ($starlinkJitter.Count -gt 0) { ($starlinkJitter | ForEach-Object { $_.jitter_meters } | Measure-Object -Maximum).Maximum } else { $null }
            p95Jitter = if ($starlinkJitter.Count -gt 0) { $slJitterP95 } else { $null }
        }
        rutos = @{
            hours = $rutosJitter.Count
            avgJitter = if ($rutosJitter.Count -gt 0) { ($rutosJitter | ForEach-Object { $_.jitter_meters } | Measure-Object -Average).Average } else { $null }
            maxJitter = if ($rutosJitter.Count -gt 0) { ($rutosJitter | ForEach-Object { $_.jitter_meters } | Measure-Object -Maximum).Maximum } else { $null }
            p95Jitter = if ($rutosJitter.Count -gt 0) { $rtJitterP95 } else { $null }
        }
    }
}

# Function to analyze Starlink's reported vs actual accuracy using RUTOS as ground truth
function Get-StarlinkAccuracyValidation {
    param([hashtable]$Data)
    
    Write-Host "=== STARLINK ACCURACY VALIDATION (RUTOS as Ground Truth) ===" -ForegroundColor Yellow
    Write-Host "=============================================================" -ForegroundColor Yellow
    Write-Host ""
    
    # Find time-synchronized readings where both sources have accuracy data
    $validReadings = @()
    foreach ($slink in $Data.starlink) {
        if ($null -ne $slink.lat -and $null -ne $slink.lon -and $null -ne $slink.accuracy) {
            $matchingRutos = $Data.rutos | Where-Object { 
                $null -ne $_.lat -and $null -ne $_.lon -and
                [math]::Abs(($_.timestamp - $slink.timestamp).TotalSeconds) -lt 30
            } | Sort-Object { [math]::Abs(($_.timestamp - $slink.timestamp).TotalSeconds) } | Select-Object -First 1
            
            if ($matchingRutos) {
                # Calculate actual distance between Starlink and RUTOS (ground truth)
                $actualDistance = Get-DistanceHaversine -lat1 $slink.lat -lon1 $slink.lon -lat2 $matchingRutos.lat -lon2 $matchingRutos.lon
                
                $validReadings += @{
                    timestamp = $slink.timestamp
                    starlink_reported_accuracy = $slink.accuracy
                    actual_distance_from_rutos = $actualDistance
                    starlink_lat = $slink.lat
                    starlink_lon = $slink.lon
                    rutos_lat = $matchingRutos.lat
                    rutos_lon = $matchingRutos.lon
                    accuracy_ratio = if ($slink.accuracy -gt 0) { $actualDistance / $slink.accuracy } else { $null }
                    time_diff_seconds = [math]::Abs(($matchingRutos.timestamp - $slink.timestamp).TotalSeconds)
                }
            }
        }
    }
    
    if ($validReadings.Count -eq 0) {
        Write-Host "No synchronized readings with accuracy data found" -ForegroundColor Red
        return
    }
    
    Write-Host "STARLINK REPORTED vs ACTUAL ACCURACY:" -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host "Analysis based on $($validReadings.Count) synchronized readings" -ForegroundColor White
    Write-Host ""
    
    # Overall statistics
    $reportedAccuracies = $validReadings | ForEach-Object { $_.starlink_reported_accuracy }
    $actualDistances = $validReadings | ForEach-Object { $_.actual_distance_from_rutos }
    $accuracyRatios = $validReadings | Where-Object { $null -ne $_.accuracy_ratio } | ForEach-Object { $_.accuracy_ratio }
    
    $reportedStats = $reportedAccuracies | Measure-Object -Average -Minimum -Maximum
    $actualStats = $actualDistances | Measure-Object -Average -Minimum -Maximum
    $ratioStats = $accuracyRatios | Measure-Object -Average -Minimum -Maximum
    
    Write-Host "Starlink REPORTED Accuracy:" -ForegroundColor Blue
    Write-Host "  Average: $($reportedStats.Average.ToString('F1'))m" -ForegroundColor White
    Write-Host "  Range: $($reportedStats.Minimum.ToString('F1'))m to $($reportedStats.Maximum.ToString('F1'))m" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Starlink ACTUAL Distance from RUTOS (Ground Truth):" -ForegroundColor Green
    Write-Host "  Average: $($actualStats.Average.ToString('F1'))m" -ForegroundColor White
    Write-Host "  Range: $($actualStats.Minimum.ToString('F1'))m to $($actualStats.Maximum.ToString('F1'))m" -ForegroundColor White
    Write-Host ""
    
    # Calculate percentiles for actual distances
    $actualSorted = $actualDistances | Sort-Object
    $actualP50 = $actualSorted[[math]::Floor($actualDistances.Count * 0.5)]
    $actualP75 = $actualSorted[[math]::Floor($actualDistances.Count * 0.75)]
    $actualP90 = $actualSorted[[math]::Floor($actualDistances.Count * 0.9)]
    $actualP95 = $actualSorted[[math]::Floor($actualDistances.Count * 0.95)]
    
    Write-Host "Actual Distance Percentiles:" -ForegroundColor Green
    Write-Host "  50th percentile: $($actualP50.ToString('F1'))m" -ForegroundColor White
    Write-Host "  75th percentile: $($actualP75.ToString('F1'))m" -ForegroundColor White
    Write-Host "  90th percentile: $($actualP90.ToString('F1'))m" -ForegroundColor White
    Write-Host "  95th percentile: $($actualP95.ToString('F1'))m" -ForegroundColor White
    Write-Host ""
    
    # Accuracy ratio analysis
    Write-Host "ACCURACY VALIDATION ANALYSIS:" -ForegroundColor Magenta
    Write-Host "=============================" -ForegroundColor Magenta
    
    if ($ratioStats.Average -lt 1.0) {
        $percentage = ((1.0 - $ratioStats.Average) * 100)
        Write-Host "✅ Starlink is MORE accurate than reported!" -ForegroundColor Green
        Write-Host "   Actual accuracy is $($percentage.ToString('F0'))% BETTER than reported" -ForegroundColor Green
        Write-Host "   Average ratio: $($ratioStats.Average.ToString('F2')) (< 1.0 = better than reported)" -ForegroundColor Green
    } elseif ($ratioStats.Average -gt 1.2) {
        $percentage = (($ratioStats.Average - 1.0) * 100)
        Write-Host "❌ Starlink is LESS accurate than reported" -ForegroundColor Red
        Write-Host "   Actual accuracy is $($percentage.ToString('F0'))% WORSE than reported" -ForegroundColor Red
        Write-Host "   Average ratio: $($ratioStats.Average.ToString('F2')) (> 1.2 = significantly worse)" -ForegroundColor Red
    } else {
        Write-Host "✅ Starlink accuracy reporting is reasonably accurate" -ForegroundColor Yellow
        Write-Host "   Average ratio: $($ratioStats.Average.ToString('F2')) (close to 1.0)" -ForegroundColor Yellow
    }
    Write-Host ""
    
    # Analyze by reported accuracy ranges
    Write-Host "ANALYSIS BY REPORTED ACCURACY RANGES:" -ForegroundColor Cyan
    Write-Host "====================================" -ForegroundColor Cyan
    
    $highAccuracy = $validReadings | Where-Object { $_.starlink_reported_accuracy -le 3 }
    $mediumAccuracy = $validReadings | Where-Object { $_.starlink_reported_accuracy -gt 3 -and $_.starlink_reported_accuracy -le 8 }
    $lowAccuracy = $validReadings | Where-Object { $_.starlink_reported_accuracy -gt 8 }
    
    if ($highAccuracy.Count -gt 0) {
        $highActual = ($highAccuracy | ForEach-Object { $_.actual_distance_from_rutos } | Measure-Object -Average).Average
        $highReported = ($highAccuracy | ForEach-Object { $_.starlink_reported_accuracy } | Measure-Object -Average).Average
        Write-Host "High Accuracy Reports (≤3m): $($highAccuracy.Count) samples" -ForegroundColor Green
        Write-Host "  Reported: $($highReported.ToString('F1'))m, Actual: $($highActual.ToString('F1'))m" -ForegroundColor White
        Write-Host "  Ratio: $(($highActual/$highReported).ToString('F2'))" -ForegroundColor White
    }
    
    if ($mediumAccuracy.Count -gt 0) {
        $medActual = ($mediumAccuracy | ForEach-Object { $_.actual_distance_from_rutos } | Measure-Object -Average).Average
        $medReported = ($mediumAccuracy | ForEach-Object { $_.starlink_reported_accuracy } | Measure-Object -Average).Average
        Write-Host "Medium Accuracy Reports (3-8m): $($mediumAccuracy.Count) samples" -ForegroundColor Yellow
        Write-Host "  Reported: $($medReported.ToString('F1'))m, Actual: $($medActual.ToString('F1'))m" -ForegroundColor White
        Write-Host "  Ratio: $(($medActual/$medReported).ToString('F2'))" -ForegroundColor White
    }
    
    if ($lowAccuracy.Count -gt 0) {
        $lowActual = ($lowAccuracy | ForEach-Object { $_.actual_distance_from_rutos } | Measure-Object -Average).Average
        $lowReported = ($lowAccuracy | ForEach-Object { $_.starlink_reported_accuracy } | Measure-Object -Average).Average
        Write-Host "Low Accuracy Reports (>8m): $($lowAccuracy.Count) samples" -ForegroundColor Red
        Write-Host "  Reported: $($lowReported.ToString('F1'))m, Actual: $($lowActual.ToString('F1'))m" -ForegroundColor White
        Write-Host "  Ratio: $(($lowActual/$lowReported).ToString('F2'))" -ForegroundColor White
    }
    Write-Host ""
    
    # Show worst and best cases
    Write-Host "EXTREME CASES:" -ForegroundColor Cyan
    Write-Host "==============" -ForegroundColor Cyan
    
    $worstCases = $validReadings | Sort-Object accuracy_ratio -Descending | Select-Object -First 3
    Write-Host "Worst Accuracy Cases (Actual >> Reported):" -ForegroundColor Red
    foreach ($case in $worstCases) {
        $timeStr = $case.timestamp.ToString("yyyy-MM-dd HH:mm:ss")
        Write-Host "$timeStr : Reported $($case.starlink_reported_accuracy)m, Actual $($case.actual_distance_from_rutos.ToString('F1'))m (ratio: $($case.accuracy_ratio.ToString('F2')))" -ForegroundColor Red
    }
    Write-Host ""
    
    $bestCases = $validReadings | Sort-Object accuracy_ratio | Select-Object -First 3
    Write-Host "Best Accuracy Cases (Actual << Reported):" -ForegroundColor Green
    foreach ($case in $bestCases) {
        $timeStr = $case.timestamp.ToString("yyyy-MM-dd HH:mm:ss")
        Write-Host "$timeStr : Reported $($case.starlink_reported_accuracy)m, Actual $($case.actual_distance_from_rutos.ToString('F1'))m (ratio: $($case.accuracy_ratio.ToString('F2')))" -ForegroundColor Green
    }
    Write-Host ""
    
    # Look for fixed/quantized values
    Write-Host "REPORTED ACCURACY VALUE ANALYSIS:" -ForegroundColor Cyan
    Write-Host "=================================" -ForegroundColor Cyan
    
    $uniqueReported = $reportedAccuracies | Group-Object | Sort-Object Name
    Write-Host "Unique reported accuracy values:" -ForegroundColor White
    foreach ($group in $uniqueReported) {
        $avgActual = ($validReadings | Where-Object { $_.starlink_reported_accuracy -eq [double]$group.Name } | 
                     ForEach-Object { $_.actual_distance_from_rutos } | Measure-Object -Average).Average
        Write-Host "  $($group.Name)m: $($group.Count) occurrences, avg actual: $($avgActual.ToString('F1'))m" -ForegroundColor White
    }
    
    if ($uniqueReported.Count -le 5) {
        Write-Host "⚠️  WARNING: Only $($uniqueReported.Count) unique accuracy values detected!" -ForegroundColor Yellow
        Write-Host "   This suggests Starlink may be using fixed/quantized accuracy values" -ForegroundColor Yellow
    } else {
        Write-Host "✅ Good variety of accuracy values ($($uniqueReported.Count) unique)" -ForegroundColor Green
    }
    Write-Host ""
    
    return @{
        totalReadings = $validReadings.Count
        averageReported = $reportedStats.Average
        averageActual = $actualStats.Average
        accuracyRatio = $ratioStats.Average
        isMoreAccurate = $ratioStats.Average -lt 1.0
        improvementPercent = if ($ratioStats.Average -lt 1.0) { (1.0 - $ratioStats.Average) * 100 } else { 0 }
        uniqueAccuracyValues = $uniqueReported.Count
        readings = $validReadings
    }
}

# Function to analyze GPS coordinate jitter and differences
function Get-GPSJitterAnalysis {
    param([hashtable]$Data)
    
    Write-Host "=== GPS COORDINATE JITTER ANALYSIS ===" -ForegroundColor Yellow
    Write-Host "=====================================" -ForegroundColor Yellow
    Write-Host ""
    
    # Find time-synchronized GPS readings (within 30 seconds of each other)
    $syncedReadings = @()
    foreach ($slink in $Data.starlink) {
        if ($null -ne $slink.lat -and $null -ne $slink.lon) {
            $matchingRutos = $Data.rutos | Where-Object { 
                $null -ne $_.lat -and $null -ne $_.lon -and
                [math]::Abs(($_.timestamp - $slink.timestamp).TotalSeconds) -lt 30
            } | Sort-Object { [math]::Abs(($_.timestamp - $slink.timestamp).TotalSeconds) } | Select-Object -First 1
            
            if ($matchingRutos) {
                # Calculate precise distance using Haversine formula
                $distance = Get-DistanceHaversine -lat1 $slink.lat -lon1 $slink.lon -lat2 $matchingRutos.lat -lon2 $matchingRutos.lon
                
                $syncedReadings += @{
                    timestamp = $slink.timestamp
                    starlink_lat = $slink.lat
                    starlink_lon = $slink.lon  
                    starlink_alt = $slink.alt
                    starlink_accuracy = $slink.accuracy
                    rutos_lat = $matchingRutos.lat
                    rutos_lon = $matchingRutos.lon
                    rutos_alt = $matchingRutos.alt
                    rutos_accuracy = $matchingRutos.accuracy
                    distance_meters = $distance
                    time_diff_seconds = [math]::Abs(($matchingRutos.timestamp - $slink.timestamp).TotalSeconds)
                    alt_diff = if ($null -ne $slink.alt -and $null -ne $matchingRutos.alt) { [math]::Abs($slink.alt - $matchingRutos.alt) } else { $null }
                }
            }
        }
    }
    
    if ($syncedReadings.Count -eq 0) {
        Write-Host "No synchronized GPS readings found for comparison" -ForegroundColor Red
        return
    }
    
    # Calculate jitter statistics
    $distances = $syncedReadings | ForEach-Object { $_.distance_meters }
    $altDiffs = $syncedReadings | Where-Object { $null -ne $_.alt_diff } | ForEach-Object { $_.alt_diff }
    
    $distStats = $distances | Measure-Object -Average -Minimum -Maximum
    $distSorted = $distances | Sort-Object
    $distP50 = $distSorted[[math]::Floor($distances.Count * 0.5)]
    $distP75 = $distSorted[[math]::Floor($distances.Count * 0.75)]
    $distP90 = $distSorted[[math]::Floor($distances.Count * 0.9)]
    $distP95 = $distSorted[[math]::Floor($distances.Count * 0.95)]
    
    Write-Host "Position Differences (Haversine Formula):" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Synchronized readings: $($syncedReadings.Count)" -ForegroundColor White
    Write-Host "Average distance difference: $($distStats.Average.ToString('F2'))m" -ForegroundColor White
    Write-Host "Minimum distance difference: $($distStats.Minimum.ToString('F2'))m" -ForegroundColor Green
    Write-Host "Maximum distance difference: $($distStats.Maximum.ToString('F2'))m" -ForegroundColor Red
    Write-Host "Median (50%): $($distP50.ToString('F2'))m" -ForegroundColor Yellow
    Write-Host "75th percentile: $($distP75.ToString('F2'))m" -ForegroundColor Yellow  
    Write-Host "90th percentile: $($distP90.ToString('F2'))m" -ForegroundColor Yellow
    Write-Host "95th percentile: $($distP95.ToString('F2'))m" -ForegroundColor Yellow
    Write-Host ""
    
    if ($altDiffs.Count -gt 0) {
        $altStats = $altDiffs | Measure-Object -Average -Minimum -Maximum
        $altSorted = $altDiffs | Sort-Object
        $altP95 = $altSorted[[math]::Floor($altDiffs.Count * 0.95)]
        
        Write-Host "Altitude Differences:" -ForegroundColor Cyan
        Write-Host "====================" -ForegroundColor Cyan
        Write-Host "Average altitude difference: $($altStats.Average.ToString('F1'))m" -ForegroundColor White
        Write-Host "Min altitude difference: $($altStats.Minimum.ToString('F1'))m" -ForegroundColor Green
        Write-Host "Max altitude difference: $($altStats.Maximum.ToString('F1'))m" -ForegroundColor Red
        Write-Host "95th percentile: $($altP95.ToString('F1'))m" -ForegroundColor Yellow
        Write-Host ""
    }
    
    # Show GPS accuracy correlation with position differences
    Write-Host "GPS Accuracy vs Position Differences:" -ForegroundColor Cyan
    Write-Host "====================================" -ForegroundColor Cyan
    
    # Group readings by combined accuracy ranges
    $highAccuracy = $syncedReadings | Where-Object { $_.starlink_accuracy -le 5 -and $_.rutos_accuracy -le 2 }
    $mediumAccuracy = $syncedReadings | Where-Object { ($_.starlink_accuracy -gt 5 -and $_.starlink_accuracy -le 15) -or ($_.rutos_accuracy -gt 2 -and $_.rutos_accuracy -le 5) }
    $lowAccuracy = $syncedReadings | Where-Object { $_.starlink_accuracy -gt 15 -or $_.rutos_accuracy -gt 5 }
    
    if ($highAccuracy.Count -gt 0) {
        $highAccDist = ($highAccuracy | ForEach-Object { $_.distance_meters } | Measure-Object -Average).Average
        Write-Host "High accuracy readings (Starlink ≤5m, RUTOS ≤2m): $($highAccuracy.Count) samples, avg distance: $($highAccDist.ToString('F2'))m" -ForegroundColor Green
    }
    
    if ($mediumAccuracy.Count -gt 0) {
        $medAccDist = ($mediumAccuracy | ForEach-Object { $_.distance_meters } | Measure-Object -Average).Average
        Write-Host "Medium accuracy readings: $($mediumAccuracy.Count) samples, avg distance: $($medAccDist.ToString('F2'))m" -ForegroundColor Yellow
    }
    
    if ($lowAccuracy.Count -gt 0) {
        $lowAccDist = ($lowAccuracy | ForEach-Object { $_.distance_meters } | Measure-Object -Average).Average
        Write-Host "Low accuracy readings (Starlink >15m or RUTOS >5m): $($lowAccuracy.Count) samples, avg distance: $($lowAccDist.ToString('F2'))m" -ForegroundColor Red
    }
    Write-Host ""
    
    # Show worst jitter cases
    Write-Host "Worst Position Jitter Cases:" -ForegroundColor Cyan
    Write-Host "============================" -ForegroundColor Cyan
    $worstCases = $syncedReadings | Sort-Object distance_meters -Descending | Select-Object -First 5
    
    foreach ($case in $worstCases) {
        $timeStr = $case.timestamp.ToString("yyyy-MM-dd HH:mm:ss")
        Write-Host "$timeStr : $($case.distance_meters.ToString('F1'))m difference" -ForegroundColor Red
        Write-Host "  Starlink: $($case.starlink_lat.ToString('F6')), $($case.starlink_lon.ToString('F6')) (±$($case.starlink_accuracy)m)" -ForegroundColor Blue
        Write-Host "  RUTOS:    $($case.rutos_lat.ToString('F6')), $($case.rutos_lon.ToString('F6')) (±$($case.rutos_accuracy)m)" -ForegroundColor Green
    }
    Write-Host ""
    
    # Return statistics for use in recommendations
    return @{
        syncedCount = $syncedReadings.Count
        avgDistance = $distStats.Average
        maxDistance = $distStats.Maximum
        p95Distance = $distP95
        avgAltDiff = if ($altStats) { $altStats.Average } else { $null }
        p95AltDiff = if ($altP95) { $altP95 } else { $null }
        readings = $syncedReadings
    }
}

# Function to load GPS data from CSV file
function Load-GPSData {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        Write-Host "Error: CSV file not found: $FilePath" -ForegroundColor Red
        Write-Host "Run Collect-GPSAccuracy.ps1 first to collect data." -ForegroundColor Yellow
        return $null
    }
    
    try {
        $csvData = Import-Csv -Path $FilePath
        $starlinkData = @()
        $rutosData = @()
        
        foreach ($row in $csvData) {
            $entry = @{
                timestamp = [DateTime]::Parse($row.timestamp)
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
                $starlinkData += $entry
            } elseif ($row.source -eq "rutos") {
                $rutosData += $entry
            }
        }
        
        Write-Host "Loaded GPS data: $($starlinkData.Count) Starlink, $($rutosData.Count) RUTOS entries" -ForegroundColor Cyan
        Write-Host "Date range: $(($csvData | ForEach-Object { [DateTime]::Parse($_.timestamp) } | Measure-Object -Minimum).Minimum.ToString('yyyy-MM-dd HH:mm')) to $(($csvData | ForEach-Object { [DateTime]::Parse($_.timestamp) } | Measure-Object -Maximum).Maximum.ToString('yyyy-MM-dd HH:mm'))" -ForegroundColor Cyan
        Write-Host ""
        
        return @{
            starlink = $starlinkData
            rutos = $rutosData
            all = $starlinkData + $rutosData
        }
    }
    catch {
        Write-Host "Error loading CSV data: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function to get comprehensive statistics
function Get-ComprehensiveStats {
    param([array]$Data, [string]$Source)
    
    if ($Data.Count -eq 0) {
        Write-Host "No data available for $Source" -ForegroundColor Yellow
        return
    }

    # Filter out null accuracy values
    $validData = $Data | Where-Object { $null -ne $_.accuracy }
    $accuracies = $validData | ForEach-Object { $_.accuracy }
    $altitudes = $Data | Where-Object { $null -ne $_.alt } | ForEach-Object { $_.alt }
    $speeds = $Data | Where-Object { $null -ne $_.speed } | ForEach-Object { $_.speed }
    $satellites = $Data | Where-Object { $null -ne $_.satellites } | ForEach-Object { $_.satellites }
    
    if ($accuracies.Count -eq 0) {
        Write-Host "No accuracy data for $Source" -ForegroundColor Yellow
        return
    }

    # Basic statistics
    $stats = $accuracies | Measure-Object -Average -Minimum -Maximum -Sum
    $count = $accuracies.Count
    
    # Calculate percentiles
    $sortedAccuracies = $accuracies | Sort-Object
    $p50 = $sortedAccuracies[[math]::Floor($count * 0.5)]
    $p75 = $sortedAccuracies[[math]::Floor($count * 0.75)]
    $p90 = $sortedAccuracies[[math]::Floor($count * 0.90)]
    $p95 = $sortedAccuracies[[math]::Floor($count * 0.95)]
    
    # Calculate moving averages
    $movingAvg5 = if ($count -ge 5) { ($accuracies[-5..-1] | Measure-Object -Average).Average } else { $stats.Average }
    $movingAvg10 = if ($count -ge 10) { ($accuracies[-10..-1] | Measure-Object -Average).Average } else { $stats.Average }
    
    # Calculate standard deviation
    $variance = ($accuracies | ForEach-Object { [math]::Pow($_ - $stats.Average, 2) } | Measure-Object -Sum).Sum / $count
    $stdDev = [math]::Sqrt($variance)
    
    # Recommended threshold (average + 1.5 * std dev, but at least 1.5x average)
    $recommendedThreshold = [math]::Ceiling([math]::Max($stats.Average * 1.5, $stats.Average + 1.5 * $stdDev))
    
    Write-Host "=== $Source GPS Statistics ===" -ForegroundColor Cyan
    Write-Host "Readings: $count" -ForegroundColor White
    Write-Host "Average accuracy: $($stats.Average.ToString('F2'))m" -ForegroundColor White
    Write-Host "Std deviation: $($stdDev.ToString('F2'))m" -ForegroundColor White
    Write-Host "Min accuracy: $($stats.Minimum.ToString('F2'))m" -ForegroundColor Green
    Write-Host "Max accuracy: $($stats.Maximum.ToString('F2'))m" -ForegroundColor Red
    Write-Host "Median (50%): $($p50.ToString('F2'))m" -ForegroundColor Yellow
    Write-Host "75th percentile: $($p75.ToString('F2'))m" -ForegroundColor Yellow
    Write-Host "90th percentile: $($p90.ToString('F2'))m" -ForegroundColor Yellow
    Write-Host "95th percentile: $($p95.ToString('F2'))m" -ForegroundColor Yellow
    Write-Host "Moving avg (last 5): $($movingAvg5.ToString('F2'))m" -ForegroundColor Magenta
    Write-Host "Moving avg (last 10): $($movingAvg10.ToString('F2'))m" -ForegroundColor Magenta
    Write-Host "Recommended threshold: ${recommendedThreshold}m" -ForegroundColor Green
    
    # Additional statistics
    if ($altitudes.Count -gt 0) {
        $altStats = $altitudes | Measure-Object -Average -Minimum -Maximum
        Write-Host "Altitude: $($altStats.Minimum.ToString('F1')) - $($altStats.Maximum.ToString('F1'))m (avg: $($altStats.Average.ToString('F1'))m)" -ForegroundColor Cyan
    }
    
    if ($speeds.Count -gt 0) {
        $speedStats = $speeds | Measure-Object -Average -Maximum
        Write-Host "Speed: 0 - $($speedStats.Maximum.ToString('F1'))m/s (avg: $($speedStats.Average.ToString('F1'))m/s)" -ForegroundColor Cyan
    }
    
    if ($satellites.Count -gt 0) {
        $satStats = $satellites | Measure-Object -Average -Minimum -Maximum
        Write-Host "Satellites: $($satStats.Minimum) - $($satStats.Maximum) (avg: $($satStats.Average.ToString('F1')))" -ForegroundColor Cyan
    }
    
    # Fix status breakdown
    $fixStats = $Data | Group-Object -Property fix | Sort-Object Name
    if ($fixStats.Count -gt 0) {
        $fixInfo = $fixStats | ForEach-Object { "Fix $($_.Name): $($_.Count)" }
        Write-Host "Fix status: $($fixInfo -join ', ')" -ForegroundColor Cyan
    }
    
    Write-Host ""
    
    return @{
        count = $count
        average = $stats.Average
        stddev = $stdDev
        recommended = $recommendedThreshold
        p95 = $p95
    }
}

# Function to show recent data analysis
function Show-RecentData {
    param([hashtable]$Data, [int]$Hours)
    
    $cutoffTime = (Get-Date).AddHours(-$Hours)
    
    $recentStarlink = $Data.starlink | Where-Object { $_.timestamp -gt $cutoffTime }
    $recentRutos = $Data.rutos | Where-Object { $_.timestamp -gt $cutoffTime }
    
    Write-Host "=== RECENT DATA (Last $Hours hours) ===" -ForegroundColor Yellow
    Write-Host ""
    
    if ($recentStarlink.Count -gt 0) {
        $starlinkStats = Get-ComprehensiveStats -Data $recentStarlink -Source "STARLINK (Recent)"
    }
    
    if ($recentRutos.Count -gt 0) {
        $rutosStats = Get-ComprehensiveStats -Data $recentRutos -Source "RUTOS (Recent)"
    }
}

# Function to show accuracy trends over time
function Show-AccuracyTrends {
    param([hashtable]$Data)
    
    Write-Host "=== ACCURACY TRENDS ===" -ForegroundColor Yellow
    Write-Host ""
    
    # Group data by hour for trend analysis
    $hourlyStarlink = $Data.starlink | Where-Object { $null -ne $_.accuracy } | 
                      Group-Object { $_.timestamp.ToString("yyyy-MM-dd HH") } | 
                      Sort-Object Name
    
    $hourlyRutos = $Data.rutos | Where-Object { $null -ne $_.accuracy } | 
                   Group-Object { $_.timestamp.ToString("yyyy-MM-dd HH") } | 
                   Sort-Object Name
    
    if ($hourlyStarlink.Count -gt 1 -or $hourlyRutos.Count -gt 1) {
        Write-Host "Hourly Accuracy Averages:" -ForegroundColor Cyan
        Write-Host "========================" -ForegroundColor Cyan
        
        # Show last 12 hours of data
        $recentHours = ($hourlyStarlink + $hourlyRutos | ForEach-Object { $_.Name } | Sort-Object -Unique)[-12..-1]
        
        foreach ($hour in $recentHours) {
            if ($hour) {
                $slinkHour = $hourlyStarlink | Where-Object { $_.Name -eq $hour }
                $rutosHour = $hourlyRutos | Where-Object { $_.Name -eq $hour }
                
                $slinkAvg = if ($slinkHour) { 
                    ($slinkHour.Group | ForEach-Object { $_.accuracy } | Measure-Object -Average).Average.ToString('F1') 
                } else { "---" }
                
                $rutosAvg = if ($rutosHour) { 
                    ($rutosHour.Group | ForEach-Object { $_.accuracy } | Measure-Object -Average).Average.ToString('F1') 
                } else { "---" }
                
                Write-Host "$hour : Starlink ${slinkAvg}m, RUTOS ${rutosAvg}m" -ForegroundColor White
            }
        }
    }
    Write-Host ""
}

# Function to generate comprehensive Node-RED recommendations
function Get-NodeRedRecommendations {
    param([hashtable]$Data)
    
    Write-Host "=== NODE-RED GPS FLOW CONFIGURATION RECOMMENDATIONS ===" -ForegroundColor Magenta
    Write-Host "========================================================" -ForegroundColor Magenta
    Write-Host ""
    
    $starlinkStats = if ($data.starlink.Count -gt 0) { 
        $validStarlink = $data.starlink | Where-Object { $null -ne $_.accuracy }
        if ($validStarlink.Count -gt 0) {
            @{
                count = $validStarlink.Count
                accuracy = ($validStarlink | ForEach-Object { $_.accuracy } | Measure-Object -Average -Maximum).Average
                maxAccuracy = ($validStarlink | ForEach-Object { $_.accuracy } | Measure-Object -Maximum).Maximum
                p95Accuracy = ($validStarlink | ForEach-Object { $_.accuracy } | Sort-Object)[([math]::Floor($validStarlink.Count * 0.95))]
                altitude = if ($validStarlink | Where-Object { $null -ne $_.alt }) { 
                    ($validStarlink | Where-Object { $null -ne $_.alt } | ForEach-Object { $_.alt } | Measure-Object -Average).Average 
                } else { $null }
                speed = if ($validStarlink | Where-Object { $null -ne $_.speed }) { 
                    ($validStarlink | Where-Object { $null -ne $_.speed } | ForEach-Object { $_.speed } | Measure-Object -Average -Maximum)
                } else { $null }
            }
        }
    }
    
    $rutosStats = if ($data.rutos.Count -gt 0) { 
        $validRutos = $data.rutos | Where-Object { $null -ne $_.accuracy }
        if ($validRutos.Count -gt 0) {
            @{
                count = $validRutos.Count
                accuracy = ($validRutos | ForEach-Object { $_.accuracy } | Measure-Object -Average -Maximum).Average
                maxAccuracy = ($validRutos | ForEach-Object { $_.accuracy } | Measure-Object -Maximum).Maximum
                p95Accuracy = ($validRutos | ForEach-Object { $_.accuracy } | Sort-Object)[([math]::Floor($validRutos.Count * 0.95))]
                altitude = if ($validRutos | Where-Object { $null -ne $_.alt }) { 
                    ($validRutos | Where-Object { $null -ne $_.alt } | ForEach-Object { $_.alt } | Measure-Object -Average).Average 
                } else { $null }
                speed = if ($validRutos | Where-Object { $null -ne $_.speed }) { 
                    ($validRutos | Where-Object { $null -ne $_.speed } | ForEach-Object { $_.speed } | Measure-Object -Average -Maximum)
                } else { $null }
            }
        }
    }
    
    # Calculate comparative statistics for position accuracy using Haversine formula
    $jitterAnalysis = Get-GPSJitterAnalysis -Data $data
    
    # Calculate hourly jitter analysis for source stability
    $hourlyJitter = Get-HourlyGPSJitter -Data $data
    
    Write-Host "Based on analysis of your GPS data, here are the recommended settings:" -ForegroundColor Cyan
    Write-Host ""
    
    # Accuracy thresholds - data-driven approach
    Write-Host "ACCURACY THRESHOLDS:" -ForegroundColor Yellow
    Write-Host "===================" -ForegroundColor Yellow
    if ($rutosStats) {
        # RUTOS: Your data shows 0.4-0.5m, so 1m allows for 2x degradation
        $rutosThreshold = if ($rutosStats.p95Accuracy -le 0.6) { 1 } else { [math]::Ceiling($rutosStats.p95Accuracy + 0.5) }
        Write-Host "rutos_accuracy: $rutosThreshold meters" -ForegroundColor Green
        Write-Host "  (Data-driven: observed max $($rutosStats.p95Accuracy.ToString('F1'))m, threshold allows 2x degradation)" -ForegroundColor Gray
    }
    
    if ($starlinkStats) {
        # Starlink: Your data shows consistent 5.0m, so 7m allows for moderate degradation
        $starlinkThreshold = if ($starlinkStats.p95Accuracy -le 5.5) { 7 } else { [math]::Ceiling($starlinkStats.p95Accuracy + 2) }
        Write-Host "starlink_accuracy: $starlinkThreshold meters" -ForegroundColor Green
        Write-Host "  (Data-driven: observed $($starlinkStats.p95Accuracy.ToString('F1'))m, threshold allows moderate degradation)" -ForegroundColor Gray
    }
    Write-Host ""
    
    # Position accuracy threshold using Haversine analysis - data-driven
    Write-Host "POSITION ACCURACY (Haversine Formula):" -ForegroundColor Yellow
    Write-Host "=====================================" -ForegroundColor Yellow
    if ($jitterAnalysis -and $jitterAnalysis.syncedCount -gt 0) {
        # Use max observed + small buffer, typically 6-8m for your data
        $posThreshold = [math]::Min([math]::Ceiling($jitterAnalysis.maxDistance + 1), 8)
        Write-Host "gps_position_accuracy: $posThreshold meters" -ForegroundColor Green
        Write-Host "  (Data-driven: max observed $($jitterAnalysis.maxDistance.ToString('F1'))m + 1m buffer, capped at 8m)" -ForegroundColor Gray
        Write-Host "  (Based on $($jitterAnalysis.syncedCount) synced readings: avg $($jitterAnalysis.avgDistance.ToString('F1'))m, p95 $($jitterAnalysis.p95Distance.ToString('F1'))m)" -ForegroundColor Gray
    } else {
        $posThreshold = 6
        Write-Host "gps_position_accuracy: 6 meters" -ForegroundColor Green
        Write-Host "  (Default based on typical GPS coordinate differences)" -ForegroundColor Gray
    }
    Write-Host ""
    
    # Altitude difference threshold
    Write-Host "ALTITUDE ACCURACY:" -ForegroundColor Yellow
    Write-Host "=================" -ForegroundColor Yellow
    if ($jitterAnalysis -and $jitterAnalysis.avgAltDiff) {
        # Use a more reasonable approach: p95 + small buffer, capped at reasonable maximum
        $altThreshold = [math]::Min([math]::Ceiling($jitterAnalysis.p95AltDiff + 3), 20)
        Write-Host "altitude_difference_threshold: $altThreshold meters" -ForegroundColor Green
        Write-Host "  (Based on 95th percentile: $($jitterAnalysis.p95AltDiff.ToString('F1'))m + 3m buffer, max 20m)" -ForegroundColor Gray
        Write-Host "  (Observed range: avg $($jitterAnalysis.avgAltDiff.ToString('F1'))m, max ~$($jitterAnalysis.p95AltDiff.ToString('F1'))m)" -ForegroundColor Gray
    } else {
        $altThreshold = 20
        Write-Host "altitude_difference_threshold: 20 meters" -ForegroundColor Green
        Write-Host "  (Default - insufficient altitude comparison data)" -ForegroundColor Gray
    }
    Write-Host ""
    
    # Speed thresholds
    Write-Host "MOVEMENT DETECTION:" -ForegroundColor Yellow
    Write-Host "==================" -ForegroundColor Yellow
    $maxObservedSpeed = 0
    $avgObservedSpeed = 0
    
    if ($rutosStats -and $rutosStats.speed) {
        $maxObservedSpeed = [math]::Max($maxObservedSpeed, $rutosStats.speed.Maximum)
        $avgObservedSpeed = [math]::Max($avgObservedSpeed, $rutosStats.speed.Average)
    }
    if ($starlinkStats -and $starlinkStats.speed) {
        $maxObservedSpeed = [math]::Max($maxObservedSpeed, $starlinkStats.speed.Maximum)
        $avgObservedSpeed = [math]::Max($avgObservedSpeed, $starlinkStats.speed.Average)
    }
    
    $movementThreshold = if ($maxObservedSpeed -gt 0) {
        [math]::Max(2.0, $avgObservedSpeed * 1.5)
    } else {
        2.0
    }
    
    Write-Host "movement_speed_threshold: $($movementThreshold.ToString('F1')) m/s" -ForegroundColor Green
    if ($maxObservedSpeed -gt 0) {
        Write-Host "  (Based on observed speeds - max: $($maxObservedSpeed.ToString('F1')) m/s, avg: $($avgObservedSpeed.ToString('F1')) m/s)" -ForegroundColor Gray
    } else {
        Write-Host "  (Default - no speed data observed)" -ForegroundColor Gray
    }
    Write-Host ""
    
    # Data collection intervals
    Write-Host "DATA COLLECTION:" -ForegroundColor Yellow
    Write-Host "================" -ForegroundColor Yellow
    Write-Host "data_collection_interval: 30 seconds" -ForegroundColor Green
    Write-Host "  (Recommended for good balance of accuracy vs. data volume)" -ForegroundColor Gray
    Write-Host "accuracy_check_interval: 300 seconds (5 minutes)" -ForegroundColor Green
    Write-Host "  (Recommended for accuracy monitoring without excessive logging)" -ForegroundColor Gray
    Write-Host ""
    
    # Source priority with hourly jitter consideration
    Write-Host "SOURCE PRIORITY:" -ForegroundColor Yellow
    Write-Host "===============" -ForegroundColor Yellow
    if ($rutosStats -and $starlinkStats) {
        # Consider both accuracy and stability (jitter)
        $rutosJitterFactor = if ($hourlyJitter.rutos.avgJitter) { $hourlyJitter.rutos.avgJitter / 100 } else { 0 }
        $starlinkJitterFactor = if ($hourlyJitter.starlink.avgJitter) { $hourlyJitter.starlink.avgJitter / 100 } else { 0 }
        
        $rutosScore = $rutosStats.accuracy * (1 + $rutosJitterFactor)
        $starlinkScore = $starlinkStats.accuracy * (1 + $starlinkJitterFactor)
        
        if ($rutosScore -lt $starlinkScore) {
            Write-Host "primary_gps_source: RUTOS" -ForegroundColor Green
            Write-Host "secondary_gps_source: Starlink" -ForegroundColor Green
            Write-Host "  (RUTOS combined score: $($rutosScore.ToString('F1')) vs Starlink: $($starlinkScore.ToString('F1')))" -ForegroundColor Gray
            Write-Host "  (Accuracy: RUTOS $($rutosStats.accuracy.ToString('F1'))m, Starlink $($starlinkStats.accuracy.ToString('F1'))m)" -ForegroundColor Gray
            if ($hourlyJitter.rutos.avgJitter -and $hourlyJitter.starlink.avgJitter) {
                Write-Host "  (Hourly jitter: RUTOS $($hourlyJitter.rutos.avgJitter.ToString('F1'))m, Starlink $($hourlyJitter.starlink.avgJitter.ToString('F1'))m)" -ForegroundColor Gray
            }
        } else {
            Write-Host "primary_gps_source: Starlink" -ForegroundColor Green
            Write-Host "secondary_gps_source: RUTOS" -ForegroundColor Green
            Write-Host "  (Starlink combined score: $($starlinkScore.ToString('F1')) vs RUTOS: $($rutosScore.ToString('F1')))" -ForegroundColor Gray
            Write-Host "  (Accuracy: Starlink $($starlinkStats.accuracy.ToString('F1'))m, RUTOS $($rutosStats.accuracy.ToString('F1'))m)" -ForegroundColor Gray
            if ($hourlyJitter.rutos.avgJitter -and $hourlyJitter.starlink.avgJitter) {
                Write-Host "  (Hourly jitter: Starlink $($hourlyJitter.starlink.avgJitter.ToString('F1'))m, RUTOS $($hourlyJitter.rutos.avgJitter.ToString('F1'))m)" -ForegroundColor Gray
            }
        }
    } elseif ($rutosStats) {
        Write-Host "primary_gps_source: RUTOS" -ForegroundColor Green
        Write-Host "secondary_gps_source: Starlink" -ForegroundColor Green
        Write-Host "  (Only RUTOS data available)" -ForegroundColor Gray
    } elseif ($starlinkStats) {
        Write-Host "primary_gps_source: Starlink" -ForegroundColor Green
        Write-Host "secondary_gps_source: RUTOS" -ForegroundColor Green
        Write-Host "  (Only Starlink data available)" -ForegroundColor Gray
    }
    Write-Host ""
    
    # Add GPS stability thresholds based on hourly jitter
    if ($hourlyJitter.starlink.avgJitter -or $hourlyJitter.rutos.avgJitter) {
        Write-Host "GPS STABILITY THRESHOLDS:" -ForegroundColor Yellow
        Write-Host "=========================" -ForegroundColor Yellow
        
        $maxHourlyJitter = 0
        if ($hourlyJitter.starlink.maxJitter) { $maxHourlyJitter = [math]::Max($maxHourlyJitter, $hourlyJitter.starlink.maxJitter) }
        if ($hourlyJitter.rutos.maxJitter) { $maxHourlyJitter = [math]::Max($maxHourlyJitter, $hourlyJitter.rutos.maxJitter) }
        
        # Data-driven stability threshold: max observed + small buffer
        $stabilityThreshold = [math]::Min([math]::Ceiling($maxHourlyJitter + 1), 8)
        Write-Host "gps_stability_threshold: $stabilityThreshold meters" -ForegroundColor Green
        Write-Host "  (Data-driven: worst observed $($maxHourlyJitter.ToString('F1'))m + 1m buffer, capped at 8m)" -ForegroundColor Gray
        Write-Host "  (Use this to detect GPS instability periods)" -ForegroundColor Gray
        Write-Host ""
    }
    
    # Summary configuration block
    Write-Host "COMPLETE NODE-RED CONFIGURATION:" -ForegroundColor Magenta
    Write-Host "================================" -ForegroundColor Magenta
    Write-Host "Copy these values to your Node-RED GPS flow configuration:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "// GPS Accuracy Thresholds" -ForegroundColor Gray
    if ($rutosStats) {
        Write-Host "const rutos_accuracy = $rutosThreshold;" -ForegroundColor White
    }
    if ($starlinkStats) {
        Write-Host "const starlink_accuracy = $starlinkThreshold;" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "// Position and Movement Thresholds" -ForegroundColor Gray
    Write-Host "const gps_position_accuracy = $posThreshold;" -ForegroundColor White
    Write-Host "const altitude_difference_threshold = $altThreshold;" -ForegroundColor White
    Write-Host "const movement_speed_threshold = $($movementThreshold.ToString('F1'));" -ForegroundColor White
    Write-Host "// GPS Stability Settings (based on hourly jitter analysis)" -ForegroundColor Gray
    if ($hourlyJitter.starlink.avgJitter -or $hourlyJitter.rutos.avgJitter) {
        $maxHourlyJitter = 0
        if ($hourlyJitter.starlink.maxJitter) { $maxHourlyJitter = [math]::Max($maxHourlyJitter, $hourlyJitter.starlink.maxJitter) }
        if ($hourlyJitter.rutos.maxJitter) { $maxHourlyJitter = [math]::Max($maxHourlyJitter, $hourlyJitter.rutos.maxJitter) }
        $stabilityThreshold = [math]::Min([math]::Ceiling($maxHourlyJitter + 1), 8)
        Write-Host "const gps_stability_threshold = $stabilityThreshold;" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "// Data Collection Settings" -ForegroundColor Gray
    Write-Host "const data_collection_interval = 30; // seconds" -ForegroundColor White
    Write-Host "const accuracy_check_interval = 300; // seconds" -ForegroundColor White
    Write-Host ""
    
    # GPS Source Selection Logic
    Write-Host "GPS SOURCE SELECTION LOGIC:" -ForegroundColor Yellow
    Write-Host "===========================" -ForegroundColor Yellow
    Write-Host "Based on your data analysis, here's the recommended GPS source selection:" -ForegroundColor Cyan
    Write-Host ""
    
    if ($rutosStats -and $starlinkStats) {
        Write-Host "// Corrected GPS Source Selection Logic - Always Use Most Accurate" -ForegroundColor Gray
        Write-Host "function selectGPSSource(rutosData, starlinkData) {" -ForegroundColor White
        Write-Host "    // Rule: ALWAYS use the most accurate GPS source available" -ForegroundColor Green
        Write-Host "    // Don't arbitrarily switch away from a better source" -ForegroundColor Green
        Write-Host "" -ForegroundColor White
        Write-Host "    if (!rutosData.accuracy && !starlinkData.accuracy) {" -ForegroundColor White
        Write-Host "        return { source: null, reason: 'No GPS sources available' };" -ForegroundColor White
        Write-Host "    }" -ForegroundColor White
        Write-Host "" -ForegroundColor White
        Write-Host "    // Only one source available - use it" -ForegroundColor Yellow
        Write-Host "    if (rutosData.accuracy && !starlinkData.accuracy) return { source: 'rutos', data: rutosData };" -ForegroundColor White
        Write-Host "    if (starlinkData.accuracy && !rutosData.accuracy) return { source: 'starlink', data: starlinkData };" -ForegroundColor White
        Write-Host "" -ForegroundColor White
        Write-Host "    // Both available - choose the more accurate one (simple!)" -ForegroundColor Green
        Write-Host "    const betterSource = rutosData.accuracy <= starlinkData.accuracy ? 'rutos' : 'starlink';" -ForegroundColor White
        Write-Host "    const betterData = betterSource === 'rutos' ? rutosData : starlinkData;" -ForegroundColor White
        Write-Host "    const worseAccuracy = betterSource === 'rutos' ? starlinkData.accuracy : rutosData.accuracy;" -ForegroundColor White
        Write-Host "" -ForegroundColor White
        Write-Host "    return {" -ForegroundColor White
        Write-Host "        source: betterSource," -ForegroundColor White
        Write-Host "        data: betterData," -ForegroundColor White
        Write-Host "        reason: `"betterSource + ' more accurate (' + betterData.accuracy + 'm vs ' + worseAccuracy + 'm)'`"" -ForegroundColor White
        Write-Host "    };" -ForegroundColor White
        Write-Host "}" -ForegroundColor White
        Write-Host ""
        
        Write-Host "SCENARIO EXAMPLES:" -ForegroundColor Yellow
        Write-Host "=================" -ForegroundColor Yellow
        Write-Host "• RUTOS: 0.5m, Starlink: 5.0m → " -NoNewline -ForegroundColor White
        Write-Host "Use RUTOS" -ForegroundColor Green
        Write-Host "  (RUTOS more accurate: 0.5m vs 5.0m)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "• RUTOS: 2.0m, Starlink: 5.0m → " -NoNewline -ForegroundColor White
        Write-Host "Use RUTOS" -ForegroundColor Green
        Write-Host "  (RUTOS still better: 2.0m vs 5.0m - don't switch to worse source!)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "• RUTOS: 8.0m, Starlink: 5.0m → " -NoNewline -ForegroundColor White
        Write-Host "Use Starlink" -ForegroundColor Yellow
        Write-Host "  (Starlink now more accurate: 5.0m vs 8.0m)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "• RUTOS: 15m, Starlink: 12m → " -NoNewline -ForegroundColor White
        Write-Host "Use Starlink" -ForegroundColor Red
        Write-Host "  (Both degraded, Starlink less bad: 12m vs 15m)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "• RUTOS: 3m, Starlink: 15m → " -NoNewline -ForegroundColor White
        Write-Host "Use RUTOS" -ForegroundColor Yellow
        Write-Host "  (RUTOS degraded but still much better: 3m vs 15m)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "• RUTOS: null, Starlink: 5m → " -NoNewline -ForegroundColor White
        Write-Host "Use Starlink" -ForegroundColor Magenta
        Write-Host "  (RUTOS unavailable, use available source)" -ForegroundColor Gray
        Write-Host ""
        
        Write-Host "ALERT CONDITIONS:" -ForegroundColor Red
        Write-Host "=================" -ForegroundColor Red
        Write-Host "ℹ️  Normal operation: Using most accurate source" -ForegroundColor Green
        Write-Host "   → No alerts, optimal GPS performance" -ForegroundColor White
        Write-Host "⚠️  RUTOS degraded but still better than Starlink" -ForegroundColor Yellow
        Write-Host "   → Info alert only - still using best available" -ForegroundColor White
        Write-Host "⚠️  Starlink becomes more accurate than RUTOS" -ForegroundColor Yellow  
        Write-Host "   → GPS source switch alert" -ForegroundColor White
        Write-Host "🚨 Both sources significantly degraded (>10m)" -ForegroundColor Red
        Write-Host "   → GPS accuracy warning - consider reduced operations" -ForegroundColor White
        Write-Host "🚨 No GPS sources available" -ForegroundColor Red
        Write-Host "   → GPS failure alert - emergency protocols" -ForegroundColor White
        Write-Host ""
    }
    
    Write-Host "MONITORING RECOMMENDATIONS:" -ForegroundColor Yellow
    Write-Host "===========================" -ForegroundColor Yellow
    Write-Host "• Log GPS source switches to track system behavior" -ForegroundColor White
    Write-Host "• Alert when RUTOS accuracy degrades above 1m for >5 minutes" -ForegroundColor White
    Write-Host "• Alert when both sources exceed thresholds for >2 minutes" -ForegroundColor White
    Write-Host "• Monitor GPS source switch frequency (too frequent = instability)" -ForegroundColor White
    Write-Host "• Track time spent on each GPS source for performance analysis" -ForegroundColor White
    Write-Host ""
}

# Main execution
$data = Load-GPSData -FilePath $CsvFile
if (-not $data) { exit 1 }

switch ($Command.ToLower()) {
    "stats" {
        Write-Host "=== COMPREHENSIVE GPS STATISTICS ===" -ForegroundColor Yellow
        Write-Host ""
        
        $starlinkStats = if ($data.starlink.Count -gt 0) { Get-ComprehensiveStats -Data $data.starlink -Source "STARLINK" }
        $rutosStats = if ($data.rutos.Count -gt 0) { Get-ComprehensiveStats -Data $data.rutos -Source "RUTOS" }
        
        # Run Starlink accuracy validation using RUTOS as ground truth
        $accuracyValidation = Get-StarlinkAccuracyValidation -Data $data
        
        # Run position jitter analysis
        Get-GPSJitterAnalysis -Data $data
        
        # Run hourly jitter analysis
        $hourlyJitter = Get-HourlyGPSJitter -Data $data
        
        Get-NodeRedRecommendations -Data $data
        Show-AccuracyTrends -Data $data
    }
    
    "recent" {
        Show-RecentData -Data $data -Hours $Hours
    }
    
    "recommend" {
        Get-NodeRedRecommendations -Data $data
    }
    
    "jitter" {
        Get-HourlyGPSJitter -Data $data
        Get-GPSJitterAnalysis -Data $data
    }
    
    "accuracy" {
        Get-StarlinkAccuracyValidation -Data $data
    }
    
    "compare" {
        Compare-GPSSources -Data $data
    }
    
    "trends" {
        Show-AccuracyTrends -Data $data
    }
    
    "summary" {
        Write-Host "=== QUICK SUMMARY ===" -ForegroundColor Yellow
        Write-Host ""
        
        if ($data.starlink.Count -gt 0) {
            $slStats = $data.starlink | Where-Object { $null -ne $_.accuracy } | ForEach-Object { $_.accuracy } | Measure-Object -Average -Count
            Write-Host "Starlink: $($slStats.Count) readings, avg $($slStats.Average.ToString('F1'))m accuracy" -ForegroundColor Blue
        }
        
        if ($data.rutos.Count -gt 0) {
            $rtStats = $data.rutos | Where-Object { $null -ne $_.accuracy } | ForEach-Object { $_.accuracy } | Measure-Object -Average -Count
            Write-Host "RUTOS: $($rtStats.Count) readings, avg $($rtStats.Average.ToString('F1'))m accuracy" -ForegroundColor Green
        }
        
        $totalReadings = $data.all.Count
        $timeSpan = if ($totalReadings -gt 1) {
            $earliest = ($data.all | ForEach-Object { $_.timestamp } | Measure-Object -Minimum).Minimum
            $latest = ($data.all | ForEach-Object { $_.timestamp } | Measure-Object -Maximum).Maximum
            ($latest - $earliest).TotalHours.ToString('F1')
        } else { "0" }
        
        Write-Host "Total: $totalReadings readings over $timeSpan hours" -ForegroundColor Cyan
        Write-Host ""
    }
    
    default {
        Write-Host "Usage: .\Analyze-GPSAccuracy.ps1 -Command <command> [-CsvFile <path>] [-Hours <n>]" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Commands:" -ForegroundColor Cyan
        Write-Host "  stats     - Comprehensive statistics (default)" -ForegroundColor White
        Write-Host "  recent    - Recent data analysis (last N hours)" -ForegroundColor White
        Write-Host "  recommend - Get recommended threshold settings" -ForegroundColor White
        Write-Host "  jitter    - Hourly GPS jitter analysis for each source" -ForegroundColor White
        Write-Host "  accuracy  - Validate Starlink accuracy using RUTOS as ground truth" -ForegroundColor White
        Write-Host "  compare   - Compare GPS sources side-by-side" -ForegroundColor White
        Write-Host "  trends    - Show accuracy trends over time" -ForegroundColor White
        Write-Host "  summary   - Quick data summary" -ForegroundColor White
        Write-Host ""
        Write-Host "Examples:" -ForegroundColor Cyan
        Write-Host "  .\Analyze-GPSAccuracy.ps1 -Command stats" -ForegroundColor Gray
        Write-Host "  .\Analyze-GPSAccuracy.ps1 -Command recent -Hours 6" -ForegroundColor Gray
        Write-Host "  .\Analyze-GPSAccuracy.ps1 -Command recommend" -ForegroundColor Gray
        Write-Host "  .\Analyze-GPSAccuracy.ps1 -Command jitter" -ForegroundColor Gray
        Write-Host "  .\Analyze-GPSAccuracy.ps1 -Command accuracy" -ForegroundColor Gray
        Write-Host "  .\Analyze-GPSAccuracy.ps1 -Command compare" -ForeGroundColor Gray
        Write-Host ""
    }
}
