# Module created by Microsoft.PowerShell.Crescendo
class PowerShellCustomFunctionAttribute : System.Attribute { 
    [bool]$RequiresElevation
    [string]$Source
    PowerShellCustomFunctionAttribute() { $this.RequiresElevation = $false; $this.Source = "Microsoft.PowerShell.Crescendo" }
    PowerShellCustomFunctionAttribute([bool]$rElevation) {
        $this.RequiresElevation = $rElevation
        $this.Source = "Microsoft.PowerShell.Crescendo"
    }
}



function Connect-RemoteComputer
{
[PowerShellCustomFunctionAttribute(RequiresElevation=$False)]
[CmdletBinding(DefaultParameterSetName='All')]

param(
[Parameter(ParameterSetName='All')]
[Parameter(ParameterSetName='Taille')]
[String]$ComputerName,
[Parameter(ParameterSetName='All')]
[Parameter(ParameterSetName='Taille')]
[Switch]$Admin,
[Parameter(ParameterSetName='All')]
[Switch]$FullScreen,
[Parameter(ParameterSetName='All')]
[Switch]$MultiMonitor,
[Parameter(ParameterSetName='All')]
[Parameter(ParameterSetName='Taille')]
[Switch]$Prompt,
[Parameter(ParameterSetName='Taille')]
[Int]$Width = "800",
[Parameter(ParameterSetName='Taille')]
[Int]$Height = "600",
[Parameter(ParameterSetName='All')]
[Parameter(ParameterSetName='Taille')]
[Int]$Shadow,
[Parameter(ParameterSetName='All')]
[Parameter(ParameterSetName='Taille')]
[Switch]$Control,
[Parameter(ParameterSetName='All')]
[Parameter(ParameterSetName='Taille')]
[Switch]$NoConsent
    )

BEGIN {
    $__PARAMETERMAP = @{
         ComputerName = @{
               OriginalName = '/v'
               OriginalPosition = '0'
               Position = '2147483647'
               ParameterType = 'String'
               NoGap = $False
               }
         Admin = @{
               OriginalName = '/admin'
               OriginalPosition = '0'
               Position = '2147483647'
               ParameterType = 'Switch'
               NoGap = $False
               }
         FullScreen = @{
               OriginalName = '/f'
               OriginalPosition = '0'
               Position = '2147483647'
               ParameterType = 'Switch'
               NoGap = $False
               }
         MultiMonitor = @{
               OriginalName = '/multimon'
               OriginalPosition = '0'
               Position = '2147483647'
               ParameterType = 'Switch'
               NoGap = $False
               }
         Prompt = @{
               OriginalName = '/prompt'
               OriginalPosition = '0'
               Position = '2147483647'
               ParameterType = 'Switch'
               NoGap = $False
               }
         Width = @{
               OriginalName = '/w'
               OriginalPosition = '0'
               Position = '2147483647'
               ParameterType = 'Int'
               NoGap = $False
               }
         Height = @{
               OriginalName = '/h'
               OriginalPosition = '0'
               Position = '2147483647'
               ParameterType = 'Int'
               NoGap = $False
               }
         Shadow = @{
               OriginalName = '/shadow'
               OriginalPosition = '0'
               Position = '2147483647'
               ParameterType = 'Int'
               NoGap = $False
               }
         Control = @{
               OriginalName = '/control'
               OriginalPosition = '0'
               Position = '2147483647'
               ParameterType = 'Switch'
               NoGap = $False
               }
         NoConsent = @{
               OriginalName = '/NoConsentPrompt'
               OriginalPosition = '0'
               Position = '2147483647'
               ParameterType = 'Switch'
               NoGap = $False
               }
    }

    $__outputHandlers = @{ Default = @{ StreamOutput = $true; Handler = { $input } } }
}

PROCESS {
    $__commandArgs = @()
    $__boundparms = $PSBoundParameters
    $MyInvocation.MyCommand.Parameters.Values.Where({$_.SwitchParameter -and $_.Name -notmatch "Debug|Whatif|Confirm|Verbose" -and ! $PSBoundParameters[$_.Name]}).ForEach({$PSBoundParameters[$_.Name] = [switch]::new($false)})
    if ($PSBoundParameters["Debug"]){wait-debugger}
    foreach ($paramName in $PSBoundParameters.Keys|Sort-Object {$__PARAMETERMAP[$_].OriginalPosition}) {
        $value = $PSBoundParameters[$paramName]
        $param = $__PARAMETERMAP[$paramName]
        if ($param) {
            if ( $value -is [switch] ) { $__commandArgs += if ( $value.IsPresent ) { $param.OriginalName } else { $param.DefaultMissingValue } }
            elseif ( $param.NoGap ) { $__commandArgs += "{0}""{1}""" -f $param.OriginalName, $value }
            else { $__commandArgs += $param.OriginalName; $__commandArgs += $value |Foreach-Object {$_}}
        }
    }
    $__commandArgs = $__commandArgs|Where-Object {$_}
    if ($PSBoundParameters["Debug"]){wait-debugger}
    if ( $PSBoundParameters["Verbose"]) {
         Write-Verbose -Verbose -Message mstsc.exe
         $__commandArgs | Write-Verbose -Verbose
    }
    $__handlerInfo = $__outputHandlers[$PSCmdlet.ParameterSetName]
    if (! $__handlerInfo ) {
        $__handlerInfo = $__outputHandlers["Default"] # Guaranteed to be present
    }
    $__handler = $__handlerInfo.Handler
    if ( $PSCmdlet.ShouldProcess("mstsc.exe $__commandArgs")) {
        if ( $__handlerInfo.StreamOutput ) {
            & "mstsc.exe" $__commandArgs | & $__handler
        }
        else {
            $result = & "mstsc.exe" $__commandArgs
            & $__handler $result
        }
    }
  } # end PROCESS

<#
.SYNOPSIS


.DESCRIPTION See help for mstsc.exe

.PARAMETER ComputerName



.PARAMETER Admin



.PARAMETER FullScreen



.PARAMETER MultiMonitor



.PARAMETER Prompt



.PARAMETER Width



.PARAMETER Height



.PARAMETER Shadow
Num??ro de la session ?? contr??ler


.PARAMETER Control
Prise de main sur une session a distance


.PARAMETER NoConsent
Prise de main sans le consentement de l'utilisateur



#>
}


