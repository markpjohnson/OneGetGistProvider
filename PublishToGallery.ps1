
$p = @{
    Name = "GistProvider"
    NuGetApiKey = $NuGetApiKey 
    LicenseUri = "https://github.com/markpjohnson/OneGetGistProvider/blob/master/LICENSE" 
    Tag = "Gist","Github","PackageManagement","Provider"
    ReleaseNote = "Updated to work with rename to PackageManagement"
    ProjectUri = "https://github.com/markpjohnson/OneGetGistProvider"
}

Publish-Module @p
