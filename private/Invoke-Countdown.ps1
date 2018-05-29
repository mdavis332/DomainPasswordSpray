function Invoke-Countdown {   
    param(
		$Seconds = 1800,
		$Message = '[*] Pausing to avoid account lockout',
		$Subtext = '',
		$ParentId = 99
    )
	
	foreach ($Count in (1..$Seconds)) {
		$ProgressBar100Params = 	@{
				Id 					= 100
				ParentId			= $ParentId
				Activity 			= $Message
				Status 				= $Subtext
				CurrentOperation	= "Waiting for $($Seconds/60) minutes. $($Seconds - $Count) seconds remaining"
				PercentComplete		= (($Count / $Seconds) * 100)
		}
		Write-Progress @ProgressBar100Params
        Start-Sleep -Seconds 1
    }
    Write-Progress -Id 100 -ParentId $ParentId -Activity $Message -Status 'Completed' -PercentComplete 100 -Completed
}
