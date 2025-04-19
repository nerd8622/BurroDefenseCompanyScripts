# Yuck, powershell...

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Run as Administrator."
    exit 1
}


#Write-Host "Update!"
#if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
#    Install-Module -Name PSWindowsUpdate -Force
#}
#Import-Module PSWindowsUpdate
#Get-WUInstall -AcceptAll -AutoReboot

Write-Host "Firewall!"
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True

Get-NetFirewallRule | Remove-NetFirewallRule

Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultInboundAction Block -DefaultOutboundAction Block

New-NetFirewallRule -DisplayName "Allow DNS Inbound" -Direction Inbound -Protocol UDP -LocalPort 53 -Action Allow
New-NetFirewallRule -DisplayName "Allow DNS Outbound" -Direction Outbound -Protocol UDP -RemotePort 53 -Action Allow

Get-NetFirewallRule | Where-Object { $_.Enabled -eq $true } | Format-Table -Property DisplayName, Direction, Action, Protocol, LocalPort, RemotePort

Write-Host "Users!"
$essentialUsers = @("Administrator", "Guest")
$users = Get-LocalUser | Where-Object { $_.Enabled -eq $true }
foreach ($user in $users) {
    if ($essentialUsers -notcontains $user.Name) {
        Remove-LocalUser -Name $user.Name -ErrorAction SilentlyContinue
    }
}

$securePassword = ConvertTo-SecureString "NewPassword123!" -AsPlainText -Force
Set-LocalUser -Name "Administrator" -Password $securePassword -ErrorAction Stop

Write-Host "Remaining User List:"
Get-LocalUser | Where-Object { $_.Enabled -eq $true } | Select-Object -ExpandProperty Name

Write-Host "Feature Purge!"
$essentialFeatures = @(
    "DNS",
    "RSAT-DNS-Server",
    "PowerShell",
    "NET-Framework-Core"
)

$installedFeatures = Get-WindowsFeature | Where-Object { $_.Installed -eq $true }
foreach ($feature in $installedFeatures) {
    if ($essentialFeatures -notcontains $feature.Name) {
        Write-Host "Removing feature: $($feature.Name)"
        Uninstall-WindowsFeature -Name $feature.Name -Remove -ErrorAction SilentlyContinue
    }
}
