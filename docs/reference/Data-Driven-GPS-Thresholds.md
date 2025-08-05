# Data-Driven GPS Threshold Configuration

## Overview

Instead of using generic multipliers (like 1.5x, 2.5x), all GPS thresholds are now calculated based on your actual observed GPS performance data. This provides much more realistic and responsive thresholds.

## Your GPS Performance Profile

### RUTOS GPS
- **Typical Accuracy**: 0.4-0.5m
- **95th Percentile**: 0.5m
- **Hourly Jitter**: 0.1m (extremely stable)
- **Assessment**: Excellent primary GPS source

### Starlink GPS  
- **Typical Accuracy**: 5.0m (consistent)
- **95th Percentile**: 5.0m
- **Hourly Jitter**: 2.5m average, up to 4.7m max
- **Assessment**: Good backup GPS source

### GPS Coordinate Differences (Haversine)
- **Average Difference**: 2.65m
- **95th Percentile**: 4.5m
- **Maximum Observed**: 5.2m

### Altitude Differences
- **Average Difference**: 13.1m
- **95th Percentile**: 15.4m
- **Typical Range**: 13-16m

## Data-Driven Thresholds

### 1. RUTOS Accuracy Threshold: **1m**
- **Logic**: Allows 2x degradation from typical 0.5m
- **Old Method**: 0.5m × 1.8 = 0.9m → 1m ✅ (same result)
- **Purpose**: Alert when RUTOS degrades significantly but don't switch to worse source

### 2. Starlink Accuracy Threshold: **7m**  
- **Logic**: Allows moderate degradation from typical 5.0m
- **Old Method**: 5.0m × 1.8 = 9m → **7m** (more responsive)
- **Purpose**: Detect when Starlink backup is degrading

### 3. GPS Position Accuracy: **6m**
- **Logic**: Max observed 5.2m + 1m safety buffer
- **Old Method**: 2.65m × 2.5 = 6.6m → **6m** (more precise)
- **Purpose**: Detect significant position differences between sources

### 4. Altitude Difference Threshold: **18m**
- **Logic**: 95th percentile 15.4m + 3m buffer
- **Old Method**: 13.1m × 2.5 = 33m → **18m** (much more responsive!)
- **Purpose**: Detect altitude calculation differences

### 5. GPS Stability Threshold: **6m**
- **Logic**: Max observed jitter 4.7m + 1m buffer
- **Old Method**: 4.7m × 1.5 = 7m → **6m** (slightly tighter)
- **Purpose**: Detect GPS instability periods

## Benefits of Data-Driven Approach

### ✅ More Responsive
- **Altitude**: 18m vs 33m (45% more sensitive)
- **Position**: 6m vs 7m (better precision)
- **Starlink**: 7m vs 9m (earlier degradation detection)

### ✅ Based on Reality
- Thresholds reflect your actual GPS environment
- No arbitrary "safety factors" that hide real issues
- Better suited to your specific hardware and location

### ✅ Practical Alerting
- Fewer false positives from overly conservative thresholds
- Earlier detection of actual performance degradation
- More actionable alerts based on real performance boundaries

## Comparison: Old vs New Thresholds

| Threshold | Your Data | Old Method | New Method | Improvement |
|-----------|-----------|------------|------------|-------------|
| RUTOS Accuracy | 0.5m typical | 1m | 1m | Same |
| Starlink Accuracy | 5.0m typical | 9m | 7m | 22% more responsive |
| Position Accuracy | 5.2m max | 7m | 6m | 14% more precise |
| Altitude Difference | 15.4m p95 | 33m | 18m | 45% more sensitive |
| GPS Stability | 4.7m max jitter | 8m | 6m | 25% tighter |

## Implementation Notes

### Adaptive Calculation
The algorithm now uses different logic based on data quality:

```javascript
// Example: RUTOS threshold
if (observed_p95 <= 0.6) {
    threshold = 1;  // Standard threshold for excellent GPS
} else {
    threshold = Math.ceil(observed_p95 + 0.5);  // Adaptive for variable performance
}
```

### Safety Caps
All thresholds have maximum limits to prevent unreasonable values:
- Position accuracy: capped at 8m
- Altitude difference: capped at 20m  
- GPS stability: capped at 8m

### Monitoring Recommendations
With tighter, data-driven thresholds:
1. **Monitor alert frequency** - should be low with good GPS
2. **Track threshold crossings** - indicates real performance changes
3. **Review thresholds quarterly** - as GPS performance may change seasonally
4. **Log actual vs threshold** - validate threshold appropriateness over time

This approach gives you GPS monitoring that's tuned to your specific system performance rather than generic "one-size-fits-all" multipliers.
