# PowerShell Script to schedule a hashcat job after a delay
# Usage: .\Schedule-Hashcat.ps1 -DelayHours 3 -HashcatCommand "hashcat -m 1000 -a 0 hash.txt wordlist.txt"

param (
    [Parameter(Mandatory=$true)]
    [int]$DelayHours,
    
    [Parameter(Mandatory=$true)]
    [string]$HashcatCommand
)

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = "hashcat_scheduled_$timestamp.log"

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

$delaySeconds = $DelayHours * 3600
$start = Get-Date
$end = $start.AddSeconds($delaySeconds)

while ((Get-Date) -lt $end) {
    $now = Get-Date
    $percentComplete = [math]::Min(100, [math]::Round(($now - $start).TotalSeconds / $delaySeconds * 100))
    $timeLeft = [math]::Round(($end - $now).TotalMinutes)
    
    Write-Progress -Activity "Waiting to start hashcat job" -Status "$timeLeft minutes remaining" -PercentComplete $percentComplete
    
    Start-Sleep -Seconds 10
}

Write-Log "Starting scheduled hashcat job"
Write-Log "Command: $HashcatCommand"
Write-Log "----------------------------------------"

try {
    $output = Invoke-Expression $HashcatCommand 2>&1
    $output | ForEach-Object { Write-Log $_ }
    
    Write-Log "----------------------------------------"
    Write-Log "Hashcat job completed successfully"
}
catch {
    Write-Log "----------------------------------------"
    Write-Log "Error running hashcat job: $_"
}

Write-Log "Finished at: $(Get-Date)"
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")