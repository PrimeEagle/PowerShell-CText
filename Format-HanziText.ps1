<#
	.SYNOPSIS
	Renames all unprocessed music directories.
	
	.DESCRIPTION
	Renames all unprocessed music directories.

	.INPUTS
	None.

	.OUTPUTS
	None.

	.PARAMETER ChineseText
	The input Chinese text as hanzi characters.
	
	.PARAMETER Display
	Whetehr to display the extracted text in the console.
	
	.PARAMETER OutputFile
	The output file to write the book to.
	
	.PARAMETER IncludePinyin
	Whether to include pinyin in the output.
	
	.EXAMPLE
	PS> .\Format-HanziText.ps1 -ChineseText "北冥有魚，其名為鯤" -OutputFile "D:\book.txt"
#>

<#
	.BASEPARAMETERS HelpFull, HelpDetail, HelpSynopsis, Silent, Testing, DrivePreset, DriveLetter, DriveLabel, Path
	
	.COMMONPARAMETERS 
	
	.TODO
#>
#Requires -Version 5.0
#Requires -Modules Varan.PowerShell.Base
#Requires -Modules Varan.PowerShell.Common
#Requires -Modules Varan.PowerShell.Music
#Requires -Modules Varan.PowerShell.PerformanceTimer
#Requires -Modules Varan.PowerShell.Validation
#Requires -Modules Varan.PowerShell.Summary
using module Varan.PowerShell.Validation
using module Varan.PowerShell.Music
using module Varan.PowerShell.PerformanceTimer
using module Varan.PowerShell.Summary
# ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
param (	[Parameter(Mandatory, ValueFromPipeline)] 				[string[]]$ChineseText,
		[Parameter()]											[string]  $OutputFile,
		[Parameter()]											[switch]  $Display,
		[Parameter()]											[switch]  $IncludePinyin
	  )
DynamicParam { Build-BaseParameters -IncludeMusicPathQueues }


Begin
{	
	Write-LogTrace "Execute: $(Get-RootScriptName)"
	$minParams = Get-MinimumRequiredParameterCount -CommandInfo (Get-Command $MyInvocation.MyCommand.Name)
	$cmd = @{}

	if(Get-BaseParamHelpFull) { $cmd.HelpFull = $true }
	if((Get-BaseParamHelpDetail) -Or ($PSBoundParameters.Count -lt $minParams)) { $cmd.HelpDetail = $true }
	if(Get-BaseParamHelpSynopsis) { $cmd.HelpSynopsis = $true }
	
	if($cmd.Count -gt 1) { Write-DisplayHelp -Name "$(Get-RootScriptPath)" -HelpDetail }
	if($cmd.Count -eq 1) { Write-DisplayHelp -Name "$(Get-RootScriptPath)" @cmd }
	
	Add-NuGetType -PackageName "Pinyin4net"
}

Process
{
	try
	{
		$isDebug = Assert-Debug
		$result = @()
		
		if(Test-Path -Path $OutputFile) {
			Remove-Item $OutputFile -Force
		}
			
		if($IncludePinyin) {
			$outputFormat = New-Object pinyin4net.Format.HanyuPinyinOutputFormat
			$outputFormat.ToneType = [pinyin4net.Format.HanyuPinyinToneType]::WITH_TONE_MARK
			$outputFormat.VCharType = [pinyin4net.Format.HanyuPinyinVCharType]::WITH_U_UNICODE

			foreach ($line in $ChineseText) {
				Write-Host "processing $line"
				$pinyinLine = ""
				
				foreach($ch in $line.ToCharArray())
				{
					$pinyinLine += [pinyin4net.PinyinHelper]::ToHanyuPinyinStringArray($ch, $outputFormat)
				}
				
				if($Display) {
					Write-Host $pinyinLine
				}
		
				if($OutputFile) {
					$pinyinLine | Out-File -Append $OutputFile
				}
			}
		}
	}
	catch [System.Exception]
	{
		Write-DisplayError $PSItem.ToString() -Exit
	}
}
End
{
	Write-DisplayHost "Done." -Style Done
}