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
	Whether to display the extracted text in the console.
	
	.PARAMETER OutputFile
	The output file to write the book to.
	
	.PARAMETER PinyinAboveHanzi
	Whether pinyin should be displayed above hanzi, per line.
	
	.PARAMETER PinyinBelowHanzi
	Whether pinyin should be displayed below hanzi, per line.
	
	.PARAMETER PinyinBlockAboveHanzi
	Whether pinyin should be displayed as a separate block above hanzi.
	
	.PARAMETER PinyinBlockBelowHanzi
	Whether pinyin should be displayed as a separate block below hanzi.
	
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
param (	[Parameter(Mandatory, ValueFromPipeline)] 				[array]     $Text,
		[Parameter()]											[string]    $OutputFile,
		[Parameter()]											[switch]    $Display,
		[Parameter()]											[switch]    $PinyinAboveHanzi,
		[Parameter()]											[switch]    $PinyinBelowHanzi,
		[Parameter()]											[switch]    $PinyinBlockAboveHanzi,
		[Parameter()]											[switch]    $PinyinBlockBelowHanzi
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
	function Is-Hanzi {
		param (
			[char]$Character
		)

		$hanziStart = [int][char]'一'  # Unicode 4E00
		$hanziEnd = [int][char]'龥'    # Unicode 9FFF

		$charCode = [int]$Character

		return $charCode -ge $hanziStart -and $charCode -le $hanziEnd
	}

	try
	{
		$isDebug = Assert-Debug
		$IncludePinyin = $PinyinAboveHanzi -or $PinyinBelowHanzi -or $PinyinBlockAboveHanzi -or $PinyinBlockBelowHanzi
		$pinyin = @()
		
		if(Test-Path -Path $OutputFile) {
			Remove-Item $OutputFile -Force
		}
		
		if($IncludePinyin) {
			$outputFormat = New-Object pinyin4net.Format.HanyuPinyinOutputFormat
			$outputFormat.ToneType = [pinyin4net.Format.HanyuPinyinToneType]::WITH_TONE_MARK
			$outputFormat.VCharType = [pinyin4net.Format.HanyuPinyinVCharType]::WITH_U_UNICODE

			foreach ($line in $Text.Chinese) {
				$tempLine = [string]::Join("", $line)
				$pinyinLine = @()
				
				foreach($ch in $line)
				{
					if(Is-Hanzi $ch) {
						$pinyinLine += [pinyin4net.PinyinHelper]::ToHanyuPinyinStringArray($ch, $outputFormat)
					}
					else {
						[string]$tempChar = $ch
						$tempChar = $tempChar.Replace("。", ".")
						$tempChar = $tempChar.Replace("，", ",")
						$tempChar = $tempChar.Replace("：", ":")
						$tempChar = $tempChar.Replace("！", "!")
						$tempChar = $tempChar.Replace("？", "?")
						$tempChar = $tempChar.Replace("」", """")
						$tempChar = $tempChar.Replace("﹁", "'")
						$tempChar = $tempChar.Replace("﹂", "'")
						$tempChar = $tempChar.Replace("……", "…")
						$tempChar = $tempChar.Replace("《", """")
						$tempChar = $tempChar.Replace("》", """")
						
						$pinyinLine += $tempChar
					}
				}

				$pinyin += ,$pinyinLine
			}
					
			foreach ($line in $pinyin) {
				$outLine = ""
				
				foreach($ch in $line) {
					$outLine += $ch
				}
				
				if($Display) {
					Write-Host $outLine
				}
		
				if($OutputFile) {
					$outLine | Out-File -Append $OutputFile
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