param(
    [ValidateSet("template_debug", "template_release")]
    [string]$Target = "template_debug",
    [string]$Arch = "x86_64"
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Resolve-Path "$Root/.."
$GodotCpp = Join-Path $Root "extern/godot-cpp"

if (-not (Test-Path $GodotCpp)) {
    Write-Error "godot-cpp submodule missing. Run 'git submodule update --init --recursive'."
}

Push-Location $GodotCpp
try {
    Write-Host "Building godot-cpp ($Target)..."
    & scons platform=windows target=$Target bits=64 -j8
}
finally {
    Pop-Location
}

$LibName = "libgodot-cpp.windows.$Target.$Arch.lib"
$LibPath = Join-Path $GodotCpp "bin/$LibName"
if (-not (Test-Path $LibPath)) {
    Write-Error "Expected $LibPath but it was not produced."
}

$BuildDir = Join-Path $Root "build/windows-$Target"
$CMakeArgs = @(
    "-S", (Join-Path $Root "src"),
    "-B", $BuildDir,
    "-DGODOT_CPP_PATH=$GodotCpp",
    "-DGODOT_CPP_LIB=$LibPath"
)

Write-Host "Configuring CMake..."
& cmake @CMakeArgs

Write-Host "Building..."
& cmake --build $BuildDir --config Release

$OutputDll = Join-Path $BuildDir "Release/multi_mouse.dll"
if (-not (Test-Path $OutputDll)) {
    $OutputDll = Join-Path $BuildDir "multi_mouse.dll"
}

$DestDir = Join-Path $Root "addons/multi_mouse/bin/win64"
New-Item -ItemType Directory -Force -Path $DestDir | Out-Null
$DestDll = Join-Path $DestDir "libmulti_mouse.windows.$Target.$Arch.dll"
Copy-Item $OutputDll $DestDll -Force

Write-Host "Copied $OutputDll -> $DestDll"
