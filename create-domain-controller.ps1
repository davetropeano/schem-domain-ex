#
# Windows PowerShell script for AD DS Deployment
#

param (
	[string]$domain,
	[string]$username,
	[string]$password,
	[string]$step
)

$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue"
Start-Transcript -path C:\installs\output.txt -append

$a,$b = $domain.split('.')

# Password
$secure_string_pwd = ConvertTo-SecureString $password -AsPlainText -Force

if ($step -eq "1")
{
	# Domain Variables:
	$DomainMode = "Win2012";
	$ForestMode = "Win2012";

	# Path Variables
	$DatabasePath = "C:\Windows\NTDS";
	$LogPath = "C:\Windows\NTDS";
	$SysvolPath = "C:\Windows\SYSVOL";

	# Installing needed roles/feautres
	Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

	#Promote Domain Controller and create a new domain in new forest.
	Import-Module ADDSDeployment

	Install-ADDSForest `
	-CreateDnsDelegation:$false `
	-DatabasePath $DatabasePath `
	-LogPath $LogPath `
	-SysvolPath $SysvolPath `
	-DomainName $domain `
	-DomainMode $DomainMode `
	-ForestMode $ForestMode `
	-InstallDns:$true `
	-NoRebootOnCompletion:$true `
	-SafeModeAdministratorPassword $secure_string_pwd `
	-Force:$true

	Start-Sleep 5

	schtasks.exe /create /f /tn ConfigureDC /ru SYSTEM /sc ONSTART /delay 0002:00 /tr "powershell.exe -ExecutionPolicy Bypass C:\installs\create-domain-controller.ps1 -domain $domain -username $username -password $password -step 2"

	Start-Sleep 2
	Stop-Transcript

	Restart-Computer
}
else
{
	try {
		$orgpath = "DC=" + $a + ",DC=" + $b
		New-ADOrganizationalUnit -Name compute -Path $orgpath

		$oupath = "OU=compute,DC=" + $a + ",DC=" + $b
		New-ADUser -SamAccountName $username -Name "Compute User" -UserPrincipalName $username -AccountPassword $secure_string_pwd -Enabled $true -PasswordNeverExpires $true -Path $oupath

		Add-ADGroupMember -Identity 'Domain Admins' -Members $username
	}
	catch {
	}
	schtasks.exe /delete /tn "ConfigureDC" /f
    Stop-Transcript
}

