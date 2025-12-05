<#
.SYNOPSIS
    PowerShell script to resign packages using smc.exe
.DESCRIPTION
    This script automatically resigns all packages in the current directory using the specified private key.
    It processes directories with the structure: package/os/arch/ver
.PARAMETER Help
    Shows this help message and exits.
.PARAMETER Key
    Specifies the path to the private key file (default: costrict-private.pem in script directory).
.PARAMETER Defs
    Specifies the path to the package-defs.json file (default: package-defs.json in script directory).
.PARAMETER Smc
    Specifies the path to the smc.exe file (default: smc.exe in script directory).
.EXAMPLE
    .\resign-packages.ps1
    Resigns all packages using default settings.
.EXAMPLE
    .\resign-packages.ps1 -Key "custom.pem" -Defs "custom-defs.json"
    Resigns all packages using custom key and definitions file.
.EXAMPLE
    .\resign-packages.ps1 -Help
    Shows this help message.
#>

# Parse command line arguments
param(
    [Switch]$Help,
    [string]$Key = "",
    [string]$Defs = "",
    [string]$Smc = ""
)

# Show help if requested
if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path
    exit 0
}

# Set default paths
$scriptPath = $PSScriptRoot
$smcPath = if ([string]::IsNullOrEmpty($Smc)) { "$scriptPath\smc.exe" } else { $Smc }
$privateKeyPath = if ([string]::IsNullOrEmpty($Key)) { "$scriptPath\costrict-private.pem" } else { $Key }
$packageDefsPath = if ([string]::IsNullOrEmpty($Defs)) { "$scriptPath\package-defs.json" } else { $Defs }

# Read package definitions
$packageDefs = Get-Content -Path $packageDefsPath | ConvertFrom-Json

# Function to resign a single file
function Resign-File {
    param(
        [string]$package,
        [string]$os,
        [string]$arch,
        [string]$ver,
        [string]$file,
        [string]$type,
        [string]$path = ""
    )
    
    Write-Host "Resigning: $package $os/$arch $ver - $file"
    
    # Construct the smc package build command
    # For conf packages with path specified, we need to modify the -f parameter to include the path
    # This ensures the generated package.json has the correct fileName with path
    # Debug information
    Write-Host "Debug: Resign-File - Package: $package, Type: $type, Path: '$path'"
    
    if ($type -eq "conf" -and $path) {
        # For conf files, we need to construct the fileName with path
        $originalFileName = [System.IO.Path]::GetFileName($file)
        Write-Host "Debug: Original filename: $originalFileName, New filename: $path/$originalFileName"
        
        # Use a different approach - directly modify the generated package.json
        # First, sign the file normally
        $command = "$smcPath package build -p $package -f '$file' -k '$privateKeyPath' -s $os -a $arch -v $ver -t $type"
        Invoke-Expression $command
        
        # Then, modify the generated package.json to include the path in fileName
        $packageJsonPath = Join-Path -Path (Split-Path -Path $file -Parent) -ChildPath "package.json"
        Write-Host "Debug: Package.json path: $packageJsonPath"
        if (Test-Path $packageJsonPath) {
            # Use string manipulation to update the JSON
            $newFileName = "$path/$originalFileName"
            
            # Read the JSON file content
            $jsonContent = Get-Content -Path $packageJsonPath -Raw
            Write-Host "Debug: Original JSON content: $jsonContent"
            
            # Escape the backslashes in the newFileName if any
            $escapedNewFileName = $newFileName -replace "\\", "\\\\"
            
            # Replace the fileName field using regex
            $searchPattern = '"fileName":\s*"[^"]*"'
            $replacePattern = '"fileName": "' + $escapedNewFileName + '"'
            $updatedJson = [regex]::Replace($jsonContent, $searchPattern, $replacePattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
            
            Write-Host "Debug: Search pattern: $searchPattern"
            Write-Host "Debug: Replace pattern: $replacePattern"
            Write-Host "Debug: Updated JSON content: $updatedJson"
            
            # Write the updated JSON back to the file without BOM
            [System.IO.File]::WriteAllText($packageJsonPath, $updatedJson, [System.Text.UTF8Encoding]::new($false))
            
            # Verify the update
            $verifyContent = Get-Content -Path $packageJsonPath -Raw
            Write-Host "Debug: Verified JSON content: $verifyContent"
            
            Write-Host "Debug: Updated fileName to: $newFileName"
        } else {
            Write-Host "Debug: Package.json not found at $packageJsonPath"
        }
    } else {
        # For exec files or conf files without path, use the original file directly
        $command = "$smcPath package build -p $package -f '$file' -k '$privateKeyPath' -s $os -a $arch -v $ver -t $type"
        Invoke-Expression $command
    }
}

# Function to process all files in a package directory
function Process-PackageDirectory {
    param(
        [string]$packageDir
    )
    
    # Clean up the directory path
    $cleanDir = $packageDir.TrimEnd('/','\')
    
    # Split the path into parts
    $pathParts = $cleanDir -split '[\\/]'
    
    # Check if the path has the correct structure: package/os/arch/ver
    if ($pathParts.Length -lt 4) {
        Write-Host "Warning: Invalid directory structure: $packageDir"
        return
    }
    
    # Extract package information from the path
    $pkgName = $pathParts[-4]
    $os = $pathParts[-3]
    $arch = $pathParts[-2]
    $ver = $pathParts[-1]
    
    Write-Host "Processing: $pkgName/$os/$arch/$ver ..."
    
    # Get package type, description, path, and filename from package-defs.json
    $pkgInfo = $packageDefs.packages | Where-Object { $_.name -eq $pkgName }
    $pkgType = if ($pkgInfo) { $pkgInfo.type } else { "exec" }
    $pkgDescription = if ($pkgInfo) { $pkgInfo.description } else { "No description" }
    $pkgPath = if ($pkgInfo -and $pkgInfo.path) { $pkgInfo.path } else { "" }
    $pkgFilename = if ($pkgInfo) { $pkgInfo.filename } else { "" }
    
    # Debug information
    Write-Host "Debug: $pkgName - Type: $pkgType, Path: '$pkgPath'"
    
    # Get all files in the directory except package.json
    $files = Get-ChildItem -Path $packageDir -File | Where-Object { $_.Name -ne "package.json" }
    
    foreach ($file in $files) {
        # If package-defs.json specifies a path, we need to construct the full path for fileName
        # For example, if path is "share" and actual file is "system-spec.json", fileName should be "share/system-spec.json"
        Resign-File -package $pkgName -os $os -arch $arch -ver $ver -file $file.FullName -type $pkgType -path $pkgPath
    }
}

# Get all package directories with the structure package/os/arch/ver
$packageDirs = Get-ChildItem -Path $scriptPath -Directory | ForEach-Object {
    $packageDir = $_.FullName
    Get-ChildItem -Path $packageDir -Directory | ForEach-Object {
        $osDir = $_.FullName
        Get-ChildItem -Path $osDir -Directory | ForEach-Object {
            $archDir = $_.FullName
            Get-ChildItem -Path $archDir -Directory | ForEach-Object {
                $verDir = $_.FullName
                Write-Output $verDir
            }
        }
    }
}

# Process each package directory
foreach ($dir in $packageDirs) {
    Process-PackageDirectory -packageDir $dir
}

Write-Host "Resigning completed."