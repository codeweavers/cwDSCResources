function Get-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$Name
	)
	
	$returnValue = @{
		Name = [System.String]
	}
	$returnValue
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
		$Name
	)

	#Write-Verbose "Use this cmdlet to deliver information about command processing."

	#Write-Debug "Use this cmdlet to write debug information while troubleshooting."

	#Include this line if the resource requires a system reboot.
	#$global:DSCMachineStatus = 1

    Write-Verbose "Get-Service -Name $Name | Restart-Service"
    Get-Service -Name $Name | Restart-Service
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
		$Name
	)

	#Write-Verbose "Use this cmdlet to deliver information about command processing."

	#Write-Debug "Use this cmdlet to write debug information while troubleshooting."


	$result = $false
	$result

}


Export-ModuleMember -Function *-TargetResource

