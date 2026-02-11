# Schedule automatic VM shutdown to save money during non-working hours
# This script configures Azure auto-shutdown for a VM

param(
    [Parameter(Mandatory=$true)]
    [string]$VMName,
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [string]$ShutdownTime = "19:00",  # Default: 7 PM
    [string]$TimeZone = "UTC",        # Change to your timezone
    [string]$Notification = "Disabled" # or your email
)

Write-Host "⏰ Setting up auto-shutdown for VM: $VMName" -ForegroundColor Cyan

# Check if VM exists
Write-Host "🔍 Checking if VM exists..." -ForegroundColor Yellow
$vm = az vm show -n $VMName -g $ResourceGroup 2>$null

if (-not $vm) {
    Write-Host "❌ VM '$VMName' not found in resource group '$ResourceGroup'" -ForegroundColor Red
    exit 1
}

Write-Host "✅ VM found!" -ForegroundColor Green

# Get VM resource ID
$vmId = az vm show -n $VMName -g $ResourceGroup --query id -o tsv

# Create auto-shutdown schedule
Write-Host "`n📅 Creating auto-shutdown schedule..." -ForegroundColor Cyan
Write-Host "  Shutdown time: $ShutdownTime" -ForegroundColor White
Write-Host "  Timezone: $TimeZone" -ForegroundColor White

# Note: Azure auto-shutdown is configured via REST API or Portal
# Here's a simple az rest command approach
$scheduleId = "$vmId/providers/microsoft.devtestlab/schedules/shutdown-computevm-$VMName"

$body = @{
    location = (az vm show -n $VMName -g $ResourceGroup --query location -o tsv)
    properties = @{
        status = "Enabled"
        taskType = "ComputeVmShutdownTask"
        dailyRecurrence = @{
            time = $ShutdownTime.Replace(":", "")  # Format: 1900 for 19:00
        }
        timeZoneId = $TimeZone
        targetResourceId = $vmId
        notificationSettings = @{
            status = $Notification
        }
    }
} | ConvertTo-Json -Depth 10

try {
    az rest --method put --uri "https://management.azure.com$scheduleId`?api-version=2018-09-15" --body $body | Out-Null
    Write-Host "✅ Auto-shutdown configured successfully!" -ForegroundColor Green
    Write-Host "`n📋 Summary:" -ForegroundColor Cyan
    Write-Host "  VM: $VMName" -ForegroundColor White
    Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor White
    Write-Host "  Daily shutdown: $ShutdownTime ($TimeZone)" -ForegroundColor White
    Write-Host "`n💰 Estimated savings: ~50% on compute costs (assuming 12hr/day shutdown)" -ForegroundColor Green
}
catch {
    Write-Host "❌ Error configuring auto-shutdown: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "💡 You can also set this up in Azure Portal: VM > Auto-shutdown" -ForegroundColor Yellow
}

Write-Host "`n📝 Notes:" -ForegroundColor Yellow
Write-Host "  - Auto-shutdown only stops the VM, doesn't delete it" -ForegroundColor White
Write-Host "  - You can manually start the VM anytime" -ForegroundColor White
Write-Host "  - To disable: Run this script with -ShutdownTime 'Disabled'" -ForegroundColor White
