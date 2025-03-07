<#
.SYNOPSIS
Script that builds a NullSoft Installer package for Salt

.DESCRIPTION
This script takes the contents of the Python Directory that has Salt installed
and creates a NullSoft Installer based on that directory.

.EXAMPLE
build_pkg.ps1 -Version 3005

#>

param(
    [Parameter(Mandatory=$false)]
    [Alias("v")]
    # The version of Salt to be built. If this is not passed, the script will
    # attempt to get it from the git describe command on the Salt source
    # repo
    [String] $Version
)

#-------------------------------------------------------------------------------
# Script Preferences
#-------------------------------------------------------------------------------

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
$ProgressPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop"

#-------------------------------------------------------------------------------
# Script Functions
#-------------------------------------------------------------------------------

function Write-Result($result, $ForegroundColor="Green") {
    $position = 80 - $result.Length - [System.Console]::CursorLeft
    Write-Host -ForegroundColor $ForegroundColor ("{0,$position}$result" -f "")
}

#-------------------------------------------------------------------------------
# Script Variables
#-------------------------------------------------------------------------------

$PROJECT_DIR   = $(git rev-parse --show-toplevel)
$SCRIPT_DIR    = (Get-ChildItem "$($myInvocation.MyCommand.Definition)").DirectoryName
$BUILD_DIR     = "$PROJECT_DIR\pkg\windows\build"
$BUILDENV_DIR  = "$PROJECT_DIR\pkg\windows\buildenv"
$INSTALLER_DIR = "$SCRIPT_DIR\installer"
$SCRIPTS_DIR   = "$BUILDENV_DIR\Scripts"
$PYTHON_BIN    = "$SCRIPTS_DIR\python.exe"
$PY_VERSION    = [Version]((Get-Command $PYTHON_BIN).FileVersionInfo.ProductVersion)
$PY_VERSION    = "$($PY_VERSION.Major).$($PY_VERSION.Minor)"
$NSIS_BIN      = "$( ${env:ProgramFiles(x86)} )\NSIS\makensis.exe"
$ARCH          = $(. $PYTHON_BIN -c "import platform; print(platform.architecture()[0])")

if ( $ARCH -eq "64bit" ) {
    $ARCH = "AMD64"
} else {
    $ARCH = "x86"
}

#-------------------------------------------------------------------------------
# Verify Salt and Version
#-------------------------------------------------------------------------------

if ( [String]::IsNullOrEmpty($Version) ) {
    $Version = $( git describe ).Trim("v")
    if ( [String]::IsNullOrEmpty($Version) ) {
        Write-Host "Failed to get version from $PROJECT_DIR"
        exit 1
    }
}

#-------------------------------------------------------------------------------
# Start the Script
#-------------------------------------------------------------------------------

Write-Host $("=" * 80)
Write-Host "Build NullSoft Installer for Salt" -ForegroundColor Cyan
Write-Host "- Architecture: $ARCH"
Write-Host "- Salt Version: $Version"
Write-Host $("-" * 80)

#-------------------------------------------------------------------------------
# Verify Environment
#-------------------------------------------------------------------------------

Write-Host "Verifying Python Build: " -NoNewline
if ( Test-Path -Path "$PYTHON_BIN" ) {
    Write-Result "Success" -ForegroundColor Green
} else {
    Write-Result "Failed" -ForegroundColor Red
    exit 1
}

Write-Host "Verifying Salt Installation: " -NoNewline
if ( Test-Path -Path "$BUILDENV_DIR\salt-minion.exe" ) {
    Write-Result "Success" -ForegroundColor Green
} else {
    Write-Result "Failed" -ForegroundColor Red
    exit 1
}

Write-Host "Verifying NSIS Installation: " -NoNewline
if ( Test-Path -Path "$NSIS_BIN" ) {
    Write-Result "Success" -ForegroundColor Green
} else {
    Write-Result "Failed" -ForegroundColor Red
    exit 1
}

#-------------------------------------------------------------------------------
# Build the Installer
#-------------------------------------------------------------------------------

Write-Host "Building the Installer: " -NoNewline
$installer_name = "Salt-Minion-$Version-Py$($PY_VERSION.Split(".")[0])-$ARCH-Setup.exe"
Start-Process -FilePath $NSIS_BIN `
              -ArgumentList "/DSaltVersion=$Version", `
                            "/DPythonArchitecture=$ARCH", `
                            "$INSTALLER_DIR\Salt-Minion-Setup.nsi" `
              -Wait -WindowStyle Hidden
if ( Test-Path -Path "$INSTALLER_DIR\$installer_name" ) {
    Write-Result "Success" -ForegroundColor Green
} else {
    Write-Result "Failed" -ForegroundColor Red
    Write-Host "Failed to find $installer_name in installer directory"
    exit 1
}

#-------------------------------------------------------------------------------
# Move installer to build directory
#-------------------------------------------------------------------------------

if ( ! (Test-Path -Path "$BUILD_DIR") ) {
    New-Item -Path "$BUILD_DIR" -ItemType Directory | Out-Null
}
if ( Test-Path -Path "$BUILD_DIR\$installer_name" ) {
    Write-Host "Backing up existing installer: " -NoNewline
    $new_name = "$installer_name.$( Get-Date -UFormat %s ).bak"
    Move-Item -Path "$BUILD_DIR\$installer_name" `
              -Destination "$BUILD_DIR\$new_name"
    if ( Test-Path -Path "$BUILD_DIR\$new_name" ) {
        Write-Result "Success" -ForegroundColor Green
    } else {
        Write-Result "Failed" -ForegroundColor Red
        exit 1
    }
}

Write-Host "Moving the Installer: " -NoNewline
Move-Item -Path "$INSTALLER_DIR\$installer_name" -Destination "$BUILD_DIR"
if ( Test-Path -Path "$BUILD_DIR\$installer_name" ) {
    Write-Result "Success" -ForegroundColor Green
} else {
    Write-Result "Failed" -ForegroundColor Red
    exit 1
}

#-------------------------------------------------------------------------------
# Script Complete
#-------------------------------------------------------------------------------

Write-Host $("-" * 80)
Write-Host "Build NullSoft Installer for Salt Completed" -ForegroundColor Cyan
Write-Host $("=" * 80)
Write-Host "Installer can be found at the following location:"
Write-Host "$BUILD_DIR\$installer_name"
