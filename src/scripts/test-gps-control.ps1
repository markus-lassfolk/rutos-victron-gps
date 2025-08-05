# GPS Control Test Script (PowerShell)
# =====================================

Write-Host "Testing GPS Control System..." -ForegroundColor Green

# Test 1: Get system status
Write-Host "1. Getting system status..." -ForegroundColor Yellow
mosquitto_pub -h localhost -t "gps/control/get_status" -m "true"
Start-Sleep 2

# Test 2: Get logs
Write-Host "2. Getting logs..." -ForegroundColor Yellow
mosquitto_pub -h localhost -t "gps/control/get_logs" -m "true"
Start-Sleep 2

# Test 3: Test source override
Write-Host "3. Testing source override to RUTOS..." -ForegroundColor Yellow
mosquitto_pub -h localhost -t "gps/control/source" -m "rutos"
Start-Sleep 2

# Test 4: Return to auto
Write-Host "4. Returning to auto source selection..." -ForegroundColor Yellow
mosquitto_pub -h localhost -t "gps/control/source" -m "auto"
Start-Sleep 2

# Test 5: Adjust camping threshold
Write-Host "5. Setting camping threshold to 25m..." -ForegroundColor Yellow
mosquitto_pub -h localhost -t "gps/control/config" -m '{"param":"camping_threshold","value":25}'
Start-Sleep 2

# Test 6: Get updated status  
Write-Host "6. Getting updated status..." -ForegroundColor Yellow
mosquitto_pub -h localhost -t "gps/control/get_status" -m "true"

Write-Host ""
Write-Host "Test commands sent. In another terminal, run:" -ForegroundColor Green
Write-Host "mosquitto_sub -h localhost -t 'gps/status' -t 'gps/logs'" -ForegroundColor Cyan
Write-Host "to see the responses." -ForegroundColor Green
