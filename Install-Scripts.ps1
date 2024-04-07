<#
	.SYNOPSIS
	Installs prerequisites for scripts.
	
	.DESCRIPTION
	Installs prerequisites for scripts.

	.INPUTS
	None.

	.OUTPUTS
	None.

	.EXAMPLE
	PS> .\Install-Scripts
#>
# ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#Requires -Version 5.0
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param ([Parameter()] [switch] $UpdateHelp,
	   [Parameter(Mandatory = $true)] [string] $ModulesPath)

Begin
{
	$script = $MyInvocation.MyCommand.Name
	if(-Not (Test-Path ".\$script"))
	{
		Write-Host "Installation must be run from the same directory as the installer script."
		exit
	}

	if(-Not (Test-Path $ModulesPath))
	{
		Write-Host "'$ModulesPath' was not found."
		exit
	}

	$Env:PSModulePath += ";$ModulesPath"
	
	if (-Not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
		Start-Process -FilePath "pwsh.exe" -ArgumentList "-File `"$PSCommandPath`"", "-ModulesPath `"$ModulesPath`"" -Verb RunAs
		exit
	}
}

Process
{
	Import-LocalModule "Varan.PowerShell.Base"
	Import-LocalModule "Varan.PowerShell.Common"

	Add-PathToProfile -PathVariable 'Path' -Path (Get-Location).Path
	Add-PathToProfile -PathVariable 'Path' -Path 'C:\Program Files\7-Zip'
	Add-PathToProfile -PathVariable 'PSModulePath' -Path $ModulesPath
	
	Add-ImportModuleToProfile "Varan.PowerShell.Base"
	Add-ImportModuleToProfile "Varan.PowerShell.Common"
	
	Add-AliasToProfile -Script 'Get-CTextHelp' -Alias 'cthelp'
	Add-AliasToProfile -Script 'Get-CTextHelp' -Alias 'gcth'
	Add-AliasToProfile -Script 'Get-CTextScriptVersion' -Alias 'gctsv'
	Add-AliasToProfile -Script 'Get-CTextScriptVersion' -Alias 'ctgv'
	Add-AliasToProfile -Script 'Get-CTextBook' -Alias 'gctb'
	Add-AliasToProfile -Script 'Get-CTextBook' -Alias 'ctgb'
	
	Add-LineToProfile -Text '$ConfirmPreference = ''None'''
}

End
{
	Format-Profile
	Complete-Install
}