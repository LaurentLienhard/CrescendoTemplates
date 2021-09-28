# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License
# this contains code common for all generators
# OM VERSION 1.2
# =========================================================================
using namespace System.Collections.Generic
class UsageInfo { # used for .SYNOPSIS of the comment-based help
    [string]$Synopsis
    [bool]$SupportsFlags
    [bool]$HasOptions
    hidden [string[]]$OriginalText

    UsageInfo() { }
    UsageInfo([string] $synopsis)
    {
        $this.Synopsis = $synopsis
    }

    [string]ToString() #  this is to be replaced with actual generation code
    {
        return ((".SYNOPSIS",$this.synopsis) -join "`n")
    }
}

class ExampleInfo { # used for .EXAMPLE of the comment-based help
    [string]$Command # ps-command
    [string]$OriginalCommand # original native tool command
    [string]$Description

    ExampleInfo() { }

    ExampleInfo([string]$Command, [string]$OriginalCommand, [string]$Description)
    {
        $this.Command = $Command
        $this.OriginalCommand = $OriginalCommand
        $this.Description = $description
    }

    [string]ToString() #  this is to be replaced with actual generation code
    {
        $sb = [text.stringbuilder]::new()
        $sb.AppendLine(".EXAMPLE")
        $sb.AppendLine("PS> " + $this.Command)
        $sb.AppendLine("")
        $sb.AppendLine($this.Description)
        $sb.AppendLine("Original Command: " + $this.OriginalCommand)
        return $sb.ToString()
    }
}


class ParameterInfo {
    [string]$Name # PS-function name
    [string]$OriginalName # original native parameter name

    [string]$OriginalText
    [string]$Description
    [string]$DefaultValue
    # some parameters are -param or +param which can be represented with a switch parameter
    # so we need way to provide for this
    [string]$DefaultMissingValue
    [string]$ParameterType = 'object' # PS type

    [string[]]$AdditionalParameterAttributes

    [bool] $Mandatory
    [string[]] $ParameterSetName
    [string[]] $Aliases
    [int] $Position = [int]::MaxValue
    [int] $OriginalPosition
    [bool] $ValueFromPipeline
    [bool] $ValueFromPipelineByPropertyName
    [bool] $ValueFromRemainingArguments
    [bool] $NoGap # this means that we need to construct the parameter as "foo=bar"

    ParameterInfo() {
        $this.Position = [int]::MaxValue
    }
    ParameterInfo ([string]$Name, [string]$OriginalName)
    {
        $this.Name = $Name
        $this.OriginalName = $OriginalName
        $this.Position = [int]::MaxValue
    }

    [string]ToString() #  this is to be replaced with actual generation code
    {
        if ($this.Name -eq [string]::Empty) {
            return $null
        }
        $sb = [System.Text.StringBuilder]::new()
        if ( $this.AdditionalParameterAttributes )
        {
            foreach($s in $this.AdditionalParameterAttributes) {
                $sb.AppendLine($s)
            }
        }

        if ( $this.Aliases ) {
            $paramAliases = $this.Aliases -join "','"
            $sb.AppendLine("[Alias('" + $paramAliases + "')]")
        }

        # TODO: This logic does not handle parameters in multiple sets correctly

        $elements = @()
        if ( $this.ParameterSetName.Count -eq 0) {
            $sb.Append('[Parameter(')
            if ( $this.Position -ne [int]::MaxValue ) { $elements += "Position=" + $this.Position }
            if ( $this.ValueFromPipeline ) { $elements += 'ValueFromPipeline=$true' }
            if ( $this.ValueFromPipelineByPropertyName ) { $elements += 'ValueFromPipelineByPropertyName=$true' }
            if ( $this.ValueFromRemainingArguments ) { $elements += 'ValueFromRemainingArguments=$true' }
            if ( $this.Mandatory ) { $elements += 'Mandatory=$true' }
            if ( $this.ValueFromRemainingArguments ) { $elements += 'ValueFromRemainingArguments=$true' }
            if ($elements.Count -gt 0) { $sb.Append(($elements -join ",")) }
            $sb.AppendLine(')]')
        }
        else {
            foreach($parameterSetName in $this.ParameterSetName) {
                $sb.Append('[Parameter(')
                if ( $this.Position -ne [int]::MaxValue ) { $elements += "Position=" + $this.Position }
                if ( $this.ValueFromPipeline ) { $elements += 'ValueFromPipeline=$true' }
                if ( $this.ValueFromPipelineByPropertyName ) { $elements += 'ValueFromPipelineByPropertyName=$true' }
                if ( $this.ValueFromRemainingArguments ) { $elements += 'ValueFromRemainingArguments=$true' }
                if ( $this.Mandatory ) { $elements += 'Mandatory=$true' }
                if ( $this.ValueFromRemainingArguments ) { $elements += 'ValueFromRemainingArguments=$true' }
                $elements += "ParameterSetName='{0}'" -f $parameterSetName
                if ($elements.Count -gt 0) { $sb.Append(($elements -join ",")) }
                $sb.AppendLine(')]')
                $elements = @()
            }
        }

        #if ( $this.ParameterSetName.Count -gt 1) {
        #    $this.ParameterSetName.ForEach({$sb.AppendLine(('[Parameter(ParameterSetName="{0}")]' -f $_))})
        #}
        $sb.Append(('[{0}]${1}' -f $this.ParameterType, $this.Name))
        if ( $this.DefaultValue ) {
            $sb.Append(' = "' + $this.DefaultValue + '"')
        }

        return $sb.ToString()
    }

    [string]GetParameterHelp()
    {
        $parameterSb = [System.Text.StringBuilder]::new()
        $null = $parameterSb.Append(".PARAMETER ")
        $null = $parameterSb.AppendLine($this.Name)
        $null = $parameterSb.AppendLine($this.Description)
        $null = $parameterSb.AppendLine()
        return $parameterSb.ToString()
    }
}

class OutputHandler {
    [string]$ParameterSetName
    [string]$Handler # This is a scriptblock which does the conversion to an object
    [string]$HandlerType # Inline, Function, or Script
    [bool]$StreamOutput # this indicates whether the output should be streamed to the handler
    OutputHandler() {
        $this.HandlerType = "Inline" # default is an inline script
    }
    [string]ToString() {
        $s = '        '
        if ($this.HandlerType -eq "Inline") {
            $s += '{0} = @{{ StreamOutput = ${1}; Handler = {{ {2} }} }}' -f $this.ParameterSetName, $this.StreamOutput, $this.Handler
        }
        elseif ($this.HandlerType -eq "Script") {
            $s += '{0} = @{{ StreamOutput = ${1}; Handler = "${{PSScriptRoot}}/{2}" }}' -f $this.ParameterSetName, $this.StreamOutput, $this.Handler
        }
        else { # function
            $s += '{0} = @{{ StreamOutput = ${1}; Handler = ''{2}'' }}' -f $this.ParameterSetName, $this.StreamOutput, $this.Handler
        }
        return $s
    }
}

class Elevation {
    [string]$Command
    [List[ParameterInfo]]$Arguments
}

class Command {
    [string]$Verb # PS-function name verb
    [string]$Noun # PS-function name noun


