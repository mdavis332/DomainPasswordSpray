function Invoke-Countdown {   
    param(
		$Seconds = 1800,
		$Message = '[*] Pausing to avoid account lockout'
    )
	
	foreach ($Count in (1..$Seconds)) {   
		Write-Progress -Id 100 -Activity $Message -Status "Waiting for $($Seconds/60) minutes. $($Seconds - $Count) seconds remaining" -PercentComplete (($Count / $Seconds) * 100)
        Start-Sleep -Seconds 1
    }
    Write-Progress -Id 100 -Activity $Message -Status 'Completed' -PercentComplete 100 -Completed
}