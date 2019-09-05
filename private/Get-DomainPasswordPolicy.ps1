function Get-DomainPasswordPolicy {
    <#
	.SYNOPSIS
		Retrives the default active directory password policy.
	.DESCRIPTION
		Retrives the default active directory password policy with an optional check for fine-grained password policies.
	.PARAMETER DomainName
		The domain for which to get Password Policy.
	.PARAMETER CheckPso
		A switch statement that determines if the function will attempt to find any Fine-Grained Password Policies and set the most sensitive Account Lockout Threshold.
	.EXAMPLE
		PS C:\> Get-DomainPasswordPolicy
		Output the default domain password policy
	#>
    [CmdletBinding()]
    param(
        [string]$DomainName = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().Name,

        [switch]$CheckPso
    )

    try {
        # Using domain specified with -DomainName option
        $DomainContext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext("domain", $DomainName)
        $DomainObject = [System.DirectoryServices.ActiveDirectory.Domain]::GetDomain($DomainContext)
        $DomainDn = ([ADSI]"LDAP://$DomainName").distinguishedName

    }
    catch {
        Write-Error '[*] Could not connect to the domain. Try again specifying the domain name with the -DomainName option'
        break
    }

    # Setting the current domain's account lockout threshold
    # Format of the next few lines credit to @benpturner
    $DomainPolicy = [ADSI] "LDAP://$($DomainObject.PDCRoleOwner)"

    $MinPassLen = @{Name = 'Minimum Password Length (Chars)'; Expression = { $_.minPwdLength.value } }
    $MinPassAge = @{Name = 'Minimum Password Age (Days)'; Expression = { $_.ConvertLargeIntegerToInt64($_.minPwdAge.value) / -864000000000 } }
    $MaxPassAge = @{Name = 'Maximum Password Age (Days)'; Expression = { $_.ConvertLargeIntegerToInt64($_.maxPwdAge.value) / -864000000000 } }
    $PassHistory = @{Name = 'Enforce Password History (Passwords remembered)'; Expression = { $_.pwdHistoryLength.value } }
    $AcctLockoutDuration = @{Name = 'Account Lockout Duration (Minutes)'; Expression = {
            if ($_.ConvertLargeIntegerToInt64($_.lockoutDuration.value) / -600000000 -eq -1) { 'Account is locked out until administrator unlocks it.' } else { $_.ConvertLargeIntegerToInt64($_.lockoutDuration.value) / -600000000 }
        }
    }
    $AcctLockoutObservationInterval = @{Name = 'Lockout Observation Interval (Minutes)'; Expression = { $_.ConvertLargeIntegerToInt64($_.lockOutObservationWindow.value) / -600000000 } }
    $AcctLockoutThreshold = @{Name = 'Account Lockout Threshold (Invalid logon attempts)'; Expression = { $_.lockoutThreshold.value } }

    # do we check for Password Settings Objects (Fine-Grained Password Policies)
    if ($CheckPso) {
        [System.Collections.ArrayList]$AccountLockoutThresholds = @()
        $AccountLockoutThresholds.Add($DomainPolicy.Properties.lockoutThreshold.value) > $null

        # Getting the AD behavior version to determine if fine-grained password policies are possible
        $BehaviorVersion = [int]$DomainPolicy.Properties['msds-behavior-version'].item(0)
        if ($BehaviorVersion -ge 3) {
            # Determine if there are any fine-grained password policies
            Write-Verbose '[*] Current domain is compatible with Fine-Grained Password Policy'
            $ADSearcher = New-Object System.DirectoryServices.DirectorySearcher
            $ADSearcher.SearchRoot = [ADSI] "LDAP://CN=Password Settings Container,CN=System,$DomainDn"
            $ADSearcher.Filter = "(objectclass=msDS-PasswordSettings)"

            try {
                $PSOs = $ADSearcher.FindAll()
            }
            catch {
                Write-Verbose '[*] No permission to access Password Settings Container'
            }

            if ( $PSOs.count -gt 0) {

                Write-Verbose "[*] A total of $($PSOs.count) Fine-Grained Password policies were found"
                foreach ($Entry in $PSOs) {
                    # Selecting the lockout threshold, min pwd length, and which groups the fine-grained password policy applies to
                    $PSOFineGrainedPolicy = $Entry | Select-Object -ExpandProperty Properties
                    $PSOPolicyName = $PSOFineGrainedPolicy.name[0]
                    $PSOLockoutThreshold = $PSOFineGrainedPolicy.'msds-lockoutthreshold'[0]
                    $PSOAppliesTo = $PSOFineGrainedPolicy.'msds-psoappliesto'[0]
                    $PSOMinPwdLength = $PSOFineGrainedPolicy.'msds-minimumpasswordlength'[0]
                    # adding lockout threshold to array for use later to determine which is the lowest.
                    $AccountLockoutThresholds.Add($PSOLockoutThreshold) > $null

                    Write-Verbose "[*] Fine-Grained Password Policy titled: $PSOPolicyName has a Lockout Threshold of $PSOLockoutThreshold attempts, minimum password length of $PSOMinPwdLength chars, and applies to $PSOAppliesTo"
                }

            }
            else {
                Write-Verbose '[*] NO Fine-Grained Password policies found'
            }

        }

        # Generate a userlist from the domain
        # Selecting the lowest account lockout threshold in the domain to avoid locking out any accounts.
        [int]$SmallestLockoutThreshold = $AccountLockoutThresholds | Sort-Object | Select-Object -First 1

        $AcctLockoutThreshold = @{Name = 'Account Lockout Threshold (Invalid logon attempts)'; Expression = { $SmallestLockoutThreshold } }

    }


    $DomainPolicy | Select-Object $MinPassLen, $MinPassAge, $MaxPassAge, $PassHistory, $AcctLockoutThreshold, $AcctLockoutDuration, $AcctLockoutObservationInterval

}
