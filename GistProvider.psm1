$Providername = "Gist"
$GistPath     = "$env:LOCALAPPDATA\OneGet\Gist"
$CSVFilename  = "$($GistPath)\OneGetData.csv"

function Get-GistAuthHeader {
    param(
    	[pscredential]$Credential
    )    

    $authInfo = "{0}:{1}" -f $Credential.UserName, $Credential.GetNetworkCredential().Password
    $authInfo = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($authInfo))

    @{
		"Authorization" = "Basic " + $authInfo
		"Content-Type" = "application/json"
    }
}

function Initialize-Provider     { write-debug "In $($Providername) - Initialize-Provider" }
function Get-PackageProviderName { return $Providername }

function Resolve-PackageSource { 
    write-debug "In $($ProviderName)- Resolve-PackageSources"    
    
    $IsTrusted    = $false
    $IsRegistered = $false
    $IsValidated  = $true
    
    foreach($Name in @($request.PackageSources)) {
    	$Location = "https://api.github.com/users/$($Name)/gists"
    	
    	write-debug "In $($ProviderName)- Resolve-PackageSources gist: {0}" $Location
    	
    	New-PackageSource $Name $Location $IsTrusted $IsRegistered $IsValidated
    }        
}

function Find-Package { 
    param(
        [string[]] $names,
        [string] $requiredVersion,
        [string] $minimumVersion,
        [string] $maximumVersion
    )

	write-debug "In $($ProviderName)- Find-Package"
	
	ForEach ($Name in @($request.PackageSources)) {
	    write-debug "In $($ProviderName)- Find-Package for user {0}" $Name
	    
	    if ($request.Credential) { $Header = (Get-GistAuthHeader $request.Credential) }
	    
	    #write-debug "In $($ProviderName)- Find-Package {0}" $(help New-SoftwareIdentity | out-string)
	    ForEach ($gist in (Invoke-RestMethod "https://api.github.com/users/$($Name)/gists" -Header $Header)) {
	    	if ($request.IsCancelled) { break }
	        
	        $gistName = $gist.description.ToString()
	        $files = $gist.files | ConvertTo-HashTable
	        $rawUrl = $gist.url
	        $searchKey = $gistName
	        if ($files.Count -eq 1) { 
	        	$gistName = ($gist.files| Get-Member -MemberType NoteProperty).Name 
	        	$searchKey = $gistName.split('.')[0]
	        }
	        
	        write-debug "In $($ProviderName)- Find-Package found Gist {0}" $gistName
	        
	        if ($rawUrl -And ($gistName -match $names)) {
	            $SWID = @{
	                version              = "1.0"
	                versionScheme        = "semver"
	                fastPackageReference = $gist.url
	                name                 = $gistName
	                source               = "Gist/$($Name)"
	                summary              = ($gist.description).tostring()
	                searchKey            = $gistName
	            }
	            
	            $SWID.fastPackageReference = $SWID | ConvertTo-JSON -Compress
	            New-SoftwareIdentity @SWID
	        }
	    }
	}
}

function Install-Package { 
    param(
        [string] $fastPackageReference
    )   	
    
    $swid = ($fastPackageReference | ConvertFrom-Json)
    $rawUrl = $swid.fastpackagereference
	
	write-debug "In $($ProviderName) - Install-Package - {0}" $rawUrl
	
	if (!(Test-Path $GistPath)) { md $GistPath | Out-Null }	
	
	# $psFileName = Split-Path -Leaf $rawUrl
	$dirName = $swid.name -replace ' ','_'
	$targetDir = "$($GistPath)\$($dirName)"
	if (!(Test-Path $targetDir)) { md $targetDir | Out-Null }
	
	write-verbose "Package install location {0}" $targetDir
	$gist = (Invoke-RestMethod $rawUrl)
	$files = ($gist.files | ConvertTo-HashTable)
	foreach ($filename in $files.Keys) {
		$file = $files.$($filename)
		$targetOut = "$($targetDir)\$($filename)"
		$file.content | Set-Content -Encoding Ascii $targetOut
	}
	
	## Update the catalog of gists installed	
	$swid | Export-Csv -Path $CSVFilename -Append -NoTypeInformation -Encoding ASCII -Force
}

function ConvertTo-HashTable {
    param(
        [Parameter(ValueFromPipeline)]
        $Data
    )

    process {
        if(!$Fields) {            
            $Fields=($Data|Get-Member -MemberType NoteProperty ).Name
        }
        
        $h=[Ordered]@{}
        foreach ($Field in $Fields)
        {
            $h.$Field = $Data.$Field                        
        }
        $h
    }
}

function Get-InstalledPackage {
    param()

    if(Test-Path $CSVFilename) {
        $installedPackages = Import-Csv $CSVFilename
        
        write-debug "In $($ProviderName) - Get-InstalledPackage {0}" @($installedPackages).Count   
        
        foreach ($item in ($installedPackages | ConvertTo-HashTable))
        {    
            New-SoftwareIdentity @item
        }
    }
}
