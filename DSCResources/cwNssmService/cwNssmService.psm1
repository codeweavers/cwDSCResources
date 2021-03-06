function Get-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$ServiceName,
		[parameter(Mandatory = $true)]
		[System.String]
		$NssmPath
	)
	
	$ensureResult = "Absent"
    Write-Verbose "Verbose: Checking $NssmPath"
    Write-Debug "Debug: Test-Path -Path $NssmPath"
    $nssmInstalled = Test-Path -Path $NssmPath
    if($nssmInstalled){
        Write-Verbose "Verbose: $NssmPath is installed - retrieving details"

		$_ErrorActionPreference = $ErrorActionPreference ; $ErrorActionPreference = "SilentlyContinue"

        Write-Debug "Debug: GetPath: & $NssmPath get $ServiceName Application"
        $ServicePath =& $NssmPath get $ServiceName Application
        Write-Debug "Debug: GetArgs: & $NssmPath get $ServiceName AppParameters"
        $ServiceAdditionalArgs = & $NssmPath get $ServiceName AppParameters
        Write-Debug "Debug: GetStartCondition: & $NssmPath get `"$ServiceName`" Start"
        $ServiceStartCondition = & $NssmPath get "$ServiceName" Start
        Write-Debug "Debug: GetStopAction: & $NssmPath set `"$ServiceName`" Appexit Default"
        $ServiceStopAction = & $NssmPath get "$ServiceName" Appexit Default

		if (((& $NssmPath get "$ServiceName" Start) -eq $ServiceStartCondition) -and`
		                                ((& $NssmPath get "$ServiceName" Appexit Default) -eq $ServiceStopAction)) {
			$ensureResult = "Present"
		}

		Write-Debug "Debug: ErrorActionPreference = $_ErrorActionPreference"
		$ErrorActionPreference = $_ErrorActionPreference
    } else {
        Write-Verbose "Verbose: $NssmPath is not installed"
    }
    Write-Debug "Debug: Set return value"
	$returnValue = @{
		ServiceName = $ServiceName
		ServicePath = $ServicePath
		ServiceAdditionalArgs = $ServiceAdditionalArgs
		ServiceStartCondition = $ServiceStartCondition
		ServiceStopAction = $ServiceStopAction
		NssmPath = $NssmPath
		Ensure = $ensureResult
	}
	$returnValue
}

function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$ServiceName,
		[System.String]
		$ServicePath,
		[System.String]
		$ServiceAdditionalArgs,
		[System.String]
		$ServiceStartCondition,
		[System.String]
		$ServiceStopAction,
		[parameter(Mandatory = $true)]
		[System.String]
		$NssmPath,
		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure
	)
    Write-Verbose "Verbose: Checking $NssmPath"
    Write-Debug "Debug: Test-Path -Path $NssmPath"
    $nssmInstalled = Test-Path -Path $NssmPath
    if(!$nssmInstalled) {
        Write-Verbose "Verbose: $NssmPath is not installed"
        Write-Debug "Debug: Throwing Exception"
		throw [System.IO.FileNotFoundException]"$NssmPath not found. Hint: Use File resource to copy NSSM to appropriate location on target host"
    }
    Write-Verbose "Verbose: Remove $ServiceName Service - ignore any errors"
    if($PSCmdlet.ShouldProcess("Removing existing installation of $ServiceName")){
        Write-Debug "Debug: ErrorActionPreference = `"SilentlyContinue`""
        $_ErrorActionPreference = $ErrorActionPreference ; $ErrorActionPreference = "SilentlyContinue"
        Write-Debug "Debug: & $NssmPath remove `"$ServiceName`" confirm"
        & $NssmPath remove "$ServiceName" confirm
        Write-Debug "Debug: ErrorActionPreference = $_ErrorActionPreference"
        $ErrorActionPreference = $_ErrorActionPreference
    }
    Write-Verbose "Verbose: Testing `"Ensure`" property: $Ensure"
    if($Ensure -eq "Present") {
        Write-Verbose "Verbose: Property `"Ensure`" equals `"Present`"; Proceed with installation/configuration"
        if($PSCmdlet.ShouldProcess("Installing $ServiceName")){
            Write-Debug "Debug: & $NssmPath install `"$ServiceName`" `"$ServicePath`" $ServiceAdditionalArgs"
	        & $NssmPath install "$ServiceName" "$ServicePath" $ServiceAdditionalArgs    
            if($LastExitCode -ne 0){
                Write-Debug "Debug: LastExitCode not 0: $LastExitCode`nDebug: Throwing Exception"
                throw [System.Exception]"Return Code: $LastExitCode `n Failed Nssm Service Install"
            }
        }
        if($PSCmdlet.ShouldProcess("Applying the Start Condition `"$ServiceStartCondition`" to $ServiceName")){
            Write-Debug "Debug: & $NssmPath set `"$ServiceName`" Start $ServiceStartCondition"
	        & $NssmPath set "$ServiceName" Start $ServiceStartCondition
            if($LastExitCode -ne 0){
                Write-Debug "Debug: LastExitCode not 0: $LastExitCode`nDebug: Throwing Exception"
                throw [System.Exception]"Return Code: $LastExitCode `n Failed Nssm Set Parameter"
            }
        }
        if($PSCmdlet.ShouldProcess("Applying the Service Stop Action `"$ServiceStopAction`" to $ServiceName")){
            Write-Debug "Debug: & $NssmPath set `"$ServiceName`" Appexit Default $ServiceStopAction"
	        & $NssmPath set "$ServiceName" Appexit Default $ServiceStopAction
            if($LastExitCode -ne 0){
                Write-Debug "Debug: LastExitCode not 0: $LastExitCode`nDebug: Throwing Exception"
                throw [System.Exception]"Return Code: $LastExitCode `n Failed Nssm Set Parameter"
            }
        }
    } else {
        Write-Verbose "Verbose: Property `"Ensure`" equals `"Absent`"; No further work to do"
    }
	#Include this line if the resource requires a system reboot.
	#$global:DSCMachineStatus = 1
}

function Test-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$ServiceName,
		[System.String]
		$ServicePath,
		[System.String]
		$ServiceAdditionalArgs,
		[System.String]
		$ServiceStartCondition,
		[System.String]
		$ServiceStopAction,
		[parameter(Mandatory = $true)]
		[System.String]
		$NssmPath,
		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure
	)
    Write-Verbose "Verbose: Checking path $NssmPath"
    Write-Debug "Debug: Test-Path -Path $NssmPath"
    $nssmInstalled = Test-Path -Path $NssmPath
    if($nssmInstalled) {
        Write-Verbose "Verbose: $NssmPath is installed - proceed to next check"
    } else {
        Write-Verbose "Verbose: $NssmPath is not installed. Terminate here"
        $returnValue = ($false -eq ($Ensure -eq "Present"))
        return $returnValue         
    }

    Write-Verbose "Verbose: Checking whether $ServiceName is installed and configured with correct start condition/stop action"
    Write-Debug "Debug: ErrorActionPreference = `"SilentlyContinue`""
    $_ErrorActionPreference = $ErrorActionPreference ; $ErrorActionPreference = "SilentlyContinue"
          Write-Debug "Debug: if(((& $NssmPath get `"$ServiceName`" Start) -eq $ServiceStartCondition) -and`n`t((& $NssmPath get `"$ServiceName`" Appexit Default) -eq $ServiceStopAction))"

    $serviceInstalledConfigged = ((& $NssmPath get "$ServiceName" Start) -eq $ServiceStartCondition) -and`
		                                ((& $NssmPath get "$ServiceName" Appexit Default) -eq $ServiceStopAction)

    Write-Debug "Debug: ErrorActionPreference = $_ErrorActionPreference"
    $ErrorActionPreference = $_ErrorActionPreference

    if($serviceInstalledConfigged) {
        Write-Verbose "Verbose: $ServiceName is installed and correctly configured"
        $returnValue = ($true -eq ($Ensure -eq "Present")) 
    } else {
        Write-Verbose "Verbose: $ServiceName is either not installed or incorrectly configured"
        $returnValue = ($false -eq ($Ensure -eq "Present")) 
    }
    Write-Verbose "Verbose: Returning $returnValue"
    return $returnValue
}
Export-ModuleMember -Function *-TargetResource