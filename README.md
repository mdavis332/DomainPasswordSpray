# DomainPasswordSpray
DomainPasswordSpray is a tool written in PowerShell to perform a password spray attack against users of a domain. By default it will automatically generate the userlist from the domain. BE VERY CAREFUL NOT TO LOCKOUT ACCOUNTS!

This version has been updated with Warren Frame's (@RamblingCookieMonster) Invoke-Parallel to process the users simultaneously in batches of 50 and speed up the spray. In tests, this has reduced scan time by up to 83%.

## Quick Start Guide
Open a PowerShell terminal from the Windows command line with 'powershell.exe -exec bypass'.

CD to the DomainPasswordSpray root and:

```PowerShell
Import-Module DomainPasswordSpray
```

The only option necessary to perform a password spray is -PasswordList where you can provide a single string or array of strings. When trying multiptle passwords, Invoke-DomainPasswordSpray will attempt to gather the account lockout observation window from the domain and limit sprays to one per observation window to avoid locking out accounts.

The following command will automatically generate a list of users from the current user's domain and attempt to authenticate using each username and a password of Spring2017.
```PowerShell
Invoke-DomainPasswordSpray -PasswordList 'Spring2017'
```

The following command will use the userlist at users.txt and try to authenticate to the domain "domain.local" using each password in the passlist.txt file one at a time. It will automatically attempt to detect the domain's lockout observation window and restrict sprays to one attempt during each window. The results of the spray will be output to a file called sprayed-creds.txt
```PowerShell
Invoke-DomainPasswordSpray -UserList (Get-Content 'c:\users.txt') -DomainName 'domain.local' -PasswordList (Get-Content '.\passlist.txt') | Out-File 'sprayed-creds.txt'
```

### Invoke-DomainPasswordSpray Options
```
UserList          - Optional UserList parameter. This will be generated automatically if not specified.
PasswordList      - A list of passwords one per line to use for the password spray (Be very careful not to lockout accounts).
DomainName            - A domain to spray against.

```
## Get-DomainUserList Function
The function Get-DomainUserList allows you to generate a userlist from the domain. It has options to remove disabled accounts and those that are about to be locked out. This is performed automatically in DomainPasswordSpray if no user list is specified.

This command will write the domain user list without disabled accounts or accounts about to be locked out to a file at "userlist.txt".
```PowerShell
Get-DomainUserList -Domain domainname.local -RemoveDisabled -RemovePotentialLockouts | Out-File -Encoding ascii userlist.txt
```
## Demo
![alt text](.\images\pwspray-demo480.gif "Animated gif demo")

The above gif depicts a parallel spray against 250 users with 2 consecutive passwords, all in 18 seconds.
