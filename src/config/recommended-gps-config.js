// Optimized GPS Configuration Based on Real Data Analysis (Data-Driven Approach)
// ===============================================================================
// Based on analysis of actual RUTOS and Starlink GPS performance
// RUTOS: 0.4-0.5m accuracy, 0.1m jitter - extremely stable
// Starlink: 5.0m accuracy, 2.5m avg jitter - less stable but acceptable backup
// All thresholds based on observed data patterns, not generic multipliers

// GPS Accuracy Thresholds (Data-Driven)
const rutos_accuracy = 1;           // 2x degradation allowance from observed 0.5m max
const starlink_accuracy = 7;        // Moderate degradation allowance from observed 5.0m

// Position and Movement Thresholds (Data-Driven)
const gps_position_accuracy = 6;    // Max observed difference 5.2m + 1m buffer
const altitude_difference_threshold = 18;  // Observed p95: 15.4m + 3m buffer
const movement_speed_threshold = 2.0;      // Reasonable default for movement detection

// GPS Stability Settings (Data-Driven)
const gps_stability_threshold = 6;   // Max observed jitter 4.7m + 1m buffer, capped at 8m

// Data Collection Settings
const data_collection_interval = 30;    // seconds
const accuracy_check_interval = 300;    // seconds (5 minutes)

// Enhanced Source Selection Logic - Always use the most accurate GPS source available
function selectGPSSource(rutosData, starlinkData) {
    const rutosAvailable = rutosData.accuracy != null;
    const starlinkAvailable = starlinkData.accuracy != null;
    
    // No GPS sources available
    if (!rutosAvailable && !starlinkAvailable) {
        return {
            source: null,
            data: null,
            reason: 'No GPS sources available',
            priority: 5,
            alert: 'GPS_FAILURE'
        };
    }
    
    // Only one source available - use it regardless of accuracy
    if (rutosAvailable && !starlinkAvailable) {
        const alert = rutosData.accuracy > rutos_accuracy ? 'RUTOS_DEGRADED_ONLY_SOURCE' : null;
        return {
            source: 'rutos',
            data: rutosData,
            reason: `RUTOS only source available (${rutosData.accuracy}m)`,
            priority: rutosData.accuracy <= rutos_accuracy ? 1 : 4,
            alert: alert
        };
    }
    
    if (starlinkAvailable && !rutosAvailable) {
        const alert = starlinkData.accuracy > starlink_accuracy ? 'STARLINK_DEGRADED_ONLY_SOURCE' : null;
        return {
            source: 'starlink',
            data: starlinkData,
            reason: `Starlink only source available (${starlinkData.accuracy}m)`,
            priority: starlinkData.accuracy <= starlink_accuracy ? 2 : 4,
            alert: alert
        };
    }
    
    // Both sources available - ALWAYS choose the more accurate one
    const betterSource = rutosData.accuracy <= starlinkData.accuracy ? 'rutos' : 'starlink';
    const betterData = betterSource === 'rutos' ? rutosData : starlinkData;
    const worseData = betterSource === 'rutos' ? starlinkData : rutosData;
    
    // Determine priority and alerts based on accuracy quality
    let priority, alert;
    
    if (betterData.accuracy <= 1.0) {
        // Excellent accuracy - probably RUTOS in normal operation
        priority = 1;
        alert = null;
    } else if (betterData.accuracy <= 8.0) {
        // Good accuracy - could be degraded RUTOS or normal Starlink
        priority = 2;
        alert = rutosData.accuracy > rutos_accuracy && starlinkData.accuracy > starlink_accuracy ? 'BOTH_GPS_DEGRADED' : 
                (rutosData.accuracy > rutos_accuracy ? 'RUTOS_DEGRADED' : null);
    } else {
        // Both sources are quite degraded
        priority = 3;
        alert = 'BOTH_GPS_DEGRADED';
    }
    
    return {
        source: betterSource,
        data: betterData,
        reason: `${betterSource.toUpperCase()} more accurate (${betterData.accuracy}m vs ${worseData.accuracy}m)`,
        priority: priority,
        alert: alert
    };
}

// Position Change Detection (using your observed thresholds)
function isSignificantPositionChange(oldPos, newPos) {
    if (!oldPos || !newPos) return true;
    
    const distance = calculateHaversineDistance(
        oldPos.latitude, oldPos.longitude,
        newPos.latitude, newPos.longitude
    );
    
    const altitudeDiff = Math.abs((newPos.altitude || 0) - (oldPos.altitude || 0));
    
    return distance > gps_position_accuracy || altitudeDiff > altitude_difference_threshold;
}

// GPS Stability Monitoring
function checkGPSStability(recentReadings, source) {
    if (recentReadings.length < 10) return { stable: true, reason: 'Insufficient data' };
    
    // Calculate position spread over recent readings
    const positions = recentReadings.map(r => ({ lat: r.latitude, lon: r.longitude }));
    let maxDistance = 0;
    
    for (let i = 0; i < positions.length - 1; i++) {
        for (let j = i + 1; j < positions.length; j++) {
            const distance = calculateHaversineDistance(
                positions[i].lat, positions[i].lon,
                positions[j].lat, positions[j].lon
            );
            maxDistance = Math.max(maxDistance, distance);
        }
    }
    
    const isStable = maxDistance <= gps_stability_threshold;
    
    return {
        stable: isStable,
        maxSpread: maxDistance,
        reason: isStable 
            ? `${source} stable (${maxDistance.toFixed(1)}m spread ≤ ${gps_stability_threshold}m)`
            : `${source} unstable (${maxDistance.toFixed(1)}m spread > ${gps_stability_threshold}m)`
    };
}