    [string]$OriginalName # e.g. "cubectl get user" -> "cubectl"
    [string[]]$OriginalCommandElements # e.g. "cubectl get user" -> "get", "user"
    [string[]]$Platform # can be any (or all) of "Windows","Linux","MacOS"

    [Elevation]$Elevation

    [string[]] $Aliases
    [string] $DefaultParameterSetName
    [bool] $SupportsShouldProcess
    [bool] $SupportsTransactions
    [bool] $NoInvocation # certain scenarios want to use the generated code as a front end. When true, the generated code will return the arguments only.

    [string]$Description
    [UsageInfo]$Usage
    [List[ParameterInfo]]$Parameters
    [List[ExampleInfo]]$Examples
    [string]$OriginalText
    [string[]]$HelpLinks

    [OutputHandler[]]$OutputHandlers

    Command() {
        $this.Platform = "Windows","Linux","MacOS"
    }
    Command([string]$Verb, [string]$Noun)
    {
        $this.Verb = $Verb
        $this.Noun = $Noun
        $this.Parameters = [List[ParameterInfo]]::new()
        $this.Examples = [List[ExampleInfo]]::new()
        $this.Platform = "Windows","Linux","MacOS"
    }

    [string]GetDescription() {
        if ( $this.Description ) {
            return (".DESCRIPTION",$this.Description -join "`n")
        }
        else {
            return (".DESCRIPTION",("See help for {0}" -f $this.OriginalName))
        }
    }

    [string]GetSynopsis() {
        if ( $this.Description ) {
            return ([string]$this.Usage)
        }
        else { # try running the command with -?
            if ( Get-Command $this.OriginalName -ErrorAction ignore ) {
                try {
                    $origOutput = & $this.OriginalName -? 2>&1
                    $nativeHelpText = $origOutput -join "`n"
                }
                catch {
                    $nativeHelpText = "error running " + $this.OriginalName + " -?."
                }
            }
            else {
                $nativeHelpText = "Could not find " + $this.OriginalName + " to generate help."

            }
            return (".SYNOPSIS",$nativeHelpText) -join "`n"
        }
    }

    [string]GetFunctionHandlers()
    {
        # 
        $functionSB = [System.Text.StringBuilder]::new()
        if ( $this.OutputHandlers ) {
            foreach ($handler in $this.OutputHandlers ) {
                if ( $handler.HandlerType -eq "Function" ) {
                    $handlerName = $handler.Handler
                    $functionHandler = Get-Content function:$handlerName -ErrorAction Ignore
                    if ( $null -eq $functionHandler ) {
                        throw "Cannot find function '$handlerName'."
                    }
                    $functionSB.AppendLine($functionHandler.Ast.Extent.Text)
                }
            }
        }
        return $functionSB.ToString()
    }

    [string]ToString()
    {
        return $this.ToString($false)
    }

    [string]GetBeginBlock()
    {
        $sb = [System.Text.StringBuilder]::new()
        $sb.AppendLine("BEGIN {")
        # get the parameter map, this may be null if there are no parameters
        $parameterMap = $this.GetParameterMap()
        if ( $parameterMap ) {
            $sb.AppendLine($parameterMap)
        }
        # Provide for the scriptblocks which handle the output
        if ( $this.OutputHandlers ) {
            $sb.AppendLine('    $__outputHandlers = @{')
            foreach($handler in $this.OutputHandlers) {
                $sb.AppendLine($handler.ToString())
            }
            $sb.AppendLine('    }')
        }
        else {
            $sb.AppendLine('    $__outputHandlers = @{ Default = @{ StreamOutput = $true; Handler = { $input } } }')
        }
        $sb.AppendLine("}") # END BEGIN
        return $sb.ToString()
    }

    [string]GetProcessBlock()
    {
        # construct the command invocation
        # this must exist and should never be null
        # otherwise we won't actually be invoking anything
        $sb = [System.Text.StringBuilder]::new()
        $sb.AppendLine("PROCESS {")
        if ($this.OriginalCommandElements.Count -ne 0) {
            $sb.AppendLine('    $__commandArgs = @(')
            foreach($element in $this.OriginalCommandElements) {
                # we use single quotes here to reduce injection attacks
                $sb.AppendLine('        ''{0}''' -f $element)
            }
            $sb.AppendLine('    )')
        }
        else {
            $sb.AppendLine('    $__commandArgs = @()')
        }
        $sb.AppendLine($this.GetInvocationCommand())

        # add the help
        $help = $this.GetCommandHelp()
        if ($help) {
            $sb.AppendLine($help)
        }
        # finish the block
        $sb.AppendLine("}")
        return $sb.ToString()
    }

    # emit the function, if EmitAttribute is true, the Crescendo attribute will be included
    [string]ToString([bool]$EmitAttribute)
    {
        $sb = [System.Text.StringBuilder]::new()
        # emit any output handlers which are functions,
        # they're available only in the exported module.
        $sb.AppendLine($this.GetFunctionHandlers())

        $sb.AppendLine()
        # get the command declaration
        $sb.AppendLine($this.GetCommandDeclaration($EmitAttribute))
        # We will always provide a parameter block, even if it's empty
        $sb.AppendLine($this.GetParameters())

        # get the begin block
        $sb.AppendLine($this.GetBeginBlock())

        # get the process block
        $sb.AppendLine($this.GetProcessBlock())

        # return $this.Verb + "-" + $this.Noun
        return $sb.ToString()
    }

    [string]GetParameterMap() {
        $sb = [System.Text.StringBuilder]::new()
        if ( $this.Parameters.Count -eq 0 ) {
            return '    $__PARAMETERMAP = @{}'
        }
        $sb.AppendLine('    $__PARAMETERMAP = @{')
        foreach($parameter in $this.Parameters) {
            $sb.AppendLine(('         {0} = @{{' -f $parameter.Name))
            $sb.AppendLine(('               OriginalName = ''{0}''' -f $parameter.OriginalName))
            $sb.AppendLine(('               OriginalPosition = ''{0}''' -f $parameter.OriginalPosition))
            $sb.AppendLine(('               Position = ''{0}''' -f $parameter.Position))
            $sb.AppendLine(('               ParameterType = ''{0}''' -f $parameter.ParameterType))
            $sb.AppendLine(('               NoGap = ${0}' -f $parameter.NoGap))
            if($parameter.DefaultMissingValue) {
                $sb.AppendLine(('               DefaultMissingValue = ''{0}''' -f $parameter.DefaultMissingValue))
            }
            $sb.AppendLine('               }')
        }
        # end parameter map
        $sb.AppendLine("    }")
        return $sb.ToString()
    }

    [string]GetCommandHelp() {
        $helpSb = [System.Text.StringBuilder]::new()
        $helpSb.AppendLine("<#")
        $helpSb.AppendLine($this.GetSynopsis())
        $helpSb.AppendLine()
        $helpSb.AppendLine($this.GetDescription())
        $helpSb.AppendLine()
        if ( $this.Parameters.Count -gt 0 ) {
            foreach ( $parameter in $this.Parameters) {
                $helpSb.AppendLine($parameter.GetParameterHelp())
            }
            $helpSb.AppendLine();
        }
        if ( $this.Examples.Count -gt 0 ) {
            foreach ( $example in $this.Examples ) {
                $helpSb.AppendLine($example.ToString())
                $helpSb.AppendLine()
            }
        }
        if ( $this.HelpLinks.Count -gt 0 ) {
            $helpSB.AppendLine(".LINK");
            foreach ( $link in $this.HelpLinks ) {
                $helpSB.AppendLine($link.ToString())
            }
            $helpSb.AppendLine()
        }
        $helpSb.Append("#>")
        return $helpSb.ToString()
    }

