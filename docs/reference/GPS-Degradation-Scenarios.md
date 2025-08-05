# GPS Source Selection - Always Use Most Accurate Source

Based on your GPS data analysis showing RUTOS typically at 0.4-0.5m accuracy and Starlink at 5.0m, here's the **corrected** GPS source selection logic that always uses the most accurate source available:

## Core Principle: **Most Accurate GPS Wins**

The system should **always** use whichever GPS source is more accurate, regardless of arbitrary thresholds. Don't switch away from a 2m source to use a 5m source just because the 2m source "degraded" from 0.5m!

## Normal Operation (Current State)
- **RUTOS**: 0.5m accuracy ✅
- **Starlink**: 5.0m accuracy 
- **System Choice**: RUTOS (more accurate: 0.5m vs 5.0m)
- **Alert**: None - optimal operation

## Scenario 1: RUTOS Slightly Degraded but Still Better
- **RUTOS**: 2.0m accuracy ⚠️
- **Starlink**: 5.0m accuracy 
- **System Choice**: RUTOS (still more accurate: 2.0m vs 5.0m)
- **Alert**: Info - "RUTOS degraded to 2.0m but still better than Starlink (5.0m)"
- **Action**: Continue with RUTOS, monitor performance

## Scenario 2: RUTOS More Degraded but Still Better
- **RUTOS**: 3.0m accuracy ⚠️
- **Starlink**: 5.0m accuracy 
- **System Choice**: RUTOS (still more accurate: 3.0m vs 5.0m)
- **Alert**: Info - "RUTOS degraded to 3.0m but still better than Starlink (5.0m)"
- **Action**: Continue with RUTOS, investigate degradation cause

## Scenario 3: Starlink Becomes More Accurate (Switch Point)
- **RUTOS**: 8.0m accuracy ⚠️
- **Starlink**: 5.0m accuracy ✅
- **System Choice**: Starlink (now more accurate: 5.0m vs 8.0m)
- **Alert**: Warning - "GPS source switched to Starlink (5.0m) - more accurate than RUTOS (8.0m)"
- **Action**: Normal operation with new best source, investigate RUTOS issues

## Scenario 4: Both Degraded, RUTOS Still Better
- **RUTOS**: 10.0m accuracy ⚠️
- **Starlink**: 15.0m accuracy ⚠️
- **System Choice**: RUTOS (less bad: 10.0m vs 15.0m)
- **Alert**: Error - "Both GPS degraded, using RUTOS (10.0m vs 15.0m)"
- **Action**: GPS system compromised, investigate both sources

## Scenario 5: Both Degraded, Starlink Better
- **RUTOS**: 15.0m accuracy 🚨
- **Starlink**: 10.0m accuracy ⚠️
- **System Choice**: Starlink (less bad: 10.0m vs 15.0m)
- **Alert**: Error - "Both GPS degraded, using Starlink (10.0m vs 15.0m)"
- **Action**: GPS system compromised, prioritize RUTOS recovery

## Scenario 6: One Source Fails
- **RUTOS**: No signal/null 🚨
- **Starlink**: 5.0m accuracy ✅
- **System Choice**: Starlink (only option available)
- **Alert**: Warning - "RUTOS unavailable, using Starlink only (5.0m)"
- **Action**: Attempt RUTOS recovery, single-source operation

## Implementation in Node-RED

### Corrected GPS Source Selection Function
```javascript
function selectGPSSource(rutosData, starlinkData) {
    // Rule: ALWAYS use the most accurate GPS source available
    // Don't arbitrarily switch away from a better source
    
    if (!rutosData.accuracy && !starlinkData.accuracy) {
        return { source: null, reason: 'No GPS sources available' };
    }
    
    // Only one source available - use it
    if (rutosData.accuracy && !starlinkData.accuracy) {
        return { source: 'rutos', data: rutosData };
    }
    if (starlinkData.accuracy && !rutosData.accuracy) {
        return { source: 'starlink', data: starlinkData };
    }
    
    // Both available - choose the more accurate one (simple!)
    const betterSource = rutosData.accuracy <= starlinkData.accuracy ? 'rutos' : 'starlink';
    const betterData = betterSource === 'rutos' ? rutosData : starlinkData;
    const worseAccuracy = betterSource === 'rutos' ? starlinkData.accuracy : rutosData.accuracy;
    
    return {
        source: betterSource,
        data: betterData,
        reason: `${betterSource.toUpperCase()} more accurate (${betterData.accuracy}m vs ${worseAccuracy}m)`
    };
}
```

### Example Scenarios in Practice

**✅ Correct Logic:**
- RUTOS: 2m, Starlink: 5m → Use RUTOS (2m is better than 5m)
- RUTOS: 3m, Starlink: 5m → Use RUTOS (3m is better than 5m)  
- RUTOS: 6m, Starlink: 5m → Use Starlink (5m is better than 6m)

**❌ Wrong Logic (Fixed):**
- ~~RUTOS: 2m, Starlink: 5m → Use Starlink (because RUTOS >1m threshold)~~ 
- ~~This was the flawed logic that would switch to a worse source~~

### Monitoring and Alerting
```javascript
// Track GPS source switches to detect instability
let gpsSourceHistory = [];
let lastGPSSource = null;

function checkGPSHealth(currentSource, accuracy) {
    // Log source changes
    if (lastGPSSource && lastGPSSource !== currentSource) {
        gpsSourceHistory.push({
            timestamp: Date.now(),
            from: lastGPSSource,
            to: currentSource,
            accuracy: accuracy
        });
        
        // Alert if switching too frequently (instability indicator)
        const recentSwitches = gpsSourceHistory.filter(
            s => Date.now() - s.timestamp < 300000 // 5 minutes
        );
        
        if (recentSwitches.length > 3) {
            msg.alert = "GPS_INSTABILITY - Frequent source switching detected";
        }
    }
    
    lastGPSSource = currentSource;
}
```

## Alert Levels and Responses

### 🟢 Normal (No Alerts)
- RUTOS ≤ 1m: System operating optimally
- Action: Continue normal operation

### 🟡 Warning (Degraded but Functional)
- RUTOS > 1m, Starlink ≤ 8m: Backup activated
- Action: Monitor primary source, continue operation

### 🟠 Error (Compromised Operation)
- Both sources degraded: GPS accuracy reduced
- Action: Consider reduced operational envelope

### 🔴 Critical (Emergency Response)
- Complete GPS failure: No position updates
- Action: Emergency protocols, manual navigation

## Recovery Monitoring

The system should continuously monitor for RUTOS recovery:

```javascript
// Check if RUTOS has recovered and can resume primary role
if (currentSource === 'starlink' && rutosData.accuracy <= 1.0) {
    // RUTOS has recovered - switch back to primary
    msg.gpsSwitch = {
        action: 'switch_to_primary',
        reason: `RUTOS recovered (${rutosData.accuracy}m ≤ 1m)`,
        previousSource: 'starlink'
    };
}
```

## Key Takeaways

1. **RUTOS degradation above 1m triggers automatic Starlink backup**
2. **System maintains operation as long as one source is within thresholds**
3. **Alerts escalate based on severity of GPS degradation**
4. **Frequent source switching indicates GPS instability requiring investigation**
5. **Complete GPS failure triggers emergency protocols**

Your current GPS performance shows RUTOS is extremely reliable (0.4-0.5m), so degradation scenarios would be exceptional events requiring investigation of the RUTOS GPS system or environmental factors affecting satellite reception.
