Import-Module -Name Microsoft.PowerShell.Crescendo


Export-CrescendoModule -ConfigurationFile $PWD/Microsoft.PowerShell.Crescendo/0.6.1/Samples/mstsc.Crescendo.json -ModuleName $PWD/MSTSC/RemoteComputer.psm1 -Force
Import-Module -Name $PWD/MSTSC/RemoteComputer.psm1 -Force
Connect-RemoteComputer -ComputerName SRV-2K22 -w 800 -h 600



Connect-RemoteComputer -ComputerName SRV-2K22 

Get-Help Connect-RemoteComputer

