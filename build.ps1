function Test-Project
{
    param([string] $DirectoryName)
    & dotnet test -c Release ("""" + $DirectoryName + """")
}

# Taken from psake https://github.com/psake/psake

<#
.SYNOPSIS
  This is a helper function that runs a scriptblock and checks the PS variable $lastexitcode
  to see if an error occcured. If an error is detected then an exception is thrown.
  This function allows you to run command-line programs without having to
  explicitly check the $lastexitcode variable.
.EXAMPLE
  exec { svn info $repository_trunk } "Error executing SVN. Please verify SVN command-line client is installed"
#>
function Exec
{
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=1)][scriptblock]$cmd,
        [Parameter(Position=1,Mandatory=0)][string]$errorMessage = ($msgs.error_bad_command -f $cmd)
    )
    & $cmd
    if ($lastexitcode -ne 0) {
        throw ("Exec: " + $errorMessage)
    }
}
########################
# THE BUILD!
########################
# Based on https://github.com/AutoMapper/AutoMapper.Extensions.Microsoft.DependencyInjection/blob/master/Build.ps1

Push-Location $PSScriptRoot

if(Test-Path .\artifacts) { Remove-Item .\artifacts -Force -Recurse }

$branch = @{ $true = $env:APPVEYOR_REPO_BRANCH; $false = $(git symbolic-ref --short -q HEAD) }[$env:APPVEYOR_REPO_BRANCH -ne $NULL];
$revision = @{ $true = "{0:00000}" -f [convert]::ToInt32("0" + $env:APPVEYOR_BUILD_NUMBER, 10); $false = "local" }[$env:APPVEYOR_BUILD_NUMBER -ne $NULL];
$suffix = @{ $true = ""; $false = "$($branch.Substring(0, [math]::Min(10,$branch.Length)))-$revision"}[$branch -eq "master" -and $revision -ne "local"]
$commitHash = $(git rev-parse --short HEAD)
$buildSuffix = @{ $true = "$($suffix)-$($commitHash)"; $false = "$($branch)-$($commitHash)" }[$suffix -ne ""]
$versionSuffix = @{ $true = "--version-suffix=$($suffix)"; $false = ""}[$suffix -ne ""]

echo "build: Package version suffix is $suffix"
echo "build: Build version suffix is $buildSuffix" 


exec { dotnet build .\src\NotDeadYet\NotDeadYet.csproj -c Release --version-suffix=$buildSuffix -v q /nologo}
exec { dotnet build .\src\NotDeadYet.AspNetCore\NotDeadYet.AspNetCore.csproj -c Release --version-suffix=$buildSuffix -v q /nologo}
exec { dotnet build .\src\NotDeadYet.MVC4\NotDeadYet.MVC4.csproj -c Release --version-suffix=$buildSuffix -v q /nologo}
exec { dotnet build .\src\NotDeadYet.Nancy\NotDeadYet.Nancy.csproj -c Release --version-suffix=$buildSuffix -v q /nologo}
exec { dotnet build .\src\NotDeadYet.WebApi\NotDeadYet.WebApi.csproj -c Release --version-suffix=$buildSuffix -v q /nologo}

#exec { dotnet build -c Release --version-suffix=$buildSuffix -v q /nologo }

foreach ($test in ls src/*Tests) {
    Push-Location $test

	echo "build: Testing project in $test"

    & dotnet test -c Release
    if($LASTEXITCODE -ne 0) { exit 3 }

    Pop-Location
}

exec { dotnet pack .\src\NotDeadYet\NotDeadYet.csproj -c Release -o ..\..\artifacts --no-build --include-symbols $versionSuffix }
exec { dotnet pack .\src\NotDeadYet.AspNetCore\NotDeadYet.AspNetCore.csproj -c Release -o ..\..\artifacts --no-build --include-symbols $versionSuffix }
exec { dotnet pack .\src\NotDeadYet.MVC4\NotDeadYet.MVC4.csproj -c Release -o ..\..\artifacts --no-build --include-symbols $versionSuffix }
exec { dotnet pack .\src\NotDeadYet.Nancy\NotDeadYet.Nancy.csproj -c Release -o ..\..\artifacts --no-build --include-symbols $versionSuffix }
exec { dotnet pack .\src\NotDeadYet.WebApi\NotDeadYet.WebApi.csproj -c Release -o ..\..\artifacts --no-build --include-symbols $versionSuffix }

Pop-Location