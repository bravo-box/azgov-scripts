# NVIDIA DDA Setup Script for Azure Local

This script automates the setup of NVIDIA GPUs on Azure Local using Discrete Device Assignment (DDA).

Reference: [Microsoft Azure Local GPU Preparation Guide](https://learn.microsoft.com/en-us/azure/azure-local/manage/gpu-preparation?view=azloc-2603)

## Overview

This PowerShell script performs the complete GPU preparation workflow for DDA:

1. **Detects GPUs** - Finds NVIDIA GPUs in error state on the host
2. **Dismounts GPUs** - Disables and removes GPUs from host assignment
3. **Downloads Driver** - Obtains the NVIDIA mitigation driver from Microsoft
4. **Installs Driver** - Installs the appropriate driver for your GPU model
5. **Verifies Setup** - Confirms GPUs are properly configured

## Prerequisites

### System Requirements
- Azure Local host with NVIDIA GPU(s)
- Windows Server 2022 or later
- Administrator privileges on the host
- Internet access to download drivers
- No host GPU driver currently installed (if there is, uninstall it first)

### Supported NVIDIA GPUs
- T4, A2, A10, A16, A40, L4, L40, L40S, RTX Pro 6000, and others
- See [Azure Local GPU Catalog](https://docs.microsoft.com/en-us/azure/azure-local/manage/gpu-preparation#supported-gpu-models) for complete list

## Usage

### Basic Usage (Auto-Detect)
```powershell
# Run with administrator privileges
.\enable-nvidia-dda.ps1
```

The script will automatically:
- Detect GPUs in error state
- Prompt for GPU model when installing the driver
- Skip driver download/extraction if already present

### Advanced Usage

#### Specify GPU Instances
```powershell
$gpus = @(
    "PCI\VEN_10DE&DEV_25B6&SUBSYS_157E10DE&REV_A1\4&23AD3A43&0&0010",
    "PCI\VEN_10DE&DEV_25B6&SUBSYS_157E10DE&REV_A1\4&17F8422A&0&0010"
)
.\enable-nvidia-dda.ps1 -GPUModelInstances $gpus
```

#### Skip Driver Download (if already available)
```powershell
.\enable-nvidia-dda.ps1 -SkipDownload $true
```

#### Custom Download Path
```powershell
.\enable-nvidia-dda.ps1 -DownloadPath "D:\nvidia-dda-prep"
```

#### Custom Driver URL
```powershell
.\enable-nvidia-dda.ps1 -DriverDownloadUrl "https://custom-url/nvidia-driver.zip"
```

## GPU Model Reference

When prompted for GPU model, use the model name (not the full product name):

| GPU Model | Model Name |
|-----------|-----------|
| NVIDIA T4 | `T4` |
| NVIDIA A2 | `A2` |
| NVIDIA A10 | `A10` |
| NVIDIA A16 | `A16` |
| NVIDIA A40 | `A40` |
| NVIDIA L4 | `L4` |
| NVIDIA L40 | `L40` |
| NVIDIA L40S | `L40S` |
| NVIDIA RTX Pro 6000 | `RTX6000` |

The script will show you available drivers during execution.

## Post-Installation Steps

After running the script:

1. **Review Configuration**
   - Open Device Manager
   - Look for NVIDIA GPUs under Display adapters
   - Verify all GPUs are properly recognized

2. **System Restart** (if required)
   - Some systems may require a restart for all changes to take effect
   - The script will indicate if restart is needed

3. **Verify GPU Status**
   - Run: `Get-PnpDevice -Class Display | Where-Object { $_.FriendlyName -like "*NVIDIA*" }`
   - Should show configured NVIDIA GPUs

4. **Configure VMs for DDA**
   - Use Hyper-V or Azure Local management tools to assign GPUs to VMs
   - Reference: [Manage GPU via DDA](https://learn.microsoft.com/en-us/azure/azure-local/manage/gpu-manage-via-device?view=azloc-2603)

## Troubleshooting

### No GPUs Found in Error State
- Verify NVIDIA GPUs are installed and powered on in BIOS
- Check if GPUs are already configured (script reports if found)
- Run Device Manager to manually confirm GPU presence

### Driver Installation Fails
- Verify you entered the correct GPU model name
- Run as Administrator
- Ensure NVIDIA drivers are not currently installed on the host
- Check available disk space (~2-3 GB required)

### GPUs Remain in Unknown State
- Try disabling/enabling in Device Manager
- Verify the correct driver is installed
- Restart the host machine

### Cannot Download Driver
- Verify internet connectivity
- Check if URL is still valid
- Try specifying `-SkipDownload $true` if driver already exists locally

## Script Output Example

```
========================================
Azure Local NVIDIA GPU DDA Setup
========================================

[STEP 1] Finding GPUs in error state...
==========================================
Found 2 GPU(s) in error state:

FriendlyName        InstanceId
3D Video Controller PCI\VEN_10DE&DEV_25B6&SUBSYS_157E10DE&REV_A1\4&23AD3A43&0&0010
3D Video Controller PCI\VEN_10DE&DEV_25B6&SUBSYS_157E10DE&REV_A1\4&17F8422A&0&0010

[STEP 2] Disabling and dismounting GPUs...
...
```

## Security Considerations

- Script requires Administrator privileges
- Driver is downloaded from official Microsoft/NVIDIA sources
- Installation is logged in Windows Event Viewer
- No telemetry or additional data collected

## Performance Notes

- DDA provides dedicated GPU access to individual VMs
- No GPU sharing between VMs with DDA
- Highest performance and compatibility isolation
- Best for workloads requiring full GPU capabilities

## Supported Workloads

With DDA-configured GPUs, Azure Local supports:
- **VMs (Azure Arc-enabled)** - Most flexible GPU deployment
- **Unmanaged VMs** - Legacy Azure Local deployments
- **AKS (Azure Arc-enabled)** - Kubernetes workloads (with limitations)
- Compute-intensive workloads: ML, Deep Learning, HPC, Rendering

## Related Documentation

- [Azure Local GPU Preparation](https://learn.microsoft.com/en-us/azure/azure-local/manage/gpu-preparation?view=azloc-2603)
- [GPU Management via DDA](https://learn.microsoft.com/en-us/azure/azure-local/manage/gpu-manage-via-device?view=azloc-2603)
- [GPU vs GPU-P Comparison](https://learn.microsoft.com/en-us/azure/azure-local/manage/gpu-preparation?view=azloc-2603#attaching-gpus-on-azure-local)
- [NVIDIA GPU Passthrough Documentation](https://docs.nvidia.com/datacenter/tesla/gpu-passthrough/)

## Version History

- **1.0** - Initial release based on Microsoft Azure Local GPU Preparation guide (March 2026)

## Support

For issues or questions:
1. Review the troubleshooting section above
2. Check Microsoft's GPU Preparation guide
3. Verify GPU compatibility in Azure Local Catalog
4. Review Windows Event Viewer for system errors
