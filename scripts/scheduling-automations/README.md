[README.md](https://github.com/user-attachments/files/25238462/README.md)
# Scheduling Automations ⏰

Scripts to automatically start/stop/scale Azure resources based on schedule.

## 📋 Available Scripts

### 1. schedule-vm-shutdown.ps1
Configure Azure auto-shutdown for a VM (built-in Azure feature).

**Usage:**
```powershell
./schedule-vm-shutdown.ps1 -VMName "my-vm" -ResourceGroup "my-rg" -ShutdownTime "19:00"
```

**Parameters:**
- `-VMName` - Name of the VM
- `-ResourceGroup` - Resource group name
- `-ShutdownTime` - Time to shutdown (24h format, e.g., "19:00")
- `-TimeZone` - Timezone (default: "UTC")

### 2. start-stop-vms.ps1
Start or stop VMs on demand (use with Task Scheduler/cron).

**Usage:**
```powershell
# Stop all VMs with tag
./start-stop-vms.ps1 -Action Stop -Tag "AutoShutdown=Yes"

# Start VMs in resource group
./start-stop-vms.ps1 -Action Start -ResourceGroup "my-rg"

# Test without making changes
./start-stop-vms.ps1 -Action Stop -ResourceGroup "my-rg" -DryRun
```

**Parameters:**
- `-Action` - "Start" or "Stop"
- `-ResourceGroup` - (Optional) Filter by resource group
- `-Tag` - (Optional) Filter by tag (format: "Key=Value")
- `-DryRun` - Test mode without making changes

### 3. scale-appservice.ps1
Scale App Service Plans up/down.

**Usage:**
```powershell
# Scale down for night
./scale-appservice.ps1 -PlanName "my-plan" -ResourceGroup "my-rg" -Tier Basic -Size B1

# Scale up for business hours
./scale-appservice.ps1 -PlanName "my-plan" -ResourceGroup "my-rg" -Tier Standard -Size S1
```

## 🤖 Automation Setup

### Windows (Task Scheduler)

**Stop VMs at 7 PM:**
```powershell
$action = New-ScheduledTaskAction -Execute "pwsh" -Argument "-File C:\scripts\start-stop-vms.ps1 -Action Stop -Tag AutoShutdown=Yes"
$trigger = New-ScheduledTaskTrigger -Daily -At 7PM
Register-ScheduledTask -TaskName "Stop VMs" -Action $action -Trigger $trigger
```

**Start VMs at 8 AM:**
```powershell
$action = New-ScheduledTaskAction -Execute "pwsh" -Argument "-File C:\scripts\start-stop-vms.ps1 -Action Start -Tag AutoShutdown=Yes"
$trigger = New-ScheduledTaskTrigger -Daily -At 8AM
Register-ScheduledTask -TaskName "Start VMs" -Action $action -Trigger $trigger
```

### Linux (cron)

```bash
# Edit crontab
crontab -e

# Add these lines:
# Stop VMs at 7 PM (19:00) on weekdays
0 19 * * 1-5 /usr/bin/pwsh /scripts/start-stop-vms.ps1 -Action Stop -Tag "AutoShutdown=Yes"

# Start VMs at 8 AM on weekdays
0 8 * * 1-5 /usr/bin/pwsh /scripts/start-stop-vms.ps1 -Action Start -Tag "AutoShutdown=Yes"
```

### Azure Automation (Recommended for Production)

1. Create Automation Account
2. Import scripts as Runbooks
3. Create schedules
4. Link schedules to Runbooks

**Why Azure Automation?**
- No need for local machine to be running
- Integrated with Azure
- Can use Managed Identity
- Free for first 500 minutes/month

## 💰 Cost Savings Examples

**Example 1: Dev/Test VMs**
- 3 VMs running 24/7: $300/month
- Same VMs running 12h/day (business hours): $150/month
- **Savings: $150/month (50%)**

**Example 2: App Service Plan**
- Standard S1 24/7: $75/month
- Standard S1 business hours + Basic B1 off-hours: $50/month
- **Savings: $25/month (33%)**

## 🏷️ Tagging Strategy

Tag resources for automated scheduling:

```bash
# Tag VM for auto-shutdown
az vm update -n my-vm -g my-rg --set tags.AutoShutdown=Yes

# Tag VM to exclude from automation
az vm update -n prod-vm -g my-rg --set tags.AutoShutdown=No
```

Common tags:
- `AutoShutdown=Yes/No` - Include in scheduled shutdowns
- `Environment=Dev/Test/Prod` - Environment type
- `ShutdownTime=19:00` - Custom shutdown time
- `StartTime=08:00` - Custom start time

## 📝 Best Practices

1. **Test first** - Always use `-DryRun` parameter first
2. **Tag properly** - Use tags to control what gets automated
3. **Start small** - Begin with dev/test environments
4. **Monitor** - Check logs and VM states regularly
5. **Weekend handling** - Consider different schedules for weekends
6. **Notifications** - Set up alerts for failed operations

## ⚠️ Important Notes

- Stopping VMs saves compute costs, but disks still cost money
- Use `deallocate` not just `stop` to fully stop billing
- App Service on Free tier has limitations
- Always test in dev environment first!
