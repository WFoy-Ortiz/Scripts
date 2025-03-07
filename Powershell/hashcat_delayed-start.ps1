# PowerShell Script to schedule a hashcat job after a delay
# Usage: .\Schedule-Hashcat.ps1 -DelayHours 3 -HashcatCommand "C:\full\path\to\hashcat.exe -m 1000 -a 0 hash.txt wordlist.txt"
# For help: .\Schedule-Hashcat.ps1 -h

param (
    [Parameter(Mandatory=$false)]
    [Alias("h")]
    [switch]$Help,
    
    [Parameter(Mandatory=$false)]
    [int]$DelayHours,
    
    [Parameter(Mandatory=$false)]
    [string]$HashcatCommand
)

if ($h) {
    Write-Host @"
Description:
    This script schedules a hashcat job to run after a specified delay,
    allowing you to queue jobs to run automatically while you're away.

Usage:
    .\Schedule-Hashcat.ps1 -DelayHours <hours> -HashcatCommand "<full_hashcat_command>"

Parameters:
    -h              : Display this help information
    -DelayHours     : Number of hours to wait before starting the hashcat job
    -HashcatCommand : The complete hashcat command with all parameters

Examples:
    # Run hashcat job after 3 hours
    .\Schedule-Hashcat.ps1 -DelayHours 3 -HashcatCommand "C:\full\path\to\hashcat.exe -a 0 -m 1000 hashes.txt wordlist.txt"
    
    # Run hashcat job immediately (0 hour delay)
    .\Schedule-Hashcat.ps1 -DelayHours 0 -HashcatCommand "C:\full\path\to\hashcat.exe -a 0 -m 1000 hashes.txt wordlist.txt"
    
    # Run hashcat with rule files
    .\Schedule-Hashcat.ps1 -DelayHours 2 -HashcatCommand "C:\full\path\to\hashcat.exe -a 0 -m 1000 hashes.txt wordlist.txt -r rules/best64.rule"

Notes:
    - This script allows interactive functionality with hashcat
    - All output is also logged to a timestamped file
    - The PowerShell window must remain open for the scheduled job to run
"@
    exit
}

if (-not $DelayHours -and -not $h) {
    Write-Host "ERROR: Missing required parameter -DelayHours" -ForegroundColor Red
    Write-Host "Use -h for help information" -ForegroundColor Yellow
    exit 1
}

if ([string]::IsNullOrEmpty($HashcatCommand) -and -not $h) {
    Write-Host "ERROR: Missing required parameter -HashcatCommand" -ForegroundColor Red
    Write-Host "Use -h for help information" -ForegroundColor Yellow
    exit 1
}

if ((-not $PSBoundParameters.ContainsKey('DelayHours')) -and -not $Help) {
    Write-Host "ERROR: Missing required parameter -DelayHours" -ForegroundColor Red
    Write-Host "Use -Help for help information" -ForegroundColor Yellow
    exit 1
}

