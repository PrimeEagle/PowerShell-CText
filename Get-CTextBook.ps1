<#
	.SYNOPSIS
	Renames all unprocessed music directories.
	
	.DESCRIPTION
	Renames all unprocessed music directories.

	.INPUTS
	None.

	.OUTPUTS
	None.

	.PARAMETER BookTag
	The identifier tag for the book on ctext.org.
	
	.PARAMETER Display
	Whetehr to display the extracted text in the console.
	
	.PARAMETER OutputFile
	The output file to write the book to.
	
	.EXAMPLE
	PS> .\Get-CTextBook.ps1 -BookTag zhuangzi -OutputFile "D:\book.txt"
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
param (	[Parameter(Mandatory)] 				[string]$BookTag,
		[Parameter()]						[string]$OutputFile,
		[Parameter()]						[switch]$Display
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
	
	Add-NuGetType -PackageName "HtmlAgilityPack" -Subdirectory "netstandard2.0"
}

Process
{
	try
	{
		$isDebug = Assert-Debug
		
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
								$chapterUrls[$fullUrl.AbsoluteUri] = @()
								Get-ChapterUrls -url $fullUrl.AbsoluteUri -chapterUrls $chapterUrls
							}
						}
					}
				}
			}
		}
		
		function Get-ChapterTexts {
			param(
				[Parameter()]		[System.Collections.Specialized.OrderedDictionary]$ChapterUrls,
				[Parameter()]		[string] $ChineseClass,
				[Parameter()]		[string] $EnglishClass
			)
				
			$resultDataChinese = @()
			$resultDataEnglish = @()
						
			foreach ($cu in $ChapterUrls.Keys) {
				if($cu.EndsWith("/zh"))
				{
					$url = $cu.Substring(0, $cu.Length - 3)
				}
				else
				{
					$url = $cu
				}
				
				$result = Invoke-WebRequest -Uri $url -AllowInsecureRedirect
				$htmlDoc = New-Object HtmlAgilityPack.HtmlDocument
				$htmlDoc.LoadHtml($result.Content)
				
				$tdNodesChinese = $htmlDoc.DocumentNode.SelectNodes("//div[@class = 'text']//td[contains(concat(' ', normalize-space(@class), ' '), ' $chineseClass ')]")
				
				foreach ($td in $tdNodesChinese) {
					$line = ($td.InnerText -replace '\s+', ' ').Trim()
					
					if (-Not [string]::IsNullOrWhiteSpace($line)) {
						$lineArray = $line.ToCharArray()
						$resultDataChinese += ,($lineArray)
					}
				}
				
				$tdNodesEnglish = $htmlDoc.DocumentNode.SelectNodes("//div[@class = 'text']//td[@class = '$englishClass']")
				foreach ($td in $tdNodesEnglish) {
					$tempDoc = New-Object HtmlAgilityPack.HtmlDocument
					$tempDoc.LoadHtml($td.InnerHtml)

					$unwantedNodes = $tempDoc.DocumentNode.SelectNodes(".//span | .//a | .//p")
					if ($unwantedNodes -ne $null) {
						foreach ($node in $unwantedNodes) {
							$node.ParentNode.RemoveChild($node, $false)
						}
					}
					$htmlString = $tempDoc.DocumentNode.InnerHtml
					$lines = $htmlString -split '<br\s*/?>'

					foreach ($line in $lines) {
						$lineDoc = New-Object HtmlAgilityPack.HtmlDocument
						$lineDoc.LoadHtml($line)
						
						$cleanText = $lineDoc.DocumentNode.InnerText.Trim()

						if (-Not [string]::IsNullOrWhiteSpace($cleanText)) {
							$resultDataEnglish += $cleanText
						}
					}
				}
			}
			
			$resultData = [PSCustomObject]@{
				Chinese = $resultDataChinese
				English = $resultDataEnglish
			}
			
			return $resultData
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
		$chapterUrls = [ordered]@{}
		Get-ChapterUrls -url "$bookUrl/zh" -chapterUrls $chapterUrls
		$text = Get-ChapterTexts -ChapterUrls $chapterUrls -ChineseClass "ctext" -EnglishClass "etext"
		
		if(Test-Path -Path $OutputFile) {
			Remove-Item $OutputFile -Force
		}
			
		foreach($lineArray in $text.Chinese) {
			$outLine = [string]::Join("", $lineArray)

			if($Display) {
				Write-Host $outLine
			}
			
			if($OutputFile) {
				$outLine | Out-File -Append $OutputFile
			}
		}
		
		foreach($line in $text.English) {
			if($Display) {
				Write-Host $line
			}
			
			if($OutputFile) {
				$line | Out-File -Append $OutputFile
			}
		}

		if ($PSCmdlet.MyInvocation.PipelinePosition -ne $PSCmdlet.MyInvocation.PipelineLength) {
            ,($text)
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