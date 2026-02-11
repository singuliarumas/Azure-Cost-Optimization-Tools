# Simple script to start or stop VMs on schedule
# Run this via cron/task scheduler at specific times

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Start", "Stop")]
    [string]$Action,
    
    [string]$ResourceGroup = "",  # Leave empty for all VMs
    [string]$Tag = "",            # e.g., "AutoShutdown=Yes"
    [switch]$DryRun               # Test mode - don't actually start/stop
)

Write-Host "🔄 VM Scheduler - Action: $Action" -ForegroundColor Cyan

# Get VMs based on filters
if ($ResourceGroup) {
    Write-Host "🔍 Looking for VMs in Resource Group: $ResourceGroup" -ForegroundColor Yellow
    $vms = az vm list -g $ResourceGroup --query "[].{Name:name, ResourceGroup:resourceGroup}" -o json | ConvertFrom-Json
} elseif ($Tag) {
    Write-Host "🔍 Looking for VMs with tag: $Tag" -ForegroundColor Yellow
    $tagParts = $Tag -split "="
    $vms = az vm list --query "[?tags.$($tagParts[0])=='$($tagParts[1])'].{Name:name, ResourceGroup:resourceGroup}" -o json | ConvertFrom-Json
} else {
    Write-Host "⚠️  No filter specified - will affect ALL VMs!" -ForegroundColor Red
    Write-Host "Press Ctrl+C to cancel, or Enter to continue..." -ForegroundColor Yellow
    Read-Host
    $vms = az vm list --query "[].{Name:name, ResourceGroup:resourceGroup}" -o json | ConvertFrom-Json
}

if (-not $vms) {
    Write-Host "❌ No VMs found!" -ForegroundColor Red
    exit
}

Write-Host "Found $($vms.Count) VM(s)`n" -ForegroundColor Green

# Process each VM
$success = 0
$failed = 0

foreach ($vm in $vms) {
    Write-Host "Processing: $($vm.Name)" -ForegroundColor Cyan
    
    # Check current state
    $state = az vm show -n $vm.Name -g $vm.ResourceGroup -d --query powerState -o tsv
    Write-Host "  Current state: $state" -ForegroundColor White
    
    # Determine action
    $shouldProcess = $false
    
    if ($Action -eq "Stop" -and $state -like "*running*") {
        $shouldProcess = $true
        $actionCommand = "deallocate"
        $actionText = "Stopping (deallocating)"
    } elseif ($Action -eq "Start" -and $state -like "*stopped*") {
        $shouldProcess = $true
        $actionCommand = "start"
        $actionText = "Starting"
    } else {
        Write-Host "  ⏭️  Skipping (already in desired state)" -ForegroundColor Gray
    }
    
    if ($shouldProcess) {
        if ($DryRun) {
            Write-Host "  🧪 [DRY RUN] Would $actionText VM" -ForegroundColor Yellow
            $success++
        } else {
            Write-Host "  ▶️  $actionText VM..." -ForegroundColor Yellow
            try {
                az vm $actionCommand -n $vm.Name -g $vm.ResourceGroup --no-wait
                Write-Host "  ✅ Command sent successfully" -ForegroundColor Green
                $success++
            }
            catch {
                Write-Host "  ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
                $failed++
            }
        }
    }
    Write-Host ""
}

# Summary
Write-Host ("="*60) -ForegroundColor Cyan
Write-Host "📊 SUMMARY" -ForegroundColor Cyan
Write-Host ("="*60) -ForegroundColor Cyan
Write-Host "Total VMs: $($vms.Count)"
Write-Host "Processed: $success"
Write-Host "Failed: $failed"
Write-Host "Skipped: $($vms.Count - $success - $failed)"

if ($DryRun) {
    Write-Host "`n🧪 This was a DRY RUN - no changes were made" -ForegroundColor Yellow
    Write-Host "Remove -DryRun parameter to execute for real" -ForegroundColor Yellow
}

Write-Host "`n💡 Setup Tips:" -ForegroundColor Cyan
Write-Host "  Windows: Use Task Scheduler to run this script daily" -ForegroundColor White
Write-Host "  Linux: Use cron (e.g., '0 19 * * * pwsh script.ps1 -Action Stop')" -ForegroundColor White
Write-Host "  Azure: Use Automation Account with runbooks" -ForegroundColor White
