# Azure Cost Optimizer 💰

Simple PowerShell and Azure CLI scripts to help reduce your Azure bills.

## 📋 What's Inside

- **unused-resources-finder.ps1** - Find resources that cost money but aren't being used
- **rightsizing-recommendations.ps1** - Get suggestions to resize VMs based on actual usage
- **scheduling-automations/** - Scripts to auto-start/stop resources on schedule

## 🚀 Prerequisites

- Azure CLI installed ([Install Guide](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli))
- PowerShell 7+ ([Install Guide](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell))
- Azure subscription with appropriate permissions

## 🔐 Login to Azure

```powershell
az login
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

## 📊 Usage Examples

### Find Unused Resources
```powershell
cd scripts
./unused-resources-finder.ps1
```

### Get Rightsizing Recommendations
```powershell
./rightsizing-recommendations.ps1 -ResourceGroup "my-rg"
```

### Schedule VM Auto-Shutdown
```powershell
cd scheduling-automations
./schedule-vm-shutdown.ps1 -VMName "my-vm" -ResourceGroup "my-rg" -ShutdownTime "19:00"
```

## 💡 Tips

- Run these scripts regularly (weekly) to catch cost leaks early
- Test in dev/test subscription first
- Always review before deleting resources!
- Use tags to exclude resources from automation

## 📝 License

MIT License - feel free to use and modify

## 🤝 Contributing

Found a bug or have an idea? Open an issue or submit a PR!

---

**Note:** These are simple scripts for learning and small-scale usage. For enterprise scenarios, consider Azure Cost Management APIs or third-party tools.