    # this is where the logic of actually calling the command is created
    [string]GetInvocationCommand() {
        $sb = [System.Text.StringBuilder]::new()
        $sb.AppendLine('    $__boundparms = $PSBoundParameters') # debugging assistance
        $sb.AppendLine('    $MyInvocation.MyCommand.Parameters.Values.Where({$_.SwitchParameter -and $_.Name -notmatch "Debug|Whatif|Confirm|Verbose" -and ! $PSBoundParameters[$_.Name]}).ForEach({$PSBoundParameters[$_.Name] = [switch]::new($false)})')
        $sb.AppendLine('    if ($PSBoundParameters["Debug"]){wait-debugger}')
        $sb.AppendLine('    foreach ($paramName in $PSBoundParameters.Keys|Sort-Object {$__PARAMETERMAP[$_].OriginalPosition}) {')
        $sb.AppendLine('        $value = $PSBoundParameters[$paramName]')
        $sb.AppendLine('        $param = $__PARAMETERMAP[$paramName]')
        $sb.AppendLine('        if ($param) {')
        $sb.AppendLine('            if ( $value -is [switch] ) { $__commandArgs += if ( $value.IsPresent ) { $param.OriginalName } else { $param.DefaultMissingValue } }')
        # $sb.AppendLine('            elseif ( $param.Position -ne [int]::MaxValue ) { $__commandArgs += $value }')
        $sb.AppendLine('            elseif ( $param.NoGap ) { $__commandArgs += "{0}""{1}""" -f $param.OriginalName, $value }')
        $sb.AppendLine('            else { $__commandArgs += $param.OriginalName; $__commandArgs += $value |Foreach-Object {$_}}')
        $sb.AppendLine('        }')
        $sb.AppendLine('    }')
        $sb.AppendLine('    $__commandArgs = $__commandArgs|Where-Object {$_}') # strip nulls
        if ( $this.NoInvocation ) {
        $sb.AppendLine('    return $__commandArgs')
        }
        else {
        $sb.AppendLine('    if ($PSBoundParameters["Debug"]){wait-debugger}')
        $sb.AppendLine('    if ( $PSBoundParameters["Verbose"]) {')
        $sb.AppendLine('         Write-Verbose -Verbose -Message ' + $this.OriginalName)
        $sb.AppendLine('         $__commandArgs | Write-Verbose -Verbose')
        $sb.AppendLine('    }')
        $sb.AppendLine('    $__handlerInfo = $__outputHandlers[$PSCmdlet.ParameterSetName]')
        $sb.AppendLine('    if (! $__handlerInfo ) {')
        $sb.AppendLine('        $__handlerInfo = $__outputHandlers["Default"] # Guaranteed to be present')
        $sb.AppendLine('    }')
        $sb.AppendLine('    $__handler = $__handlerInfo.Handler')
        $sb.AppendLine('    if ( $PSCmdlet.ShouldProcess("' + $this.OriginalName + ' $__commandArgs")) {')
        $sb.AppendLine('        if ( $__handlerInfo.StreamOutput ) {')
        if ( $this.Elevation.Command ) {
            $__elevationArgs = $($this.Elevation.Arguments | Foreach-Object { "{0} {1}" -f $_.OriginalName, $_.DefaultValue }) -join " "
            $sb.AppendLine(('            & "{0}" {1} "{2}" $__commandArgs | & $__handler' -f $this.Elevation.Command, $__elevationArgs, $this.OriginalName))
        }
        else {
            $sb.AppendLine(('            & "{0}" $__commandArgs | & $__handler' -f $this.OriginalName))
        }
        $sb.AppendLine('        }')
        $sb.AppendLine('        else {')
        if ( $this.Elevation.Command ) {
            $__elevationArgs = $($this.Elevation.Arguments | Foreach-Object { "{0} {1}" -f $_.OriginalName, $_.DefaultValue }) -join " "
            $sb.AppendLine(('            $result = & "{0}" {1} "{2}" $__commandArgs' -f $this.Elevation.Command, $__elevationArgs, $this.OriginalName))
        }
        else {
            $sb.AppendLine(('            $result = & "{0}" $__commandArgs' -f $this.OriginalName))
        }
        $sb.AppendLine('            & $__handler $result')
        $sb.AppendLine('        }')
        $sb.AppendLine("    }")
        }
        $sb.AppendLine("  } # end PROCESS") # always present
        return $sb.ToString()
    }
    [string]GetCrescendoAttribute()
    {
        return('[PowerShellCustomFunctionAttribute(RequiresElevation=${0})]' -f (($null -eq $this.Elevation.Command) ? $false : $true))
    }
    [string]GetCommandDeclaration([bool]$EmitAttribute) {
        $sb = [System.Text.StringBuilder]::new()
        $sb.AppendFormat("function {0}`n", $this.FunctionName)
        $sb.AppendLine("{")
        if ( $EmitAttribute ) {
            $sb.AppendLine($this.GetCrescendoAttribute())
        }
        $sb.Append("[CmdletBinding(")
        $addlAttributes = @()
        if ( $this.SupportsShouldProcess ) {
            $addlAttributes += 'SupportsShouldProcess=$true'
        }
        if ( $this.DefaultParameterSetName ) {
            $addlAttributes += 'DefaultParameterSetName=''{0}''' -f $this.DefaultParameterSetName
        }
        $sb.Append(($addlAttributes -join ','))
        $sb.AppendLine(")]")
        return $sb.ToString()
    }
    [string]GetParameters() {
        $sb = [System.Text.StringBuilder]::new()
        $sb.Append("param(")
        if ($this.Parameters.Count -gt 0) {
            $sb.AppendLine()
            $params = $this.Parameters|ForEach-Object {$_.ToString()}
            $sb.AppendLine(($params -join ",`n"))
        }
        $sb.AppendLine("    )")
        return $sb.ToString()
    }

}
# =========================================================================

# function to test whether there is a parser error in the output handler
function Test-Handler {
    param (
        [Parameter(Mandatory=$true)][string]$script,
        [Parameter(Mandatory=$true)][ref]$parserErrors
    )
    $null = [System.Management.Automation.Language.Parser]::ParseInput($script, [ref]$null, $parserErrors)
    (0 -eq $parserErrors.Value.Count)
}

# functions to create the classes since you can't access the classes outside the module
function New-ParameterInfo {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions","")]
    param (
        [Parameter(Position=0,Mandatory=$true)][string]$Name,
        [Parameter(Position=1,Mandatory=$true)][AllowEmptyString()][string]$OriginalName
    )
    [ParameterInfo]::new($Name, $OriginalName)
}

function New-UsageInfo {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions","")]
    param (
        [Parameter(Position=0,Mandatory=$true)][string]$usage
        )
    [UsageInfo]::new($usage)
}

