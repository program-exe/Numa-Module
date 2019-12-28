<#
.SYNOPSIS
    CHeck CPU information for a given Virtual Machine within vCenter
.DESCRIPTION
    Performs the following action to check and fix CPU information (Numa):
        Gets information of VM and Host that VM lives on
        Checks Socket, CoresPerSocket and NumCPU against Host CPU capability
        If Numa information needs changing, turn VM off in order to fix. Else, skip.
.Parameter [Array]VMInfo
    Provide VM name to check
.Parameter [VMware.VimAutomation.Types.VIServer]$Server
    Provide vCenter Server where VM lives
.NOTES
  Version:        1.0
  Author:         <Joshua Dooling, Jason Nagin>
  Creation Date:  <08/10/2019>
  Purpose/Change: Check VMs to reassure Numa information is correct
.EXAMPLE
    PS C:\> "Deploy.ps1"
#>
Function CheckNuma{

    Param(
        [Parameter(Mandatory = $true)]
        [Array]$VMInfo,
        [VMware.VimAutomation.Types.VIServer]$Server
    )

    try{

        $getVM = Get-VM -Name "$($VMInfo.Name) - *" -Server $Server | select VMHost, Guest, @{n='Sockets'; e={($_.NumCpu)/($_.CoresPerSocket)}}, @{n='CoresPerSocket'; e={$_.CoresPerSocket}}, @{n='NumCPU'; e={$_.NumCpu}}

        $vmHost = Get-VMHost -Server $Server -Name $getVM.VMHost | Select-Object Name, @{n='HostSockets'; e={($_.ExtensionData.Hardware.CpuInfo.NumCpuPackages)}}, @{n='CoresPerSocket'; e={($_.ExtensionData.Hardware.CpuInfo.NumCPUCores)/$($_.ExtensionData.Hardware.CpuInfo.NumCpuPackages)}}      

        if(($getVM.Sockets -eq 1 -and $getVM.CoresPerSocket -gt $vmHost.CoresPerSocket) -or ($getVM.Sockets -gt $vmHost.HostSockets) -or ($getVM.CoresPerSocket -gt $VMHost.CoresPerSocket) -or ($GetVM.Sockets -gt 1 -and $getVM.NumCPU -lt $VMHost.CoresPerSocket) -or ($getVM.NumCPU -gt ($VMHost.CoresPerSocket * $VMHost.HostSockets))){
            throw "1"    
        }

        return "$($VMInfo.Name) Numa information is already optimized"

    }catch{
        if($_.Exception.Message -eq 1){
            Write-Host "$($VMInfo.Name) Numa information needs to be changed"

            if($getVM.Guest.State -ne "NotRunning"){
                Write-Host "Powering off $($VMInfo.Name)...."

                Shutdown-VMGuest -VM "$($VMInfo.Name) - *" -Server $Server -Confirm:$false | Out-Null
                Sleep -Seconds 15
            }

            $correctSockets = [Math]::Ceiling($getVM.NumCPU/$vmHost.CoresPerSocket)
            $correctCPS = [Math]::Floor($getVM.NumCPU/$correctSockets)
            $newVCPU = $correctSockets * $correctCPS

            $check = Set-VM -VM "$($VMInfo.Name) - *" -Server $Server -NumCpu $newVCPU -CoresPerSocket $correctCPS -Confirm:$false | Out-String

            if($null -eq $check){
                return "Unfortunately the Numa information could not be changed for $($VmInfo.Name)"
            }

            $VM = Get-VM -Name "$($VMInfo.Name) - *" -Server $Server | select Guest
            $State = $VM.Guest.State

            if($State -ne "Running"){
                Write-Host "Powering on $($VMInfo.Name)...."

                Start-VM -VM "$($VMInfo.Name) - *" -Server $Server -Confirm:$false | Out-Null
                Sleep -Seconds 5
            }

            return "$($VMInfo.Name) Numa information has been changed"
            
        }
    }
}