// Haversine distance calculation
function calculateHaversineDistance(lat1, lon1, lat2, lon2) {
    const R = 6371000; // Earth radius in meters
    const φ1 = lat1 * Math.PI / 180;
    const φ2 = lat2 * Math.PI / 180;
    const Δφ = (lat2 - lat1) * Math.PI / 180;
    const Δλ = (lon2 - lon1) * Math.PI / 180;

    const a = Math.sin(Δφ/2) * Math.sin(Δφ/2) +
              Math.cos(φ1) * Math.cos(φ2) *
              Math.sin(Δλ/2) * Math.sin(Δλ/2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));

    return R * c;
}

// Alert handling for GPS scenarios
function handleGPSAlert(alertType, gpsResult, context = {}) {
    const alerts = {
        'RUTOS_DEGRADED': {
            level: 'info',
            message: `RUTOS GPS accuracy degraded to ${gpsResult.data.accuracy}m (normally ≤1m), but still more accurate than Starlink (${context.starlinkAccuracy}m).`,
            action: 'Monitor RUTOS performance, continue using most accurate source'
        },
        'GPS_SOURCE_SWITCHED': {
            level: 'warning',
            message: `GPS source switched to ${gpsResult.source.toUpperCase()} (${gpsResult.data.accuracy}m) as it became more accurate than the alternative (${context.alternativeAccuracy}m).`,
            action: 'Normal operation - using most accurate GPS source'
        },
        'BOTH_GPS_DEGRADED': {
            level: 'error', 
            message: `Both GPS sources degraded (RUTOS: ${context.rutosAccuracy}m, Starlink: ${context.starlinkAccuracy}m). Using best available: ${gpsResult.source.toUpperCase()}.`,
            action: 'Investigate GPS issues, consider reduced operational envelope if accuracy >10m'
        },
        'RUTOS_DEGRADED_ONLY_SOURCE': {
            level: 'warning',
            message: `RUTOS GPS degraded to ${gpsResult.data.accuracy}m (normally ≤1m) and Starlink unavailable.`,
            action: 'Attempt to restore Starlink backup, monitor RUTOS closely'
        },
        'STARLINK_DEGRADED_ONLY_SOURCE': {
            level: 'warning', 
            message: `Starlink GPS degraded to ${gpsResult.data.accuracy}m (normally ≤8m) and RUTOS unavailable.`,
            action: 'Attempt to restore RUTOS primary, monitor Starlink closely'
        },
        'GPS_FAILURE': {
            level: 'critical',
            message: 'Complete GPS failure - no sources available',
            action: 'Emergency protocol: maintain last known position, attempt GPS recovery'
        }
    };
    
    const alert = alerts[alertType];
    if (alert) {
        return {
            timestamp: new Date().toISOString(),
            type: alertType,
            level: alert.level,
            message: alert.message,
            recommendedAction: alert.action,
            gpsState: {
                activeSource: gpsResult.source,
                reason: gpsResult.reason,
                priority: gpsResult.priority
            }
        };
    }
    
    return null;
}

// GPS Source monitoring and switching logic
function monitorGPSSources(rutosData, starlinkData, previousState = {}) {
    const currentResult = selectGPSSource(rutosData, starlinkData);
    const previousSource = previousState.activeSource;
    const switchCount = previousState.switchCount || 0;
    const lastSwitchTime = previousState.lastSwitchTime;
    
    // Detect source switching
    const sourceChanged = previousSource && previousSource !== currentResult.source;
    const newSwitchCount = sourceChanged ? switchCount + 1 : switchCount;
    const currentTime = Date.now();
    
    // Check for excessive switching (instability indicator)
    const timeSinceLastSwitch = lastSwitchTime ? currentTime - lastSwitchTime : Infinity;
    const isFrequentSwitching = sourceChanged && timeSinceLastSwitch < 120000; // 2 minutes
    
    // Generate alerts
    const alerts = [];
    
    if (currentResult.alert) {
        const context = {
            rutosAccuracy: rutosData.accuracy,
            starlinkAccuracy: starlinkData.accuracy
        };
        const alert = handleGPSAlert(currentResult.alert, currentResult, context);
        if (alert) alerts.push(alert);
    }
    
    if (sourceChanged) {
        alerts.push({
            timestamp: new Date().toISOString(),
            type: 'GPS_SOURCE_SWITCH',
            level: isFrequentSwitching ? 'warning' : 'info',
            message: `GPS source switched: ${previousSource} → ${currentResult.source}. Reason: ${currentResult.reason}`,
            recommendedAction: isFrequentSwitching ? 'Investigate GPS instability - frequent switching detected' : 'Normal operation',
            switchCount: newSwitchCount
        });
    }
    
    return {
        gpsResult: currentResult,
        alerts: alerts,
        monitoring: {
            activeSource: currentResult.source,
            switchCount: newSwitchCount,
            lastSwitchTime: sourceChanged ? currentTime : lastSwitchTime,
            isStable: !isFrequentSwitching,
            uptime: {
                rutos: previousState.uptime?.rutos || 0 + (currentResult.source === 'rutos' ? 30 : 0),
                starlink: previousState.uptime?.starlink || 0 + (currentResult.source === 'starlink' ? 30 : 0)
            }
        }
    };
}

// Export configuration for Node-RED
module.exports = {
    rutos_accuracy,
    starlink_accuracy,
    gps_position_accuracy,
    altitude_difference_threshold,
    movement_speed_threshold,
    gps_stability_threshold,
    data_collection_interval,
    accuracy_check_interval,
    selectGPSSource,
    handleGPSAlert,
    monitorGPSSources,
    isSignificantPositionChange,
    checkGPSStability,
    calculateHaversineDistance
};
