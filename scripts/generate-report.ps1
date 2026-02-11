# Generate a complete cost optimization report
# Combines all checks into one report

param(
    [string]$OutputPath = "./cost-report.html"
)

Write-Host "📊 Generating Azure Cost Optimization Report..." -ForegroundColor Cyan
Write-Host "This may take a few minutes...`n" -ForegroundColor Yellow

# Initialize report data
$reportData = @{
    GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Subscription = az account show --query name -o tsv
    Findings = @()
    TotalPotentialSavings = 0
}

# 1. Check unattached disks
Write-Host "Checking unattached disks..." -ForegroundColor Green
$unattachedDisks = az disk list --query "[?diskState=='Unattached'].{Name:name, ResourceGroup:resourceGroup, Size:diskSizeGb}" -o json | ConvertFrom-Json
if ($unattachedDisks) {
    $diskCost = ($unattachedDisks | Measure-Object -Property Size -Sum).Sum * 0.05
    $reportData.Findings += @{
        Category = "Storage"
        Issue = "Unattached Disks"
        Count = $unattachedDisks.Count
        MonthlyCost = [math]::Round($diskCost, 2)
        Details = $unattachedDisks
    }
    $reportData.TotalPotentialSavings += $diskCost
}

# 2. Check unused public IPs
Write-Host "Checking unused public IPs..." -ForegroundColor Green
$unusedIPs = az network public-ip list --query "[?ipConfiguration==null].{Name:name, ResourceGroup:resourceGroup}" -o json | ConvertFrom-Json
if ($unusedIPs) {
    $ipCost = $unusedIPs.Count * 3.5
    $reportData.Findings += @{
        Category = "Networking"
        Issue = "Unused Public IPs"
        Count = $unusedIPs.Count
        MonthlyCost = $ipCost
        Details = $unusedIPs
    }
    $reportData.TotalPotentialSavings += $ipCost
}

# 3. Check stopped VMs
Write-Host "Checking stopped VMs..." -ForegroundColor Green
$stoppedVMs = az vm list -d --query "[?powerState=='VM stopped'].{Name:name, ResourceGroup:resourceGroup, Size:hardwareProfile.vmSize}" -o json | ConvertFrom-Json
if ($stoppedVMs) {
    $reportData.Findings += @{
        Category = "Compute"
        Issue = "Stopped VMs (Still Billing)"
        Count = $stoppedVMs.Count
        MonthlyCost = "Unknown - Deallocate to stop billing"
        Details = $stoppedVMs
    }
}

# 4. Check empty resource groups
Write-Host "Checking empty resource groups..." -ForegroundColor Green
$allRGs = az group list --query "[].{Name:name}" -o json | ConvertFrom-Json
$emptyRGs = @()
foreach ($rg in $allRGs) {
    $resources = az resource list --resource-group $rg.Name --query "length(@)" -o tsv
    if ($resources -eq "0") {
        $emptyRGs += $rg
    }
}
if ($emptyRGs) {
    $reportData.Findings += @{
        Category = "Resource Groups"
        Issue = "Empty Resource Groups"
        Count = $emptyRGs.Count
        MonthlyCost = 0
        Details = $emptyRGs
    }
}

# Generate HTML report
Write-Host "`nGenerating HTML report..." -ForegroundColor Cyan

