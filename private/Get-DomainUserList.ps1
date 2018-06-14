function Get-DomainUserList {
	<#
    .SYNOPSIS
    This function gathers a userlist from the domain.
    .DESCRIPTION
    	This function gathers a userlist from the domain.
		Author: Beau Bullock (@dafthack) and Michael Davis (@mdavis332)
		License: MIT
    .PARAMETER DomainName
    	Optional. The domain to spray against.
    .PARAMETER RemoveDisabled
    	Optional. Attempts to remove disabled accounts from the userlist. (Credit to Sally Vandeven (@sallyvdv))   
    .PARAMETER RemovePotentialLockouts
		Optional. Removes accounts within 1 attempt of locking out.
	.PARAMETER Filter
		Optional. Custom LDAP filter for users, e.g. "(description=*admin*)". Thanks to @egypt
    
    .EXAMPLE
		C:\PS> Get-DomainUserList
		Description
		-----------
		This command will gather a userlist from the current domain including all samAccountType "805306368".
    
    .EXAMPLE
		C:\PS> Get-DomainUserList -DomainName domainname.net -RemoveDisabled -RemovePotentialLockouts | Out-File -Encoding ascii userlist.txt
		Description
		-----------
		This command will gather a userlist from the domain "domainname.net" including any accounts that are not disabled and are not close to locking out. 
		It will write them to a file at "userlist.txt"
    
    #>
	[CmdletBinding()]
    param(
     [Parameter(Position = 0, Mandatory = $false)]
	 [Alias('Domain')]
     [string]$DomainName = ([System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()).Name,
     
     [Parameter(Position = 1, Mandatory = $false)]
     [switch]$RemoveDisabled,
     
     [Parameter(Position = 2, Mandatory = $false)]
     [switch]$RemovePotentialLockouts,
	 
	 [Parameter(Position = 3, Mandatory = $false)]
	 [int]$SmallestLockoutThreshold,

	 [Parameter(Position = 4, Mandatory = $false)]
	 [string]$Filter
    )
    

    try {
		# Using domain specified with -DomainName option
		$DomainContext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext("domain",$DomainName)
		$DomainObject =[System.DirectoryServices.ActiveDirectory.Domain]::GetDomain($DomainContext)
		$CurrentPdc = "LDAP://$($DomainObject.PdcRoleOwner.Name)"
    } catch {
		Write-Error '[*] Could not connect to the domain. Try again specifying the domain name with the -DomainName option'
		break
    }


    # Setting the current domain's account lockout threshold
    $DomainPolicy = [ADSI] "LDAP://$($DomainObject.PDCRoleOwner)"

	# Get account lockout observation window to avoid running more than 1 password spray per observation window.
	[int]$ObservationWindow = $DomainPolicy.ConvertLargeIntegerToInt64($DomainPolicy.lockOutObservationWindow.value)/-600000000
	
	$DirEntry = [ADSI]$CurrentPdc
	$UserSearcher = [adsisearcher]$DirEntry

	$UserSearcher.PropertiesToLoad.Add("samaccountname") > $null
	$UserSearcher.PropertiesToLoad.Add("badpwdcount") > $null
	$UserSearcher.PropertiesToLoad.Add("badpasswordtime") > $null
	$Now = [datetime]::Now.toFiletime()
	if ($RemoveDisabled) {
		Write-Verbose '[*] Excluding disabled, locked out, and expired users from search criteria'
		# more precise LDAP filter UAC check for users that are disabled (Joff Thyer)
		# LDAP 1.2.840.113556.1.4.803 means bitwise &
		# LDAP 1.2.840.113556.1.4.804 means bitwise OR
		# uac 0x2 is ACCOUNTDISABLE
		# uac 0x10 is LOCKOUT
		# See http://jackstromberg.com/2013/01/useraccountcontrol-attributeflag-values/. Thanks @egypt
		# lockoutTime>=1 corresponds to accounts that are locked out already
		# accountExpires>=$Now corresponds to accounts that are set to expire sometime in the future
		# accountExpires=0 corresponds to an account that is set to never expire
		$UserSearcher.Filter = "(&(objectCategory=person)(objectClass=user)(!userAccountControl:1.2.840.113556.1.4.804:=18)(!lockoutTime>=1)(|(accountExpires>=$Now)(accountExpires=0))$Filter)"
	} else {
		$UserSearcher.Filter = "(&(objectCategory=person)(objectClass=user)(|(accountExpires>=$Now)(accountExpires=0))$Filter)"
	}

	# grab batches of 1000 in results
	$UserSearcher.PageSize = 1000
	$AllUserObjects = $UserSearcher.FindAll()
	Write-Verbose "[*] There were $($AllUserObjects.count) users returned after filtering out disabled, locked out, and expired accounts"
	[System.Collections.ArrayList]$UserListArray = @()
	$RemovedUserCount = 0
	
	if ($RemovePotentialLockouts) {
	
		$CurrentTime = Get-Date
		foreach ($User in $AllUserObjects) {
			$BadCount = $null
			# Getting bad password counts and lst bad password time for each user
			try {
				$BadCount = $User.Properties.badpwdcount[0]
			} catch {}
			
			$SamAccountName = $User.Properties.samaccountname[0]
			
			try {
				$BadPasswordTime = $User.Properties.badpasswordtime[0]
				$LastBadPwd = [datetime]::FromFileTime($BadPasswordTime)
			} catch {}
		
			$TimeDifference = ($CurrentTime - $LastBadPwd).TotalMinutes

			if ($BadCount) {
				
				$AttemptsUntilLockout = $SmallestLockoutThreshold - $BadCount   
				
				# if there is no lockout threshold (ie, threshold = 0)
				# if there is more than 1 attempt left before a user locks out 
				# or if the time since the last failed login is greater than the domain observation window add user to spray list
				if ($SmallestLockoutThreshold -eq 0 -or $AttemptsUntilLockout -gt 1 -or $TimeDifference -gt $ObservationWindow) {
					$UserListArray.Add($SamAccountName) > $null
				} else {
					$RemovedUserCount++
				}

			} elseif ($BadCount -eq 0) {
				# if they get here, it means BadCount = 0, no worries about locking out the account, so we add it
				$UserListArray.Add($SamAccountName) > $null
			} elseif (-not $User.Properties.badpwdcount) {
				# if we get here, it means the account doesn't log bad passwords, so add it
				$UserListArray.Add($SamAccountName) > $null
			}
		}
		Write-Verbose "[*] Removed $RemovedUserCount users from spray list due to being within 1 attempt of locking out and having its last bad logon within the domain observation window of $ObservationWindow minutes"
	} else {
		
		foreach ($User in $AllUserObjects) {
			$SamAccountName = $User.Properties.samaccountname[0]
			$UserListArray.Add($SamAccountName) > $null
		}
	}
	
	Write-Verbose "[*] Created a final userlist containing $($UserListArray.count) users gathered from the current user's domain"
	$UserListArray

}
