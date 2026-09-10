# Copyright (c) 2014 Atif Aziz. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

function Get-VCAPIPath
{
    $programFilesPath = if (${Env:PROCESSOR_ARCHITECTURE} -eq 'x86') { ${Env:ProgramFiles} } else { ${Env:ProgramFiles(x86)} }
    Join-Path $programFilesPath VisualCron\VisualCronAPI.dll
}

function Get-VCServer
{
    [CmdletBinding()]
    param ([string]$ComputerName, 
           [int]$Port,
           [System.Management.Automation.PSCredential]$Credential)

    $apiPath = Get-VCAPIPath
    if (!(Test-Path $apiPath)) { Throw "VisualCron does not appear to be installed. API library not found at `"$apiPath`"." }
    [Reflection.Assembly]::LoadFrom($apiPath) | Out-Null
    $conn = New-Object VisualCronAPI.Connection
    $conn.Address = if ([String]::IsNullOrEmpty($ComputerName)) { ${Env:COMPUTERNAME} } else { $ComputerName }
    if (!($credential -eq $null)) 
    {
        $conn.UseADLogon = $true
        $netcred = $credential.GetNetworkCredential()
        $conn.UserName = $netcred.UserName
        $conn.Password = $netcred.Password
    }
    $client = New-Object VisualCronAPI.Client
    $client.Connect($conn)
}

function Get-VCJob
{
    [CmdletBinding()]
    param ([string]$ComputerName, 
           [int]$Port,
           [System.Management.Automation.PSCredential]$Credential,
           [switch]$Active)

    $ps = New-Object Collections.Hashtable($psBoundParameters)
    $ps.Remove('Active') | Out-Null
    $server = Get-VCServer @ps
    $server.Jobs.GetAll() `
    | ? { !($Active) -or $_.Stats.Active } `
    | Add-Member ScriptMethod Start { $server.Jobs.Run($this, $false, $false, $false, $null) }.GetNewClosure() -PassThru
 }
 
function Get-VCTask
{
    [CmdletBinding()]
    param ([string]$ComputerName, 
           [int]$Port,
           [System.Management.Automation.PSCredential]$Credential,
           [switch]$Active)

    Get-VCJob @psBoundParameters `
    | % { 
        $job = $_
        $_.Tasks `
        | ? { !($Active) -or $_.Stats.Active } `
        | sort Order `
        | % { Add-Member NoteProperty   Job     -InputObject $_ $job                -PassThru } `
        | % { Add-Member ScriptProperty JobName -InputObject $_ { $this.Job.Name  } -PassThru } `
        | % { Add-Member ScriptProperty Group   -InputObject $_ { $this.Job.Group } -PassThru }
    }
}

function Get-VCTaskExecute
{
    [CmdletBinding()]
    param ([string]$ComputerName, 
           [int]$Port,
           [System.Management.Automation.PSCredential]$Credential,
           [switch]$Active)

    Get-VCTask @psBoundParameters `
    | ? { !($_.Execute -eq $null) } 
}

function Get-VCTaskCommandLine
{
    [CmdletBinding()]
    param ([string]$ComputerName, 
           [int]$Port,
           [System.Management.Automation.PSCredential]$Credential,
           [switch]$Active)

    Get-VCTaskExecute @psBoundParameters `
    | % { Add-Member ScriptProperty CmdLine   -InputObject $_ { $this.Execute.CmdLine   } -PassThru } `
    | % { Add-Member ScriptProperty Arguments -InputObject $_ { $this.Execute.Arguments } -PassThru }
}