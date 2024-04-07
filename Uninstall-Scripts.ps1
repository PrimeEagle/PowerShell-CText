<#
	.SYNOPSIS
	Uninstalls prerequisites for scripts.
	
	.DESCRIPTION
	Uninstalls prerequisites for scripts.

	.INPUTS
	None.

	.OUTPUTS
	None.

	.EXAMPLE
	PS> .\Uninstall-Scripts
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
		Write-Host "Uninstallation must be run from the same directory as the uninstaller script."
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

	Remove-ImportModuleFromProfile -PathVariable 'Path' -Path (Get-Location).Path
	Remove-ImportModuleFromProfile -PathVariable 'Path' -Path 'C:\Program Files\7-Zip'
	Remove-ImportModuleFromProfile -PathVariable 'PSModulePath' -Path $ModulesPath
	
	Add-ImportModuleToProfile "Varan.PowerShell.Base"
	Add-ImportModuleToProfile "Varan.PowerShell.Common"
	
	Remove-AliasFromProfile -Script 'Get-CTextHelp' -Alias 'cthelp'
	Remove-AliasFromProfile -Script 'Get-CTextHelp' -Alias 'gcth'
	Remove-AliasFromProfile -Script 'Get-CTextScriptVersion' -Alias 'gctsv'
	Remove-AliasFromProfile -Script 'Get-CTextScriptVersion' -Alias 'ctgv'
	Remove-AliasFromProfile -Script 'Get-CTextBook' -Alias 'gctb'
	Remove-AliasFromProfile -Script 'Get-CTextBook' -Alias 'ctgb'
	
	Remove-LineFromProfile -Text '$ConfirmPreference = ''None'''
}

End
{
	Format-Profile
	Complete-Install
}