$html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Azure Cost Optimization Report</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #0078d4; border-bottom: 3px solid #0078d4; padding-bottom: 10px; }
        h2 { color: #333; margin-top: 30px; }
        .summary { background: #e7f3ff; padding: 20px; border-radius: 5px; margin: 20px 0; }
        .summary h2 { margin-top: 0; color: #0078d4; }
        .savings { font-size: 36px; color: #107c10; font-weight: bold; }
        .finding { background: #fff4ce; border-left: 4px solid #ffaa44; padding: 15px; margin: 15px 0; border-radius: 5px; }
        .finding h3 { margin-top: 0; color: #333; }
        .finding .cost { color: #e81123; font-weight: bold; font-size: 18px; }
        table { width: 100%; border-collapse: collapse; margin: 15px 0; }
        th { background: #0078d4; color: white; padding: 12px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #ddd; }
        tr:hover { background: #f5f5f5; }
        .footer { margin-top: 40px; padding-top: 20px; border-top: 1px solid #ddd; color: #666; font-size: 12px; }
        .info { background: #e7f3ff; padding: 10px; border-radius: 5px; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>💰 Azure Cost Optimization Report</h1>
        
        <div class="info">
            <p><strong>Subscription:</strong> $($reportData.Subscription)</p>
            <p><strong>Generated:</strong> $($reportData.GeneratedAt)</p>
        </div>
        
        <div class="summary">
            <h2>📊 Summary</h2>
            <p><strong>Total Findings:</strong> $($reportData.Findings.Count)</p>
            <p><strong>Estimated Monthly Savings:</strong></p>
            <div class="savings">`$$([math]::Round($reportData.TotalPotentialSavings, 2)) USD</div>
            <p style="color: #666; margin-top: 10px;">*This is a conservative estimate. Actual savings may be higher.</p>
        </div>
"@

# Add each finding
foreach ($finding in $reportData.Findings) {
    $html += @"
        <div class="finding">
            <h3>$($finding.Category): $($finding.Issue)</h3>
            <p><strong>Count:</strong> $($finding.Count)</p>
            <p class="cost">Potential Savings: `$$($finding.MonthlyCost)/month</p>
"@
    
    if ($finding.Details -and $finding.Details.Count -gt 0) {
        $html += "<table><tr>"
        # Get property names from first object
        $props = $finding.Details[0].PSObject.Properties.Name
        foreach ($prop in $props) {
            $html += "<th>$prop</th>"
        }
        $html += "</tr>"
        
        foreach ($item in $finding.Details | Select-Object -First 10) {
            $html += "<tr>"
            foreach ($prop in $props) {
                $html += "<td>$($item.$prop)</td>"
            }
            $html += "</tr>"
        }
        
        if ($finding.Details.Count -gt 10) {
            $html += "<tr><td colspan='$($props.Count)' style='text-align: center; color: #666;'>... and $($finding.Details.Count - 10) more</td></tr>"
        }
        
        $html += "</table>"
    }
    
    $html += "</div>"
}

# Add recommendations
$html += @"
        <h2>💡 Recommendations</h2>
        <ol>
            <li><strong>Immediate Actions:</strong>
                <ul>
                    <li>Delete unattached disks (after verifying they're not needed)</li>
                    <li>Release unused public IPs</li>
                    <li>Deallocate stopped VMs to stop billing</li>
                </ul>
            </li>
            <li><strong>Short Term:</strong>
                <ul>
                    <li>Set up auto-shutdown for dev/test VMs</li>
                    <li>Review VM sizes and rightsize based on usage</li>
                    <li>Clean up empty resource groups</li>
                </ul>
            </li>
            <li><strong>Long Term:</strong>
                <ul>
                    <li>Implement tagging strategy for cost tracking</li>
                    <li>Use Reserved Instances for production workloads</li>
                    <li>Set up budget alerts in Azure Cost Management</li>
                    <li>Regular monthly cost review</li>
                </ul>
            </li>
        </ol>
        
        <div class="footer">
            <p>Generated by Azure Cost Optimizer | <a href="https://github.com/yourusername/azure-cost-optimizer">GitHub</a></p>
            <p>⚠️ Always review recommendations before taking action. Test in dev/test environments first.</p>
        </div>
    </div>
</body>
</html>
"@

# Save report
$html | Out-File -FilePath $OutputPath -Encoding UTF8

Write-Host "`n✅ Report generated successfully!" -ForegroundColor Green
Write-Host "📄 Location: $OutputPath" -ForegroundColor Cyan
Write-Host "`n💰 Total Potential Monthly Savings: `$$([math]::Round($reportData.TotalPotentialSavings, 2)) USD" -ForegroundColor Green

# Try to open in browser
if ($env:OS -like "*Windows*") {
    Start-Process $OutputPath
} else {
    Write-Host "`n💡 Open the report in your browser: file://$((Get-Item $OutputPath).FullName)" -ForegroundColor Yellow
}
"@