if (([string]::IsNullOrEmpty($HashcatCommand)) -and -not $Help) {
    Write-Host "ERROR: Missing required parameter -HashcatCommand" -ForegroundColor Red
    Write-Host "Use -Help for help information" -ForegroundColor Yellow
    exit 1
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = "hashcat_scheduled_$timestamp.log"

# Log file function
function Write-Log {
    param ([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $message" | Tee-Object -FilePath $logFile -Append
}

Write-Log "Scheduling hashcat job to run in $DelayHours hours"
Write-Log "Command to run: $HashcatCommand"
Write-Log "Log will be saved to: $logFile"

$endTime = (Get-Date).AddHours($DelayHours)
Write-Log "The job will run at: $endTime"
Write-Log "Started waiting at: $(Get-Date)"
Write-Log "You can safely minimize this window if needed. Do not close it."
Write-Log "----------------------------------------"

# Wait specified time
$delaySeconds = $DelayHours * 3600
$start = Get-Date
$end = $start.AddSeconds($delaySeconds)

# Display a progress bar while waiting
while ((Get-Date) -lt $end) {
    $now = Get-Date
    $percentComplete = [math]::Min(100, [math]::Round(($now - $start).TotalSeconds / $delaySeconds * 100))
    $timeLeft = [math]::Round(($end - $now).TotalMinutes)

    Write-Progress -Activity "Waiting to start hashcat job" -Status "$timeLeft minutes remaining" -PercentComplete $percentComplete

    Start-Sleep -Seconds 10
}

# Run the hashcat job after the delay
Write-Log "Starting scheduled hashcat job"
Write-Log "Command: $HashcatCommand"
Write-Log "----------------------------------------"

try {
    Write-Log "Launching hashcat in interactive mode..."
    
    # Extract the hashcat directory to cd into it first
    $hashcatPath = $HashcatCommand -split " " | Select-Object -First 1
    $hashcatDir = Split-Path -Parent $hashcatPath
    
    # Define path to the potfile
    $potfilePath = Join-Path -Path $hashcatDir -ChildPath "hashcat.potfile"
    
    # Check if potfile exists and get initial state
    if (Test-Path -Path $potfilePath) {
        $initialPotfileSize = (Get-Item -Path $potfilePath).Length
        $initialPotfileContent = Get-Content -Path $potfilePath
        Write-Log "Starting potfile size: $initialPotfileSize bytes, $(($initialPotfileContent | Measure-Object).Count) entries"
    } else {
        $initialPotfileSize = 0
        $initialPotfileContent = @()
        Write-Log "No existing potfile found. Will monitor for new potfile creation."
    }

    $tempScriptFile = [System.IO.Path]::GetTempFileName() + ".bat"
    
    @"
@echo off
cd /d "$hashcatDir"
$HashcatCommand
exit %ERRORLEVEL%
"@ | Out-File -FilePath $tempScriptFile -Encoding ascii

    $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/k `"$tempScriptFile`"" -NoNewWindow -PassThru
    
    # Monitor the potfile while hashcat is running
    Write-Log "Starting potfile monitoring..."
    while (-not $process.HasExited) {
        Start-Sleep -Seconds 5
        
        if (Test-Path -Path $potfilePath) {
            $currentPotfileSize = (Get-Item -Path $potfilePath).Length
            
            if ($currentPotfileSize -gt $initialPotfileSize) {
                $currentPotfileContent = Get-Content -Path $potfilePath
                $newEntries = $currentPotfileContent | Where-Object { $initialPotfileContent -notcontains $_ }

                if ($newEntries.Count -gt 0) {
                    Write-Log "!!! NEW HASH(ES) CRACKED !!!"
                    foreach ($entry in $newEntries) {
                        Write-Log "CRACKED: $entry"
                    }
                    Write-Log "----------------------------------------"
                }
                
                $initialPotfileSize = $currentPotfileSize
                $initialPotfileContent = $currentPotfileContent
            }
        }
    }
    
    # Get the exit code
    $exitCode = $process.ExitCode
    
    # Final potfile check after hashcat exits
    if (Test-Path -Path $potfilePath) {
        $finalPotfileSize = (Get-Item -Path $potfilePath).Length
        $finalPotfileContent = Get-Content -Path $potfilePath
        $initialCount = ($initialPotfileContent | Measure-Object).Count
        $finalCount = ($finalPotfileContent | Measure-Object).Count
        $newCount = $finalCount - $initialCount
        
        Write-Log "----------------------------------------"
        Write-Log "Hashcat job completed with exit code: $exitCode"
        Write-Log "Final potfile size: $finalPotfileSize bytes"
        Write-Log "New hashes cracked in this session: $newCount"
        
        if ($newCount -gt 0) {
            Write-Log "!!! CRACKED HASH SUMMARY !!!"
            $newEntries = $finalPotfileContent | Where-Object { $initialPotfileContent -notcontains $_ }
            foreach ($entry in $newEntries) {
                Write-Log "CRACKED: $entry"
            }
        }
    }
    
    # Clean up temp file
    Remove-Item -Path $tempScriptFile -Force
}
catch {
    Write-Log "----------------------------------------"
    Write-Log "Error running hashcat job: $_"
}

Write-Log "Finished at: $(Get-Date)"
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")