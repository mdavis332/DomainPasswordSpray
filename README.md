# DomainPasswordSpray
DomainPasswordSpray is a tool written in PowerShell to perform a password spray attack against users of a domain. By default it will automatically generate the userlist from the domain whether a user provides username(s) at runtime or not. If runtime userlist is provided, it will be compared against the auto-generated list and all user-provided usernames that meet the following criteria will be excluded from the final spray list:
- Locked out
- Disabled
- Expired
- Nonexistent
- Within 1 bad password attempt of a lockout

This module uses Warren Frame's (@RamblingCookieMonster) Invoke-Parallel to process the users simultaneously in batches of 20 and speed up the spray. In tests, this has reduced scan time by up to 83%. This module has been tested against 9000 users in a production AD environment with a runtime under 60 seconds.

## Quick Start Guide
Open a PowerShell terminal from the Windows command line with 'powershell.exe -exec bypass'.

CD to the DomainPasswordSpray root and:

```PowerShell
Import-Module DomainPasswordSpray
```

The only option necessary to perform a password spray is -PasswordList where you can provide a single string or array of strings. When trying multiptle passwords, Invoke-DomainPasswordSpray will attempt to gather the account lockout observation window from the domain and limit sprays to one per observation window to avoid locking out accounts.

The following command will automatically generate a list of users from the current user's domain and attempt to authenticate using each username and a password of Spring2017.
```PowerShell
Invoke-DomainPasswordSpray -Password 'Spring2017'
```

### Output
Output leaves the function as a PowerShell object. You can therefore pass output down the pipeline to other functions such as Out-File or other testing tools that make up your toolkit.

The following command will use the userlist at users.txt and try to authenticate to the domain "domain.local" using each password in the passlist.txt file one at a time. It will automatically attempt to detect the domain's lockout observation window and restrict sprays to one attempt during each window. The results of the spray will be output to a file called sprayed-creds.txt
```PowerShell
Invoke-DomainPasswordSpray -UserName (Get-Content 'c:\users.txt') -DomainName 'domain.local' -Password (Get-Content '.\passlist.txt') | Out-File 'sprayed-creds.txt'
```

### Invoke-DomainPasswordSpray Options
```
UserName          - Optional username parameter. This will be generated automatically if not specified. Can contain single string or array of strings.
Password          - Mandatory parameter. A list of passwords one per line to use for the password spray.
DomainName        - Optional parameter. A domain to spray against.
ShowProgress      - Optional switch. When specified, displays progress bar for user spraying status.
Verbose           - Optional switch. When specified, writes status messages out to console.

```
## Get-DomainUserList Function
The function Get-DomainUserList allows you to generate a userlist from the domain. It has options to remove disabled accounts and those that are about to be locked out. This is performed automatically in DomainPasswordSpray.

This command will write the domain user list without disabled accounts or accounts about to be locked out to a file at "userlist.txt".
```PowerShell
Get-DomainUserList -Domain domainname.local -RemoveDisabled -RemovePotentialLockouts | Out-File -Encoding ascii userlist.txt
```
## Demo
![alt text](images/pwspray-demo480.gif "Animated gif demo")

The above gif depicts a parallel spray against 250 users with 2 consecutive passwords, all in 18 seconds.

## Planned Updates
- [x] Take array of strings for UserList & PasswordList params
- [x] Improve progress bar status
- [x] Exclude locked out accounts from the ldap filter
- ~~Accept ADUser objects~~ (not sure about this anymore)
- [ ] Introduce throttle/sneaky parameters to reduce login attempts to a certain number within threshold of time (to avoid SIEM rules)

## Contributing
Contributions, fixes, and improvements can be submitted directly against this project as a GitHub issue or pull request.

## License
MIT License

Copyright (c) 2018

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

# Acknowledgments
* [dafthack/DomainPasswordSpray](https://github.com/dafthack/DomainPasswordSpray)
* [@RamblingCookieMonster](https://github.com/RamblingCookieMonster)
* [@egypt](https://github.com/egypt)