function New-ExampleInfo {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions","")]
    param (
        [Parameter(Position=0,Mandatory=$true)][string]$command,
        [Parameter(Position=1,Mandatory=$true)][string]$originalCommand,
        [Parameter(Position=2,Mandatory=$true)][string]$description
        )
    [ExampleInfo]::new($command, $originalCommand, $description)
}

function New-CrescendoCommand {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions","")]
    param (
        [Parameter(Position=0,Mandatory=$true)][string]$Verb,
        [Parameter(Position=1,Mandatory=$true)][string]$Noun
    )
    [Command]::new($Verb, $Noun)
}

function Import-CommandConfiguration
{
[CmdletBinding()]
param ([Parameter(Position=0,Mandatory=$true)][string]$file)
<#
.SYNOPSIS

Import a PowerShell Crescendo json file.

.DESCRIPTION

This cmdlet exports an object that can be converted into a function that acts as a proxy for the platform specific command.
The resultant object may then be used to call a native command that can participate in the PowerShell pipeline.
The ToString method of the output object returns a string that can be used to create a function that calls the native command.
Microsoft Windows, Linux, and macOS can run the generated function, if the native command is on all of the platform.

.PARAMETER File

The json file which represents the command to be wrapped.

.EXAMPLE

PS> Import-CommandConfiguration ifconfig.crescendo.json

Verb                    : Invoke
Noun                    : ifconfig
OriginalName            : ifconfig
OriginalCommandElements :
Aliases                 :
DefaultParameterSetName :
SupportsShouldProcess   : False
SupportsTransactions    : False
NoInvocation            : False
Description             : This is a description of the generated function
Usage                   : .SYNOPSIS
                          Run invoke-ifconfig
Parameters              : {[Parameter()]
                          [string]$Interface = ""}
Examples                :
OriginalText            :
HelpLinks               :
OutputHandlers          :

.NOTES

The object returned by Import-CommandConfiguration is converted through the ToString method.
Generally, you should use the Export-CrescendoModule function, which creates a PowerShell .psm1 file.

.OUTPUTS

A Command object

.LINK

Export-CrescendoModule

#>
    $options = [System.Text.Json.JsonSerializerOptions]::new()
    # this dance is to support multiple configurations in a single file
    # The deserializer doesn't seem to support creating [command[]]
    Get-Content $file |
        ConvertFrom-Json -depth 10| 
        Foreach-Object {$_.Commands} |
        ForEach-Object { $_ | ConvertTo-Json -depth 10 |
            Foreach-Object {
                $configuration = [System.Text.Json.JsonSerializer]::Deserialize($_, [command], $options)
                $errs = $null
                if (!(Test-Configuration -configuration $configuration -errors ([ref]$errs))) {
                    $errs | Foreach-Object { Write-Error -ErrorRecord $_ }
                }

                # emit the configuration even if there was an error
                $configuration
            }
        }
}

function Test-Configuration 
{
    param ([Command]$Configuration, [ref]$errors)

    $configErrors = @()
    $configurationOK = $true

    # Validate the Platform types
    $allowedPlatforms = "Windows","Linux","MacOS"
    foreach($platform in $Configuration.Platform) {
        if ($allowedPlatforms -notcontains $platform) {
            $configurationOK = $false
            $e = [System.Management.Automation.ErrorRecord]::new(
                [Exception]::new("Platform '$platform' is not allowed. Use 'Windows', 'Linux', or 'MacOS'"),
                "ParserError",
                "InvalidArgument",
                "Import-CommandConfiguration:Platform")
            $configErrors += $e
        }
    }

    # Validate the output handlers in the configuration
    foreach ( $handler in $configuration.OutputHandlers ) {
        $parserErrors = $null
        if ( -not (Test-Handler -Script $handler.Handler -ParserErrors ([ref]$parserErrors))) {
            $configurationOK = $false
            $exceptionMessage = "OutputHandler Error in '{0}' for ParameterSet '{1}'" -f $configuration.FunctionName, $handler.ParameterSetName
            $e = [System.Management.Automation.ErrorRecord]::new(
                ([Exception]::new($exceptionMessage)),
                "Import-CommandConfiguration:OutputHandler",
                "ParserError",
                $parserErrors)
            $configErrors += $e
        }
    }
    if ($configErrors.Count -gt 0) {
        $errors.Value = $configErrors
    }

    return $configurationOK

}

function Export-Schema() {
    $sGen = [Newtonsoft.Json.Schema.JsonSchemaGenerator]::new()
    $sGen.Generate([command])
}

