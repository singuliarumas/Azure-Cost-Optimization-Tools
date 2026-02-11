# Scale App Service Plans up/down based on schedule
# Save money by scaling down during non-business hours

param(
    [Parameter(Mandatory=$true)]
    [string]$PlanName,
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet("Free", "Basic", "Standard", "Premium")]
    [string]$Tier,
    
    [string]$Size = "B1"  # e.g., B1, S1, P1v2
)

Write-Host "📈 Scaling App Service Plan" -ForegroundColor Cyan

# Check if plan exists
Write-Host "🔍 Checking if App Service Plan exists..." -ForegroundColor Yellow
$plan = az appservice plan show -n $PlanName -g $ResourceGroup 2>$null

if (-not $plan) {
    Write-Host "❌ App Service Plan '$PlanName' not found!" -ForegroundColor Red
    exit 1
}

# Get current SKU
$currentPlan = $plan | ConvertFrom-Json
Write-Host "✅ Plan found!" -ForegroundColor Green
Write-Host "  Current tier: $($currentPlan.sku.tier)" -ForegroundColor White
Write-Host "  Current size: $($currentPlan.sku.name)" -ForegroundColor White

# Scale the plan
Write-Host "`n🔄 Scaling to: $Tier - $Size" -ForegroundColor Cyan

try {
    # Map tier to --sku parameter
    $skuMap = @{
        "Free" = "F1"
        "Basic" = $Size
        "Standard" = $Size
        "Premium" = $Size
    }
    
    $sku = $skuMap[$Tier]
    
    Write-Host "Executing: az appservice plan update --sku $sku..." -ForegroundColor Yellow
    az appservice plan update -n $PlanName -g $ResourceGroup --sku $sku | Out-Null
    
    Write-Host "✅ Scaling complete!" -ForegroundColor Green
    
    # Show new configuration
    $updatedPlan = az appservice plan show -n $PlanName -g $ResourceGroup | ConvertFrom-Json
    Write-Host "`n📋 New Configuration:" -ForegroundColor Cyan
    Write-Host "  Tier: $($updatedPlan.sku.tier)" -ForegroundColor White
    Write-Host "  Size: $($updatedPlan.sku.name)" -ForegroundColor White
    
    # Cost estimation
    Write-Host "`n💰 Approximate Monthly Cost:" -ForegroundColor Cyan
    switch ($Tier) {
        "Free"     { Write-Host "  ~$0 USD/month" -ForegroundColor Green }
        "Basic"    { Write-Host "  ~$13-55 USD/month (depends on size)" -ForegroundColor Yellow }
        "Standard" { Write-Host "  ~$75-300 USD/month (depends on size)" -ForegroundColor Yellow }
        "Premium"  { Write-Host "  ~$150-600 USD/month (depends on size)" -ForegroundColor Red }
    }
}
catch {
    Write-Host "❌ Error scaling: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`n💡 Usage Examples:" -ForegroundColor Cyan
Write-Host "  Scale DOWN for night (save money):" -ForegroundColor White
Write-Host "    ./scale-appservice.ps1 -PlanName 'my-plan' -ResourceGroup 'my-rg' -Tier Basic -Size B1" -ForegroundColor Gray
Write-Host "  Scale UP for business hours:" -ForegroundColor White
Write-Host "    ./scale-appservice.ps1 -PlanName 'my-plan' -ResourceGroup 'my-rg' -Tier Standard -Size S1" -ForegroundColor Gray
Write-Host "`n  Automate with Task Scheduler or cron!" -ForegroundColor Yellow
