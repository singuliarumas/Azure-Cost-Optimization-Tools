# Get VM rightsizing recommendations based on actual CPU/Memory usage
# Helps you resize VMs to save money

param(
    [string]$ResourceGroup = "",  # Leave empty to check all VMs
    [int]$DaysBack = 7            # Check metrics for last N days
)

Write-Host "📊 Getting VM rightsizing recommendations..." -ForegroundColor Cyan
Write-Host "Looking back $DaysBack days" -ForegroundColor Yellow

# Get all VMs (or in specific RG)
if ($ResourceGroup) {
    Write-Host "🔍 Checking VMs in Resource Group: $ResourceGroup" -ForegroundColor Yellow
    $vms = az vm list -g $ResourceGroup --query "[].{Name:name, ResourceGroup:resourceGroup, Size:hardwareProfile.vmSize, Location:location}" -o json | ConvertFrom-Json
} else {
    Write-Host "🔍 Checking ALL VMs in subscription" -ForegroundColor Yellow
    $vms = az vm list --query "[].{Name:name, ResourceGroup:resourceGroup, Size:hardwareProfile.vmSize, Location:location}" -o json | ConvertFrom-Json
}

if (-not $vms) {
    Write-Host "❌ No VMs found!" -ForegroundColor Red
    exit
}

Write-Host "Found $($vms.Count) VM(s)`n" -ForegroundColor Green

# Check each VM
$recommendations = @()

foreach ($vm in $vms) {
    Write-Host "Analyzing: $($vm.Name) (Size: $($vm.Size))" -ForegroundColor Cyan
    
    # Get VM metrics - CPU usage
    try {
        $endTime = Get-Date
        $startTime = $endTime.AddDays(-$DaysBack)
        
        # Get average CPU percentage
        $cpuMetrics = az monitor metrics list `
            --resource "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$($vm.ResourceGroup)/providers/Microsoft.Compute/virtualMachines/$($vm.Name)" `
            --metric "Percentage CPU" `
            --start-time $startTime.ToString("yyyy-MM-ddTHH:mm:ssZ") `
            --end-time $endTime.ToString("yyyy-MM-ddTHH:mm:ssZ") `
            --aggregation Average `
            --interval PT1H `
            -o json 2>$null | ConvertFrom-Json
        
        if ($cpuMetrics.value.timeseries) {
            $cpuValues = $cpuMetrics.value.timeseries[0].data | Where-Object { $_.average -ne $null } | Select-Object -ExpandProperty average
            
            if ($cpuValues) {
                $avgCPU = [math]::Round(($cpuValues | Measure-Object -Average).Average, 2)
                $maxCPU = [math]::Round(($cpuValues | Measure-Object -Maximum).Maximum, 2)
                
                Write-Host "  CPU Usage: Avg=$avgCPU%, Max=$maxCPU%" -ForegroundColor White
                
                # Make recommendations
                $recommendation = $null
                $savings = "Unknown"
                
                if ($avgCPU -lt 10 -and $maxCPU -lt 30) {
                    $recommendation = "Consider downsizing - very low CPU usage"
                    $savings = "~30-50%"
                } elseif ($avgCPU -lt 25 -and $maxCPU -lt 50) {
                    $recommendation = "Could downsize - low CPU usage"
                    $savings = "~20-30%"
                } elseif ($avgCPU -gt 80 -or $maxCPU -gt 90) {
                    $recommendation = "Consider upsizing - high CPU usage"
                    $savings = "N/A (performance issue)"
                } else {
                    $recommendation = "Size looks good"
                    $savings = "N/A"
                }
                
                $recommendations += [PSCustomObject]@{
                    VM = $vm.Name
                    ResourceGroup = $vm.ResourceGroup
                    CurrentSize = $vm.Size
                    AvgCPU = "$avgCPU%"
                    MaxCPU = "$maxCPU%"
                    Recommendation = $recommendation
                    PotentialSavings = $savings
                }
                
                if ($recommendation -like "*downsize*") {
                    Write-Host "  💡 $recommendation" -ForegroundColor Yellow
                } elseif ($recommendation -like "*upsize*") {
                    Write-Host "  ⚠️  $recommendation" -ForegroundColor Red
                } else {
                    Write-Host "  ✅ $recommendation" -ForegroundColor Green
                }
            } else {
                Write-Host "  ⚠️  No CPU metrics available" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  ⚠️  No metrics data found" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  ❌ Error getting metrics: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
}

# Display summary table
if ($recommendations.Count -gt 0) {
    Write-Host "`n" + ("="*100) -ForegroundColor Cyan
    Write-Host "📋 RECOMMENDATIONS SUMMARY" -ForegroundColor Cyan
    Write-Host ("="*100) -ForegroundColor Cyan
    $recommendations | Format-Table -AutoSize
    
    # Count recommendations
    $downsizeCount = ($recommendations | Where-Object { $_.Recommendation -like "*downsize*" }).Count
    $upsizeCount = ($recommendations | Where-Object { $_.Recommendation -like "*upsize*" }).Count
    
    Write-Host "`n📊 Quick Stats:" -ForegroundColor Cyan
    Write-Host "  VMs that could downsize: $downsizeCount" -ForegroundColor Yellow
    Write-Host "  VMs that should upsize: $upsizeCount" -ForegroundColor Red
    Write-Host "  VMs with good sizing: $($recommendations.Count - $downsizeCount - $upsizeCount)" -ForegroundColor Green
    
    if ($downsizeCount -gt 0) {
        Write-Host "`n💰 Potential monthly savings: 20-50% on downsized VMs" -ForegroundColor Green
        Write-Host "Use 'az vm resize' command to change VM size" -ForegroundColor Yellow
    }
}

Write-Host "`n📝 Note: These are rough recommendations. Always test before resizing!" -ForegroundColor Yellow
Write-Host "💡 Tip: Use Azure Advisor for more detailed recommendations" -ForegroundColor Cyan
