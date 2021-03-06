function IsHostESXi {
	[CmdletBinding()]
	[OutputType([bool])]
    param()
    $ErrorActionPreference = "Stop"
    Write-Debug "Call to IsHostESXi"
	Write-Verbose "Interrogating WMI BIOS Serial Number to ascertain whether hardware is ESXi Virtualised"
	Write-Debug "(Get-WmiObject Win32_BIOS).SerialNumber -like `"VMware*`""
	$returnValue = (Get-WmiObject Win32_BIOS).SerialNumber -like "VMware*"
    Write-Debug "Return value is $returnValue"
    return $returnValue
}

function VMwareToolsInstalled {
	[CmdletBinding()]
	[OutputType([bool])]
    param()
    $ErrorActionPreference = "Stop"
    Write-Debug "Call to VMWareToolsInstalled"
	Write-Verbose "Interrogating registry to ascertain whether VMware Tools is Installed"
	Write-Debug "[bool](Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName -eq `"VMware Tools`" })"	
	$returnValue = [bool](Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName -eq "VMware Tools" })
    Write-Debug "Return value is $returnValue"
    return $returnValue
}

function Run-Exe{
	[CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]$Cmd,
        [string[]]$args
    )
	BEGIN {
        Write-Debug "Call to Run-Exe"
		$ErrorMessage = "Execution of command failed:`n`t$Cmd $args"
        $exitCodesIgnore = (0,3010)
        $ErrorActionPreference = "SilentlyContinue"
	}
    PROCESS{
        <#Write-Debug "`$cmdOutput=& cmd /c `$Cmd @args"
        Write-Debug "`$cmdOutput=& cmd /c $Cmd $args"
        $cmdOutput=& cmd /c $Cmd @args
    	if($LastExitCode -notin $exitCodesIgnore){
            Write-Verbose "Failed running executable $Cmd"
            Write-Verbose "Output: $cmdOutput"
			throw [System.Exception] "Return Code: $LastExitCode`n`nExec: $ErrorMessage`n`nOutput: $cmdOutput"		
		}#>

        $startinfo = new-object System.Diagnostics.ProcessStartInfo
        $startinfo.FileName = $Cmd
        $startinfo.Arguments = $args
	    $startinfo.WindowStyle = "Hidden"
	    $startinfo.CreateNoWindow = $True
	    $startinfo.RedirectStandardError = $True
	    $startinfo.RedirectStandardOutput = $True
	    $startinfo.UseShellExecute = $False

        $job = [System.Diagnostics.Process]::Start($startinfo)

        if($job.process.ExitCode -notin $exitCodesIgnore){
            Write-Verbose "Failed running executable $Cmd"
            Write-Verbose "Output: $cmdOutput"
			throw [System.Exception] "Return Code: $LastExitCode`n`nExec: $ErrorMessage`n`nOutput: $cmdOutput"		
		}
	}
}

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $InstallerPath
    )
    $ErrorActionPreference = "Stop"
    Write-Debug "Call to Get-TargetResource"
    $ensureResult = "Absent"
	Write-Debug "if(!(IsHostESXi)) || elseif(VMwareToolsInstalled)"
	if(!(IsHostESXi)){
		Write-Verbose "Hardware is not VMware/ESXi Virtualised - returning `"Present`""
		$ensureResult = "Present"	
	} elseif(VMwareToolsInstalled) {
		Write-Verbose "VMware Tools Installed - returning `"Present`""
		$ensureResult = "Present"	
	}
	return @{
			InstallerPath = $InstallerPath
			Ensure = $ensureResult
	}
}


function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [parameter(Mandatory = $true)]
        [System.String]
        $InstallerPath
    )
    $ErrorActionPreference = "Stop"    
    Write-Debug "Call to Set-TargetResource"
    Write-Verbose "If Ensure=`"Present`" and VMware Tools Not Installed..."
    Write-Debug "if(`$Ensure -eq `"Present`" -and (VMwareToolsInstalled) -eq `$false){"
    Write-Debug "if($Ensure -eq `"Present`" -and (VMwareToolsInstalled) -eq $false){"
	if($Ensure -eq "Present" -and (VMwareToolsInstalled) -eq $false){
		Write-Verbose "Ensuring that the installer exists | $InstallerPath"
		Write-Debug "if(!(Test-Path -Path $InstallerPath)){"
		if(!(Test-Path -Path $InstallerPath)){
			throw [System.IO.FileNotFoundException]"Cannot find VMware Tools installer at path $InstallerPath"
		}

        if($PSCmdlet.ShouldProcess("WhatIf: Running $InstallerPath /S /v`"/qn REBOOT=ReallySuppress`"")){
			Write-Verbose "Installing VMware Tools"
			Write-Debug "Run-Exe $InstallerPath (`"/S`" `"/v`" `"`"/qn REBOOT=ReallySuppress`"`")"
			Run-Exe $InstallerPath ("/S","/v","`"/qn REBOOT=R`"")

			if($LastExitCode -notin $exitCodesIgnore){
				throw [System.Exception] "Return Code: $LastExitCode`n`nExec: $ErrorMessage`n`nOutput: $cmdOutput"		
			}
			# Signifies reboot required
			#$global:DSCMachineStatus = 1
		}
	} elseif ($Ensure -eq "Absent" -and (VMwareToolsInstalled) -eq $true) {
		try {
            Get-WmiObject -Class Win32_Product | Where-Object {$_.Name -eq "VMware Tools"} | foreach-object -process {$_.Uninstall()}
        } catch {
        }
	} else {
		Write-Verbose "Nothing to do in Set-TargetResource"
	}
}


function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [parameter(Mandatory = $true)]
        [System.String]
        $InstallerPath
    )
    Write-Debug "Call to Test-TargetResource"
    Write-Verbose "Checking whether host is a VMware/ESXi"
    Write-Debug "if(IsHostESXi)"
    if((IsHostESXi)){
		Write-Verbose "Host is VMware/ESXi - proceed to next check"
	} else {
		Write-Verbose "Host is not VMware/ESXi. Terminate here"
        return $True
	}
    $ErrorActionPreference = "Stop" 
	Write-Verbose "Checking whether VMware Tools is installed"
	Write-Debug "if(((Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |  Where-Object { `$_.DisplayName -eq `"VMware Tools`" })))"
	if(VMwareToolsInstalled){
		Write-Verbose "VMware Tools already installed"
        $returnValue = ($true -eq ($Ensure -eq "Present"))		
	} else {
		Write-Verbose "VMware Tools not installed"	
        Write-Debug "`$returnValue = (`$false -eq (`$Ensure -eq `"Present`"))"
        Write-Debug "`$returnValue = ($false -eq ($Ensure -eq `"Present`"))"			
        $returnValue = ($false -eq ($Ensure -eq "Present"))
        Write-Debug "}"
	}
    Write-Debug "return `$returnValue"
    Write-Debug "return $returnValue"
    return $returnValue	
    Write-Debug "} # End Test-TargetResource"
}


Export-ModuleMember -Function *-TargetResource

