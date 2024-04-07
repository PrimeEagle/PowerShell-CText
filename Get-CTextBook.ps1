<#
	.SYNOPSIS
	Renames all unprocessed music directories.
	
	.DESCRIPTION
	Renames all unprocessed music directories.

	.INPUTS
	None.

	.OUTPUTS
	None.

	.EXAMPLE
	PS> .\Get-CTextBook.ps1 -Path "D:\temp\"
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
param (	[Parameter()]
			[string]		$BookTag,
			[string]		$OutputFile,
			[switch]		$IncludeChineseHanzi,
			[switch]		$IncludeChinesePinyin,
			[switch]		$IncludeEnglishCText,
			[switch]		$IncludeEnglishDeepL
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
	
	
	$installedPackages = Get-Package | Out-String
	$htmlAgilityPackInstalled = $installedPackages -match 'HtmlAgilityPack'

	if (-Not $htmlAgilityPackInstalled) {
		Write-Host "HtmlAgilityPack does not exist"

		if ((Get-PackageSource).Name -contains 'NuGet') {
			Write-Host "Installing HtmlAgilityPack..."

			nuget install "HtmlAgilityPack"
		} else {
			Write-Host "NuGet is required to install HtmlAgilityPack, but it is not installed."
			exit
		}
	}

	$htmlAgilityPackDll = Get-ChildItem -Path $nugetPackageDir -Filter "HtmlAgilityPack.dll" -Recurse | Select-Object -First 1
	if ($htmlAgilityPackDll) {
		Add-Type -Path $htmlAgilityPackDll.FullName
	} else {
		Write-Host "HtmlAgilityPack could not be loaded."
		exit
	}
}

Process
{
	try
	{
		if(-Not (Assert-PathQueueParameter))
		{
			Write-DisplayHelp -Name "$(Get-RootScriptPath)" -HelpDetail
		}
		
		function Get-ChapterUrls {
			param(
				[string]$url,
				[System.Collections.Specialized.OrderedDictionary]$chapterUrls
			)

			$result = Invoke-WebRequest -Uri $url -AllowInsecureRedirect
			$htmlDoc = New-Object HtmlAgilityPack.HtmlDocument
			$htmlDoc.LoadHtml($result.Content)

			$contentDiv = $htmlDoc.DocumentNode.SelectSingleNode("//div[@id='content2']")
			if ($contentDiv) {
				$anchorTags = $contentDiv.SelectNodes(".//a")
				foreach ($anchor in $anchorTags) {
					$href = $anchor.GetAttributeValue("href", [System.String]::Empty)

					if (-not [string]::IsNullOrEmpty($href) -and -not $href.EndsWith("#") -and -not ($href.Contains(".pl")) -and -not ($href.Contains("tools")) -and -not ($href.Contains("faq"))) {
						$hrefUri = New-Object System.Uri($href, [System.UriKind]::RelativeOrAbsolute)
						$fullUrl = $hrefUri.IsAbsoluteUri ? $hrefUri : (New-Object System.Uri([System.Uri]$baseUrl, $hrefUri))

						if (-not $chapterUrls.Contains($fullUrl.AbsoluteUri)) {
							$chapterTopLevel = Get-TopLevelFolder $fullUrl.AbsoluteUri
							if ($chapterTopLevel -eq $bookTopLevel) {
								$chapterUrls[$fullUrl.AbsoluteUri] = ""
								Get-ChapterUrls -url $fullUrl.AbsoluteUri -chapterUrls $chapterUrls
							}
						}
					}
				}
			}
		}
		
		function Get-ChapterTexts {
			 param(
				[System.Collections.Specialized.OrderedDictionary]$chapterUrls,
				[string] $textClass
			)
			
			$tempChapterUrls = [ordered]@{}
			foreach($cu in $chapterUrls.Keys) {
				$result = Invoke-WebRequest -Uri $cu -AllowInsecureRedirect
				$htmlDoc = New-Object HtmlAgilityPack.HtmlDocument
				$htmlDoc.LoadHtml($result.Content)
				$tempChapterUrls[$cu] = ""
				
				$tdNodes = $htmlDoc.DocumentNode.SelectNodes("//td[@class='$textClass']")
				
				foreach($td in $tdNodes) {
					$tempChapterUrls[$cu] += $td.InnerText
				}
			}
			
			return $tempChapterUrls
		}
		
		function Get-TopLevelFolder {
			param([string]$url)

			$uri = New-Object System.Uri($url)
			$pathSegments = $uri.AbsolutePath.Trim('/').Split('/')

			if ($pathSegments.Length -gt 0) {
				return $pathSegments[0]
			}

			return $null
		}

		$ProgressPreference = 'SilentlyContinue'
		$baseUrl = "https://ctext.org"
		$bookUrl = "$baseUrl/$BookTag"
		$bookTopLevel = Get-TopLevelFolder $bookUrl

		if($IncludeChineseHanzi) {
			$chapterUrls = [ordered]@{}
			Get-ChapterUrls -url "$bookUrl/zh" -chapterUrls $chapterUrls
			$result = Get-ChapterTexts  $chapterUrls "ctext"

			$hanziOutput = foreach ($url in $result.Keys) { Write-Output $result[$url] }
			
		}
		
		if($IncludeChinesePinyin) {
			$chapterUrls = [ordered]@{}
			Get-ChapterUrls -url "$bookUrl/zh" -chapterUrls $chapterUrls
			$result = Get-ChapterTexts  $chapterUrls "ctext"



			$pinyinOutput = foreach ($url in $result.Keys) { 
				$chineseText = $result[$url]
				$url = "https://translate.google.com/#view=home&op=translate&sl=zh-CN&tl=en&text=$chineseText"
				$response = Invoke-WebRequest -Uri $url
				$doc = New-Object HtmlAgilityPack.HtmlDocument
				$doc.LoadHtml($response)

				$node = $doc.DocumentNode.SelectSingleNode("//span[@jsname='toZopb']")

				$pinyinText = $node.InnerText			

				Write-Output $pinyinText 
			}
			
		}
		
		if($IncludeEnglishCText) {
			$chapterUrls = [ordered]@{}
			Get-ChapterUrls -url $bookUrl -chapterUrls $chapterUrls "etext"
			$result = Get-ChapterTexts  $chapterUrls

			$englishCTextOutput = foreach ($url in $result.Keys) { Write-Output $result[$url] }
			
		}
		
		if($IncludeEnglishDeepL) {
			$chapterUrls = [ordered]@{}
			Get-ChapterUrls -url "$bookUrl/zh" -chapterUrls $chapterUrls
			$result = Get-ChapterTexts  $chapterUrls "ctext"

			$englishDeepLOutput = foreach ($url in $result.Keys) { Write-Output $result[$url] }
			
		}
		
		($hanziOutput + $pinyinOutput + $englishCTextOutput + $englishDeepLOutput) | Out-File $OutputFile
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