function Export-CrescendoModule
{
<#
.SYNOPSIS

Creates a module from PowerShell Crescendo JSON configuration files

.DESCRIPTION

This cmdlet exports an object that can be converted into a function that acts as a proxy for a platform specific command.
The resultant module file should be executable down to version 5.1 of PowerShell.


.PARAMETER ConfigurationFile

This is a list of JSON files that represent the proxies for the module

.PARAMETER ModuleName

The name of the module file you wish to create.
You can omit the trailing .psm1.

.PARAMETER Force

By default, if Export-CrescendoModule finds an already created module, it will not overwrite the existing file.
Use -Force to overwrite the existing file, or remove it prior to running Export-CrescendoModule.

.EXAMPLE

PS> Export-CrescendoModule -ModuleName netsh -ConfigurationFile netsh*.json
PS> Import-Module ./netsh.psm1

.EXAMPLE

PS> Export-CrescendoModule netsh netsh*.json -force

.NOTES

Internally, this function calls the Import-CommandConfiguration cmdlet that returns a command object.
All files provided in the -ConfigurationFile parameter are then used to create each individual function.
Finally, all proxies are used to create an Export-ModuleMember command invocation, so when the resultant module is
imported, the module has all the command proxies available.

.OUTPUTS

None

.LINK

Import-CommandConfiguration

#>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Position=1,Mandatory=$true,ValueFromPipelineByPropertyName=$true)][SupportsWildcards()][string[]]$ConfigurationFile,
        [Parameter(Position=0,Mandatory=$true)][string]$ModuleName,
        [Parameter()][switch]$Force
        )
    BEGIN {
        [array]$crescendoCollection = @()
        if ($ModuleName -notmatch "\.psm1$") {
            $ModuleName += ".psm1"
        }
        if (-not $PSCmdlet.ShouldProcess("Creating Module '$ModuleName'"))
        {
            return
        }
        if ((Test-Path $ModuleName) -and -not $Force) {
            throw "$ModuleName already exists"
        }
        # static parts of the crescendo module
        "# Module created by Microsoft.PowerShell.Crescendo" > $ModuleName
        'class PowerShellCustomFunctionAttribute : System.Attribute { '>> $ModuleName
        '    [bool]$RequiresElevation' >> $ModuleName
        '    [string]$Source' >> $ModuleName
        '    PowerShellCustomFunctionAttribute() { $this.RequiresElevation = $false; $this.Source = "Microsoft.PowerShell.Crescendo" }' >> $ModuleName
        '    PowerShellCustomFunctionAttribute([bool]$rElevation) {' >> $ModuleName
        '        $this.RequiresElevation = $rElevation' >> $ModuleName
        '        $this.Source = "Microsoft.PowerShell.Crescendo"' >> $ModuleName
        '    }' >> $ModuleName
        '}' >> $ModuleName
        '' >> $ModuleName
        $moduleBase = [System.IO.Path]::GetDirectoryName($ModuleName)
    }
    PROCESS {
        if ( $PSBoundParameters['WhatIf'] ) {
            return
        }
        $resolvedConfigurationPaths = (Resolve-Path $ConfigurationFile).Path
        foreach($file in $resolvedConfigurationPaths) {
            Write-Verbose "Adding $file to Crescendo collection"
            $crescendoCollection += Import-CommandConfiguration $file
        }
    }
    END {
        if ( $PSBoundParameters['WhatIf'] ) {
            return
        }
        [string[]]$cmdletNames = @()
        [string[]]$aliases = @()
        [string[]]$SetAlias = @()
        [bool]$IncludeWindowsElevationHelper = $false
        foreach($proxy in $crescendoCollection) {
            if ($proxy.Elevation.Command -eq "Invoke-WindowsNativeAppWithElevation") {
                $IncludeWindowsElevationHelper = $true
            }
            $cmdletNames += $proxy.FunctionName
            if ( $proxy.Aliases ) {
                # we need the aliases without value for the psd1
                $proxy.Aliases.ForEach({$aliases += $_})
                # the actual set-alias command will be emited before the export-modulemember
                $proxy.Aliases.ForEach({$SetAlias += "Set-Alias -Name '{0}' -Value '{1}'" -f $_,$proxy.FunctionName})
            }
            # when set to true, we will emit the Crescendo attribute
            $proxy.ToString($true) >> $ModuleName
        }
        $SetAlias >> $ModuleName

        # include the windows helper if it has been included
        if ($IncludeWindowsElevationHelper) {
            (Get-Content function:Invoke-WindowsNativeAppWithElevation).Ast.Extent.Text >> $ModuleName
        }

        $ModuleManifestArguments = @{
            Path = $ModuleName -Replace "psm1$","psd1"
            RootModule = [io.path]::GetFileName(${ModuleName})
            Tags = "CrescendoBuilt"
            PowerShellVersion = "5.1.0"
            CmdletsToExport = @()
            AliasesToExport = @()
            VariablesToExport = @()
            FunctionsToExport = @()
            PrivateData = @{ CrescendoGenerated = Get-Date; CrescendoVersion = (Get-Module Microsoft.PowerShell.Crescendo).Version }
        }
        if ( $cmdletNames ) {
            $ModuleManifestArguments['FunctionsToExport'] = $cmdletNames
        }
        if ( $aliases ) {
            $ModuleManifestArguments['AliasesToExport'] = $aliases
        }

        New-ModuleManifest @ModuleManifestArguments

        #"Export-ModuleMember -Function $($cmdletNames -join ', ')" >> $ModuleName
        #if ( $aliases.Count -gt 0 ) {
        #    "Export-ModuleMember -Alias $($aliases -join ', ')" >> $ModuleName
        #}
        # copy the script output handlers into place
        foreach($config in $crescendoCollection) {
            foreach($handler in $config.OutputHandlers) {
                if ($handler.HandlerType -eq "Script") {
                    $scriptInfo = Get-Command -ErrorAction Ignore -CommandType ExternalScript $handler.Handler
                    if($scriptInfo) {
                        Copy-Item $scriptInfo.Source $moduleBase
                    }
                    else {
                        Write-Error -Category ObjectNotFound -TargetObject $scriptInfo.Source -Message "Handler not found." -RecommendedAction "Copy the handler to the module directory before packaging."
                    }
                }
            }
        }
    }
}

# This is an elevation function for Windows which may be distributed with a crescendo module
function Invoke-WindowsNativeAppWithElevation
{
    [CmdletBinding(DefaultParameterSetName="username")]
    param (
        [Parameter(Position=0,Mandatory=$true)][string]$command,
        [Parameter(ParameterSetName="credential")][PSCredential]$Credential,
        [Parameter(ParameterSetName="username")][string]$User = "Administrator",
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$cArguments
    )

    $app = "cmd.exe"
    $nargs = @("/c","cd","/d","%CD%","&&")
    $nargs += $command
    if ( $cArguments.count ) {
        $nargs += $cArguments
    }
    $__OUTPUT = Join-Path ([io.Path]::GetTempPath()) "CrescendoOutput.txt"
    $__ERROR  = Join-Path ([io.Path]::GetTempPath()) "CrescendoError.txt"
    if ( $Credential ) {
        $cred = $Credential
    }
    else {
        $cred = Get-Credential $User
    }

    $spArgs = @{
        Credential = $cred
        File = $app
        ArgumentList = $nargs
        RedirectStandardOutput = $__OUTPUT
        RedirectStandardError = $__ERROR
        WindowStyle = "Minimized"
        PassThru = $True
        ErrorAction = "Stop"
    }
    $timeout = 10000
    $sleepTime = 500
    $totalSleep = 0
    try {
        $p = start-process @spArgs
        while(!$p.HasExited) {
            Start-Sleep -mill $sleepTime
            $totalSleep += $sleepTime
            if ( $totalSleep -gt $timeout )
            {
                throw "'$(cArguments -join " ")' has timed out"
            }
        }
    }
    catch {
        # should we report error output?
        # It's most likely that there will be none if the process can't be started
        # or other issue with start-process. We catch actual error output from the
        # elevated command below.
        if ( Test-Path $__OUTPUT ) { Remove-Item $__OUTPUT }
        if ( Test-Path $__ERROR ) { Remove-Item $__ERROR }
        $msg = "Error running '{0} {1}'" -f $command,($cArguments -join " ")
        throw "$msg`n$_"
    }

    try {
        if ( test-path $__OUTPUT ) {
            $output = Get-Content $__OUTPUT
        }
        if ( test-path $__ERROR ) {
            $errorText = (Get-Content $__ERROR) -join "`n"
        }
    }
    finally {
        if ( $errorText ) {
            $exception = [System.Exception]::new($errorText)
            $errorRecord = [system.management.automation.errorrecord]::new(
                $exception,
                "CrescendoElevationFailure",
                "InvalidOperation",
                ("{0} {1}" -f $command,($cArguments -join " "))
                )
            # errors emitted during the application are not fatal
            Write-Error $errorRecord
        }
        if ( Test-Path $__OUTPUT ) { Remove-Item $__OUTPUT }
        if ( Test-Path $__ERROR ) { Remove-Item $__ERROR }
    }
    # return the output to the caller
    $output
}

class CrescendoCommandInfo {
    [string]$Module
    [string]$Source
    [string]$Name
    [bool]$IsCrescendoCommand
    [bool]$RequiresElevation
    CrescendoCommandInfo([string]$module, [string]$name, [Attribute]$attribute) {
        $this.Module = $module
        $this.Name = $name
        $this.IsCrescendoCommand = $null -eq $attribute ? $false : ($attribute.Source -eq "Microsoft.PowerShell.Crescendo")
        $this.RequiresElevation = $null -eq $attribute ? $false : $attribute.RequiresElevation
        $this.Source = $null -eq $attribute ? "" : $attribute.Source
    }
}

