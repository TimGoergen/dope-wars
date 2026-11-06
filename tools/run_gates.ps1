# Run Dope Wars: Omaha Metro Edition's verification gates.
#
#   pwsh tools\run_gates.ps1              # all 8 headless gates + a 150-frame boot check
#   pwsh tools\run_gates.ps1 -Only Market # just the gates whose name matches
#
# Judges strictly by EXIT CODE (0 = PASS, non-zero = FAIL).

param(
    [switch]$All,
    [string]$Only = "",
    [string]$Godot = "D:\Downloads\Godot_v4.5.1-stable_win64\Godot_v4.5.1-stable_win64_console.exe"
)

$ErrorActionPreference = "Continue"
$repo = Split-Path -Parent $PSScriptRoot
$game = Join-Path $repo "game"

$headless = @(
    "MoneyTest",
    "MarketEngineTest",
    "TradingAndCapacityTest",
    "BankingAndLoanSharkTest",
    "CombatAndHeatTest",
    "FacilitiesAndEventsTest",
    "LegacyAndSaveTest",
    "FullRunSimTest",
    "UiLayoutTest"
)

if (-not (Test-Path $Godot)) {
    Write-Host "Godot not found at $Godot" -ForegroundColor Red
    Write-Host "Pass -Godot <path> to override." -ForegroundColor Yellow
    exit 2
}

function Invoke-Gate {
    param([string]$Name, [string[]]$ExtraArgs)

    $arguments = @("--path", $game) + $ExtraArgs + @("--script", "res://sim/$Name.gd")
    $output = & $Godot @arguments 2>&1
    $ok = ($LASTEXITCODE -eq 0)

    $label = if ($ok) { "PASS" } else { "FAIL" }
    $color = if ($ok) { "Green" } else { "Red" }
    Write-Host ("  {0,-26} {1}" -f $Name, $label) -ForegroundColor $color
    if (-not $ok) {
        $output | Select-Object -Last 30 | ForEach-Object { Write-Host "      $_" -ForegroundColor DarkGray }
    }
    return $ok
}

$gates = $headless
if ($Only -ne "") { $gates = $gates | Where-Object { $_ -like "*$Only*" } }

Write-Host ""
Write-Host "Gates ($($gates.Count))" -ForegroundColor Cyan
$failed = @()
foreach ($gate in $gates) {
    if (-not (Invoke-Gate -Name $gate -ExtraArgs @("--headless"))) { $failed += $gate }
}

if ($Only -eq "") {
    Write-Host ""
    Write-Host "Boot" -ForegroundColor Cyan
    $bootOutput = & $Godot --headless --path $game --quit-after 150 2>&1
    $bootErrors = $bootOutput | Where-Object {
        $_ -match "SCRIPT ERROR|Parse Error|Failed to load|Failed to instantiate"
    }
    if ($bootErrors) {
        Write-Host "  boot                       FAIL" -ForegroundColor Red
        $bootErrors | Select-Object -First 10 | ForEach-Object { Write-Host "      $_" -ForegroundColor DarkGray }
        $failed += "boot"
    } else {
        Write-Host "  boot                       PASS" -ForegroundColor Green
    }
}

Write-Host ""
if ($failed.Count -eq 0) {
    Write-Host "All green." -ForegroundColor Green
    exit 0
}
Write-Host "FAILED: $($failed -join ', ')" -ForegroundColor Red
exit 1
