# Find unused Azure resources that are costing you money
# This script finds resources that are running but not being used

Write-Host "🔍 Finding unused Azure resources..." -ForegroundColor Cyan

# Get current subscription
$subscription = az account show --query name -o tsv
Write-Host "📌 Checking subscription: $subscription" -ForegroundColor Yellow

# Find unattached disks (disks not connected to any VM)
Write-Host "`n💾 Checking for unattached disks..." -ForegroundColor Green
$unattachedDisks = az disk list --query "[?diskState=='Unattached'].{Name:name, ResourceGroup:resourceGroup, Size:diskSizeGb, SKU:sku.name}" -o json | ConvertFrom-Json

if ($unattachedDisks) {
    Write-Host "Found $($unattachedDisks.Count) unattached disk(s):" -ForegroundColor Red
    $unattachedDisks | Format-Table -AutoSize
    
    # Calculate approximate cost
    $totalSize = ($unattachedDisks | Measure-Object -Property Size -Sum).Sum
    Write-Host "Total size: $totalSize GB (approx cost: $([math]::Round($totalSize * 0.05, 2)) USD/month)" -ForegroundColor Yellow
} else {
    Write-Host "✅ No unattached disks found!" -ForegroundColor Green
}

# Find empty resource groups
Write-Host "`n📦 Checking for empty resource groups..." -ForegroundColor Green
$allRGs = az group list --query "[].{Name:name}" -o json | ConvertFrom-Json

$emptyRGs = @()
foreach ($rg in $allRGs) {
    $resources = az resource list --resource-group $rg.Name --query "length(@)" -o tsv
    if ($resources -eq "0") {
        $emptyRGs += $rg
    }
}

if ($emptyRGs) {
    Write-Host "Found $($emptyRGs.Count) empty resource group(s):" -ForegroundColor Red
    $emptyRGs | Format-Table -AutoSize
} else {
    Write-Host "✅ No empty resource groups found!" -ForegroundColor Green
}

# Find unassociated public IPs
Write-Host "`n🌐 Checking for unused public IPs..." -ForegroundColor Green
$unusedIPs = az network public-ip list --query "[?ipConfiguration==null].{Name:name, ResourceGroup:resourceGroup, SKU:sku.name}" -o json | ConvertFrom-Json

if ($unusedIPs) {
    Write-Host "Found $($unusedIPs.Count) unused public IP(s):" -ForegroundColor Red
    $unusedIPs | Format-Table -AutoSize
    Write-Host "Approx cost: $([math]::Round($unusedIPs.Count * 3.5, 2)) USD/month" -ForegroundColor Yellow
} else {
    Write-Host "✅ No unused public IPs found!" -ForegroundColor Green
}

# Find stopped but allocated VMs (still costing money)
Write-Host "`n🖥️  Checking for stopped (but allocated) VMs..." -ForegroundColor Green
$stoppedVMs = az vm list -d --query "[?powerState=='VM stopped'].{Name:name, ResourceGroup:resourceGroup, Size:hardwareProfile.vmSize}" -o json | ConvertFrom-Json

if ($stoppedVMs) {
    Write-Host "Found $($stoppedVMs.Count) stopped VM(s) (still billing):" -ForegroundColor Red
    $stoppedVMs | Format-Table -AutoSize
    Write-Host "💡 Tip: Use 'az vm deallocate' to stop billing!" -ForegroundColor Yellow
} else {
    Write-Host "✅ No stopped (allocated) VMs found!" -ForegroundColor Green
}

# Find App Service Plans with no apps
Write-Host "`n🌍 Checking for empty App Service Plans..." -ForegroundColor Green
$allPlans = az appservice plan list --query "[].{Name:name, ResourceGroup:resourceGroup, SKU:sku.name}" -o json | ConvertFrom-Json

$emptyPlans = @()
foreach ($plan in $allPlans) {
    $apps = az webapp list --query "[?appServicePlanId==``/subscriptions/*/$($plan.Name)``].name" -o tsv
    if (-not $apps) {
        $emptyPlans += $plan
    }
}

if ($emptyPlans) {
    Write-Host "Found $($emptyPlans.Count) empty App Service Plan(s):" -ForegroundColor Red
    $emptyPlans | Format-Table -AutoSize
} else {
    Write-Host "✅ No empty App Service Plans found!" -ForegroundColor Green
}

# Summary
Write-Host "`n" + ("="*60) -ForegroundColor Cyan
Write-Host "📊 SUMMARY" -ForegroundColor Cyan
Write-Host ("="*60) -ForegroundColor Cyan
Write-Host "Unattached Disks: $($unattachedDisks.Count)"
Write-Host "Empty Resource Groups: $($emptyRGs.Count)"
Write-Host "Unused Public IPs: $($unusedIPs.Count)"
Write-Host "Stopped VMs: $($stoppedVMs.Count)"
Write-Host "Empty App Service Plans: $($emptyPlans.Count)"
Write-Host "`n💡 Review these resources and delete if not needed!" -ForegroundColor Yellow
Write-Host "⚠️  Always backup/snapshot before deleting!" -ForegroundColor Red