function Test-IsCrescendoCommand
{
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline=$true,Mandatory=$true,Position=0)]
        [object[]]$Command
    )
    PROCESS {
        # loop through the commands and determine whether it is a Crescendo Function
        foreach( $cmd in $Command) {
            $fInfo = $null
            if ($cmd -is [System.Management.Automation.FunctionInfo]) {
                $fInfo = $cmd
            }
            elseif ($cmd -is [string]) {
                $fInfo = Get-Command -Name $cmd -CommandType Function -ErrorAction Ignore
            }
            if(-not $fInfo) {
                Write-Error -Message "'$cmd' is not a function" -TargetObject "$cmd" -RecommendedAction "Be sure that the command is a function"
                continue
            }
            #  check for the PowerShellFunctionAttribute and report on findings
            $crescendoAttribute = $fInfo.ScriptBlock.Attributes|Where-Object {$_.TypeId.Name -eq "PowerShellCustomFunctionAttribute"} | Select-Object -Last 1
            [CrescendoCommandInfo]::new($fInfo.Source, $fInfo.Name, $crescendoAttribute)
        }
    }
}

# SIG # Begin signature block
# MIIjnwYJKoZIhvcNAQcCoIIjkDCCI4wCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBDR/WM84ulozuz
# HeDHOfMtqaReL2yu5OuEpasvLDqbxqCCDYEwggX/MIID56ADAgECAhMzAAAB32vw
# LpKnSrTQAAAAAAHfMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjAxMjE1MjEzMTQ1WhcNMjExMjAyMjEzMTQ1WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQC2uxlZEACjqfHkuFyoCwfL25ofI9DZWKt4wEj3JBQ48GPt1UsDv834CcoUUPMn
# s/6CtPoaQ4Thy/kbOOg/zJAnrJeiMQqRe2Lsdb/NSI2gXXX9lad1/yPUDOXo4GNw
# PjXq1JZi+HZV91bUr6ZjzePj1g+bepsqd/HC1XScj0fT3aAxLRykJSzExEBmU9eS
# yuOwUuq+CriudQtWGMdJU650v/KmzfM46Y6lo/MCnnpvz3zEL7PMdUdwqj/nYhGG
# 3UVILxX7tAdMbz7LN+6WOIpT1A41rwaoOVnv+8Ua94HwhjZmu1S73yeV7RZZNxoh
# EegJi9YYssXa7UZUUkCCA+KnAgMBAAGjggF+MIIBejAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUOPbML8IdkNGtCfMmVPtvI6VZ8+Mw
# UAYDVR0RBEkwR6RFMEMxKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVyYXRpb25zIFB1
# ZXJ0byBSaWNvMRYwFAYDVQQFEw0yMzAwMTIrNDYzMDA5MB8GA1UdIwQYMBaAFEhu
# ZOVQBdOCqhc3NyK1bajKdQKVMFQGA1UdHwRNMEswSaBHoEWGQ2h0dHA6Ly93d3cu
# bWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY0NvZFNpZ1BDQTIwMTFfMjAxMS0w
# Ny0wOC5jcmwwYQYIKwYBBQUHAQEEVTBTMFEGCCsGAQUFBzAChkVodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY0NvZFNpZ1BDQTIwMTFfMjAx
# MS0wNy0wOC5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQsFAAOCAgEAnnqH
# tDyYUFaVAkvAK0eqq6nhoL95SZQu3RnpZ7tdQ89QR3++7A+4hrr7V4xxmkB5BObS
# 0YK+MALE02atjwWgPdpYQ68WdLGroJZHkbZdgERG+7tETFl3aKF4KpoSaGOskZXp
# TPnCaMo2PXoAMVMGpsQEQswimZq3IQ3nRQfBlJ0PoMMcN/+Pks8ZTL1BoPYsJpok
# t6cql59q6CypZYIwgyJ892HpttybHKg1ZtQLUlSXccRMlugPgEcNZJagPEgPYni4
# b11snjRAgf0dyQ0zI9aLXqTxWUU5pCIFiPT0b2wsxzRqCtyGqpkGM8P9GazO8eao
# mVItCYBcJSByBx/pS0cSYwBBHAZxJODUqxSXoSGDvmTfqUJXntnWkL4okok1FiCD
# Z4jpyXOQunb6egIXvkgQ7jb2uO26Ow0m8RwleDvhOMrnHsupiOPbozKroSa6paFt
# VSh89abUSooR8QdZciemmoFhcWkEwFg4spzvYNP4nIs193261WyTaRMZoceGun7G
# CT2Rl653uUj+F+g94c63AhzSq4khdL4HlFIP2ePv29smfUnHtGq6yYFDLnT0q/Y+
# Di3jwloF8EWkkHRtSuXlFUbTmwr/lDDgbpZiKhLS7CBTDj32I0L5i532+uHczw82
# oZDmYmYmIUSMbZOgS65h797rj5JJ6OkeEUJoAVwwggd6MIIFYqADAgECAgphDpDS
# AAAAAAADMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0
# ZSBBdXRob3JpdHkgMjAxMTAeFw0xMTA3MDgyMDU5MDlaFw0yNjA3MDgyMTA5MDla
# MH4xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMT
# H01pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTEwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQCr8PpyEBwurdhuqoIQTTS68rZYIZ9CGypr6VpQqrgG
# OBoESbp/wwwe3TdrxhLYC/A4wpkGsMg51QEUMULTiQ15ZId+lGAkbK+eSZzpaF7S
# 35tTsgosw6/ZqSuuegmv15ZZymAaBelmdugyUiYSL+erCFDPs0S3XdjELgN1q2jz
# y23zOlyhFvRGuuA4ZKxuZDV4pqBjDy3TQJP4494HDdVceaVJKecNvqATd76UPe/7
# 4ytaEB9NViiienLgEjq3SV7Y7e1DkYPZe7J7hhvZPrGMXeiJT4Qa8qEvWeSQOy2u
# M1jFtz7+MtOzAz2xsq+SOH7SnYAs9U5WkSE1JcM5bmR/U7qcD60ZI4TL9LoDho33
# X/DQUr+MlIe8wCF0JV8YKLbMJyg4JZg5SjbPfLGSrhwjp6lm7GEfauEoSZ1fiOIl
# XdMhSz5SxLVXPyQD8NF6Wy/VI+NwXQ9RRnez+ADhvKwCgl/bwBWzvRvUVUvnOaEP
# 6SNJvBi4RHxF5MHDcnrgcuck379GmcXvwhxX24ON7E1JMKerjt/sW5+v/N2wZuLB
# l4F77dbtS+dJKacTKKanfWeA5opieF+yL4TXV5xcv3coKPHtbcMojyyPQDdPweGF
# RInECUzF1KVDL3SV9274eCBYLBNdYJWaPk8zhNqwiBfenk70lrC8RqBsmNLg1oiM
# CwIDAQABo4IB7TCCAekwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFEhuZOVQ
# BdOCqhc3NyK1bajKdQKVMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1Ud
# DwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFHItOgIxkEO5FAVO
# 4eqnxzHRI4k0MFoGA1UdHwRTMFEwT6BNoEuGSWh0dHA6Ly9jcmwubWljcm9zb2Z0
# LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcmwwXgYIKwYBBQUHAQEEUjBQME4GCCsGAQUFBzAChkJodHRwOi8vd3d3Lm1p
# Y3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcnQwgZ8GA1UdIASBlzCBlDCBkQYJKwYBBAGCNy4DMIGDMD8GCCsGAQUFBwIB
# FjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2RvY3MvcHJpbWFyeWNw
# cy5odG0wQAYIKwYBBQUHAgIwNB4yIB0ATABlAGcAYQBsAF8AcABvAGwAaQBjAHkA
# XwBzAHQAYQB0AGUAbQBlAG4AdAAuIB0wDQYJKoZIhvcNAQELBQADggIBAGfyhqWY
# 4FR5Gi7T2HRnIpsLlhHhY5KZQpZ90nkMkMFlXy4sPvjDctFtg/6+P+gKyju/R6mj
# 82nbY78iNaWXXWWEkH2LRlBV2AySfNIaSxzzPEKLUtCw/WvjPgcuKZvmPRul1LUd
# d5Q54ulkyUQ9eHoj8xN9ppB0g430yyYCRirCihC7pKkFDJvtaPpoLpWgKj8qa1hJ
# Yx8JaW5amJbkg/TAj/NGK978O9C9Ne9uJa7lryft0N3zDq+ZKJeYTQ49C/IIidYf
# wzIY4vDFLc5bnrRJOQrGCsLGra7lstnbFYhRRVg4MnEnGn+x9Cf43iw6IGmYslmJ
# aG5vp7d0w0AFBqYBKig+gj8TTWYLwLNN9eGPfxxvFX1Fp3blQCplo8NdUmKGwx1j
# NpeG39rz+PIWoZon4c2ll9DuXWNB41sHnIc+BncG0QaxdR8UvmFhtfDcxhsEvt9B
# xw4o7t5lL+yX9qFcltgA1qFGvVnzl6UJS0gQmYAf0AApxbGbpT9Fdx41xtKiop96
# eiL6SJUfq/tHI4D1nvi/a7dLl+LrdXga7Oo3mXkYS//WsyNodeav+vyL6wuA6mk7
# r/ww7QRMjt/fdW1jkT3RnVZOT7+AVyKheBEyIXrvQQqxP/uozKRdwaGIm1dxVk5I
# RcBCyZt2WwqASGv9eZ/BvW1taslScxMNelDNMYIVdDCCFXACAQEwgZUwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMQITMwAAAd9r8C6Sp0q00AAAAAAB3zAN
# BglghkgBZQMEAgEFAKCBrjAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgCdqhwoFK
# 8tJt0Q+J0a/nKId4vuehGDb+45+MOohCQxowQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQA5KYn7aRnj0oyq3OdB9GXdHvx831oXyt4lfugDjhc9
# /SFnVjvNmq1XkKO1ZH9f4k7IYfHEtCki+LNWogu2BAdnDpNBQ89kjgEloAdqrEVt
# c+J7DK9STKca/c0fOXLuIzgy0Bun2F8n2fa7Gv533Qz3UobT79d4YFG5jP3uTHF9
# feJvQFSo+db0nlIYWUFeWAFLGxn1O2AEZy5m3Idatzz8h1eLLcCM1bRHhQx4Af0q
# aVkHJjiiXnpuCB/6/JdZQzv2CSMzfUEQucOpgPYYWwS+4ZBV5RPC94G3dn5+NzC6
# 9edrsEsmCxgIhWilEkK1BJ7TrjPOj0xwvQtTBx5+SQRCoYIS/jCCEvoGCisGAQQB
# gjcDAwExghLqMIIS5gYJKoZIhvcNAQcCoIIS1zCCEtMCAQMxDzANBglghkgBZQME
# AgEFADCCAVkGCyqGSIb3DQEJEAEEoIIBSASCAUQwggFAAgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEINvhmfZ9/zpewhm1KS0GLne+5So7SFfBn8fLS/PH
# 51XJAgZgxVQcGI8YEzIwMjEwNzE2MTcxNDMxLjg1OVowBIACAfSggdikgdUwgdIx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1p
# Y3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEmMCQGA1UECxMdVGhh
# bGVzIFRTUyBFU046RkM0MS00QkQ0LUQyMjAxJTAjBgNVBAMTHE1pY3Jvc29mdCBU
# aW1lLVN0YW1wIFNlcnZpY2Wggg5NMIIE+TCCA+GgAwIBAgITMwAAAUAjGdZe3pUk
# MQAAAAABQDANBgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0Eg
# MjAxMDAeFw0yMDEwMTUxNzI4MjZaFw0yMjAxMTIxNzI4MjZaMIHSMQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQg
# SXJlbGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJjAkBgNVBAsTHVRoYWxlcyBUU1Mg
# RVNOOkZDNDEtNEJENC1EMjIwMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFt
# cCBTZXJ2aWNlMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEArn1rM3Hq
# 1S9N0z8R+YKqZu25ykk5OlT8TsuwtdBWyDCRFoASk9fB6siColFhXBhyej4c3yIw
# N0UyJWBOTAjHteOIYjfCpx539rbgBI5/BTHtC+qcBT7ftPknTtQn89lNOcpP70fu
# YVZLoQsDnLjGxxtW/eVewR5Q0I1mWQfJy5xOfelk5OWjz3YV4HKtqyIRzJZd/Rzc
# Y8w6qmzoSNsYIdvliT2eeQZbyYTdJQsRozIKTMLCJUBfVjow2fJMDtzDB9XEOdfh
# PWzvUOadYgqqh0lslAR7NV90FFmZgZWARrG8j7ZnVnC5MOXOS/NI58S48ycsug0p
# N2NGLLk2YWjxCwIDAQABo4IBGzCCARcwHQYDVR0OBBYEFDVDHC4md0YgjozSqnVs
# +OeELQ5nMB8GA1UdIwQYMBaAFNVjOlyKMZDzQ3t8RhvFM2hahW1VMFYGA1UdHwRP
# ME0wS6BJoEeGRWh0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1
# Y3RzL01pY1RpbVN0YVBDQV8yMDEwLTA3LTAxLmNybDBaBggrBgEFBQcBAQROMEww
# SgYIKwYBBQUHMAKGPmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMv
# TWljVGltU3RhUENBXzIwMTAtMDctMDEuY3J0MAwGA1UdEwEB/wQCMAAwEwYDVR0l
# BAwwCgYIKwYBBQUHAwgwDQYJKoZIhvcNAQELBQADggEBAGMMUq2gQuCC9wr4YhIS
# fPyobaNYV3Ov4YwWsSfIz/j1xaN9TvLAB2BxPi2CtRbgbBUf48n07yReZInwu2r8
# vwLoNG2TtYzey01DRyjjsNoiHF9UuRLFyKZChkKC3o9r0Oy2x0YYjUpDxVChZ5q5
# cAfw884wP0iUcYnKKGn8eJ0nwpr7zr/Tlu+HOjXDT9C754aS4KUFNm8D7iwuvWWz
# SOVl7XMWdu82BnnTmB7s2Ocf3I4adGzdixQ5Zxxa3zOAvKzrV+0HcVQIY3SQJ9Pz
# jDRlzCviMThxA8FUIRL3FnYqvchWkEoZ4w8S7FsGWNlXLWQ7fHMb3l4gjueHyO4p
# 6tUwggZxMIIEWaADAgECAgphCYEqAAAAAAACMA0GCSqGSIb3DQEBCwUAMIGIMQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNy
# b3NvZnQgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAxMDAeFw0xMDA3MDEy
# MTM2NTVaFw0yNTA3MDEyMTQ2NTVaMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpX
# YXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQg
# Q29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAy
# MDEwMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqR0NvHcRijog7PwT
# l/X6f2mUa3RUENWlCgCChfvtfGhLLF/Fw+Vhwna3PmYrW/AVUycEMR9BGxqVHc4J
# E458YTBZsTBED/FgiIRUQwzXTbg4CLNC3ZOs1nMwVyaCo0UN0Or1R4HNvyRgMlhg
# RvJYR4YyhB50YWeRX4FUsc+TTJLBxKZd0WETbijGGvmGgLvfYfxGwScdJGcSchoh
# iq9LZIlQYrFd/XcfPfBXday9ikJNQFHRD5wGPmd/9WbAA5ZEfu/QS/1u5ZrKsajy
# eioKMfDaTgaRtogINeh4HLDpmc085y9Euqf03GS9pAHBIAmTeM38vMDJRF1eFpwB
# BU8iTQIDAQABo4IB5jCCAeIwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFNVj
# OlyKMZDzQ3t8RhvFM2hahW1VMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsG
# A1UdDwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFNX2VsuP6KJc
# YmjRPZSQW9fOmhjEMFYGA1UdHwRPME0wS6BJoEeGRWh0dHA6Ly9jcmwubWljcm9z
# b2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIz
# LmNybDBaBggrBgEFBQcBAQROMEwwSgYIKwYBBQUHMAKGPmh0dHA6Ly93d3cubWlj
# cm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMuY3J0
# MIGgBgNVHSABAf8EgZUwgZIwgY8GCSsGAQQBgjcuAzCBgTA9BggrBgEFBQcCARYx
# aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL1BLSS9kb2NzL0NQUy9kZWZhdWx0Lmh0
# bTBABggrBgEFBQcCAjA0HjIgHQBMAGUAZwBhAGwAXwBQAG8AbABpAGMAeQBfAFMA
# dABhAHQAZQBtAGUAbgB0AC4gHTANBgkqhkiG9w0BAQsFAAOCAgEAB+aIUQ3ixuCY
# P4FxAz2do6Ehb7Prpsz1Mb7PBeKp/vpXbRkws8LFZslq3/Xn8Hi9x6ieJeP5vO1r
# VFcIK1GCRBL7uVOMzPRgEop2zEBAQZvcXBf/XPleFzWYJFZLdO9CEMivv3/Gf/I3
# fVo/HPKZeUqRUgCvOA8X9S95gWXZqbVr5MfO9sp6AG9LMEQkIjzP7QOllo9ZKby2
# /QThcJ8ySif9Va8v/rbljjO7Yl+a21dA6fHOmWaQjP9qYn/dxUoLkSbiOewZSnFj
# nXshbcOco6I8+n99lmqQeKZt0uGc+R38ONiU9MalCpaGpL2eGq4EQoO4tYCbIjgg
# tSXlZOz39L9+Y1klD3ouOVd2onGqBooPiRa6YacRy5rYDkeagMXQzafQ732D8OE7
# cQnfXXSYIghh2rBQHm+98eEA3+cxB6STOvdlR3jo+KhIq/fecn5ha293qYHLpwms
# ObvsxsvYgrRyzR30uIUBHoD7G4kqVDmyW9rIDVWZeodzOwjmmC3qjeAzLhIp9cAv
# VCch98isTtoouLGp25ayp0Kiyc8ZQU3ghvkqmqMRZjDTu3QyS99je/WZii8bxyGv
# WbWu3EQ8l1Bx16HSxVXjad5XwdHeMMD9zOZN+w2/XU/pnR4ZOC+8z1gFLu8NoFA1
# 2u8JJxzVs341Hgi62jbb01+P3nSISRKhggLXMIICQAIBATCCAQChgdikgdUwgdIx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1p
# Y3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEmMCQGA1UECxMdVGhh
# bGVzIFRTUyBFU046RkM0MS00QkQ0LUQyMjAxJTAjBgNVBAMTHE1pY3Jvc29mdCBU
# aW1lLVN0YW1wIFNlcnZpY2WiIwoBATAHBgUrDgMCGgMVAEKl5h7yE6Y7MpfmMpEb
# QzkJclFToIGDMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
# b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwDQYJ
# KoZIhvcNAQEFBQACBQDkm/v4MCIYDzIwMjEwNzE2MjAzNzEyWhgPMjAyMTA3MTcy
# MDM3MTJaMHcwPQYKKwYBBAGEWQoEATEvMC0wCgIFAOSb+/gCAQAwCgIBAAICIKEC
# Af8wBwIBAAICEu4wCgIFAOSdTXgCAQAwNgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYB
# BAGEWQoDAqAKMAgCAQACAwehIKEKMAgCAQACAwGGoDANBgkqhkiG9w0BAQUFAAOB
# gQDGyprkhBO0dExxL+xw+oF2oLNY2mm1dkJwft0cUq9UrhnDoliHaS1DTTWJzAJw
# zZJ5fi4/2hg/kyQcA5d6ceekjfRoQW/q0d8YGGBYKGl6NWnwgVaE2NVyPzuTiD8s
# +tARZaQjp30RyzCHNdEalRDrX1kfmhCpvhPK6GnqEzRpnDGCAw0wggMJAgEBMIGT
# MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMT
# HU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAABQCMZ1l7elSQxAAAA
# AAFAMA0GCWCGSAFlAwQCAQUAoIIBSjAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQ
# AQQwLwYJKoZIhvcNAQkEMSIEIKyjxdiudcQLi158xCEJetze6q9kBqQjydki/4/K
# zbrrMIH6BgsqhkiG9w0BCRACLzGB6jCB5zCB5DCBvQQgLzawterM0qRcJO/zcvJT
# 7do/ycp8RZsRSTqqtgIIl4MwgZgwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UE
# CBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9z
# b2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQ
# Q0EgMjAxMAITMwAAAUAjGdZe3pUkMQAAAAABQDAiBCCN3wDYpq4mMninVVe6dhnu
# qvQxosGLo+4bF3KjefqhKzANBgkqhkiG9w0BAQsFAASCAQBadg5wOLhmGAI5yMO9
# zyJROhLKMS7jlgiQcHn4cvTXA2JzE/gmKWYehNTQCCDG9jx1Ll3xLabJmFQGA7UG
# neruHmzFi+5o7NO12dqOGX4gz7xKZKYTCu499MnlaPtOYbidM2++xnzaK5BwsYHn
# E4uA9hyt0UgEzj04eNHDfC7yhId2ABFEL9PCtjwUXBKF6NmRZ4aSsr9VXDvLGNk5
# k6Lx1r3NtgBxgDm1ttskGZ0wDjcFHfLJZ2lhzSZ4AG+1s8t8zXodVNexnN7eA79Z
# lb0lTTozm8qXc6P4D01YTX1TH0vyA3FdlZ3z8LD1dI96XE5QSKBs3kfrgTewRy5H
# StSm
# SIG # End signature block
