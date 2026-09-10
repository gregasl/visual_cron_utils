# Finds the VisualCron job id for the currently running job.
#
# Method 1 (reliable): VisualCron expands tokens in the task Arguments
# field before the script starts. Add this to the job's PowerShell task
# arguments:  -JobId "{JOB(Active|Id)}" -TaskId "{TASK(Active|Id)}"
# The script then just reads them as parameters.
#
# Method 2 (fallback, no job change): ask the server which jobs are
# running, then match this process id chain against any process id the
# job or its tasks record. Falls back to "only one job running" guess.

param(
    [string]$JobId  = "",
    [string]$TaskId = ""
)

. \\aslfile01\aslcap\IT\software\production\scheduler\VisualCron_API.ps1

$serverName = 'ASLDYNAMICS01'
VCAPI-ConnectServer $serverName

if (-not $Global:Server.Connected) {
    Write-Output "Failed to connect to VisualCron server $serverName"
    exit 1
}

Write-Output "--- Method 1: tokens passed in as arguments ---"
if ($JobId)  { Write-Output "JobId  (from token) - $JobId" }
else         { Write-Output "JobId  (from token) - not supplied" }
if ($TaskId) { Write-Output "TaskId (from token) - $TaskId" }
else         { Write-Output "TaskId (from token) - not supplied" }

Write-Output ""
Write-Output "--- Method 2: jobs the server reports as running ---"

# job_guid_added = "5f542375-74dd-4829-8ed9-fc7d023e8c6a"
$job_guid = $Global:Client.Variables.GetGenericVariable("{JOB(JobId)}")
write-Output "JOB ID (GUID) - $job_guid"

$running = @()
foreach ($job in $Global:Server.Jobs) {
    $isRunning = $false
    foreach ($prop in 'IsRunning','Running','Active') {
        if ($job.PSObject.Properties.Name -contains $prop -and $job.$prop) {
            $isRunning = $true
        }
    }
    if ($isRunning) { $running += $job }
}

if ($running.Count -eq 0) {
    Write-Output "No running jobs reported. Property names may differ - dumping"
    Write-Output "the first job's properties so the check can be corrected:"
    $first = @($Global:Server.Jobs)[0]
    if ($first) { $first | Get-Member -MemberType Property | Format-Table Name, Definition }
}
else {
    foreach ($job in $running) {
        Write-Output "Running job - Id: $($job.Id)  Name: $($job.Name)"
    }
}

# PID correlation. VisualCron launched this PowerShell, so the job that
# owns us should record a process id somewhere in its own or its tasks'
# properties. Build the ancestor chain first - the recorded id may be
# our parent or grandparent rather than us.
$pidChain = @()
$walkId   = $PID
for ($hop = 0; $hop -lt 5 -and $walkId; $hop++) {
    $pidChain += $walkId
    $walkProc = Get-CimInstance Win32_Process -Filter "ProcessId = $walkId" -ErrorAction SilentlyContinue
    if (-not $walkProc) { break }
    $walkId = $walkProc.ParentProcessId
}
Write-Output "PID chain (self to ancestors) - $($pidChain -join ', ')"

# Any property whose name looks like a process id counts as a candidate.
function Get-PidCandidates ($obj) {
    $hits = @()
    if (-not $obj) { return $hits }
    foreach ($prop in $obj.PSObject.Properties) {
        if ($prop.Name -match 'ProcessId|ProcessID|^PID$|Process_Id') {
            $val = $null
            try { $val = $prop.Value } catch { }
            if ($val) { $hits += [pscustomobject]@{ Name = $prop.Name; Value = $val } }
        }
    }
    return $hits
}

$matched = $null
foreach ($job in $running) {
    $sources = @([pscustomobject]@{ Where = "job"; Obj = $job })
    foreach ($t in $job.Tasks) {
        $sources += [pscustomobject]@{ Where = "task $($t.Name)"; Obj = $t }
    }

    foreach ($src in $sources) {
        foreach ($cand in (Get-PidCandidates $src.Obj)) {
            Write-Output "  candidate - $($job.Name) [$($src.Where)] $($cand.Name) = $($cand.Value)"
            if ($pidChain -contains [int]$cand.Value) {
                $matched = $job
                Write-Output "  MATCH on $($cand.Name) = $($cand.Value)"
            }
        }
    }
}

if ($matched) {
    Write-Output "Job id by PID correlation - $($matched.Id)  Name: $($matched.Name)"
}
elseif ($running.Count -eq 1) {
    Write-Output "No PID match. Only one job running, so assuming - $($running[0].Id)"
}
else {
    Write-Output "No PID match and $($running.Count) jobs running - cannot tell which is us"
}

Write-Output ""
Write-Output "--- Method 3: this process, for correlating with VisualCron ---"

$me = Get-Process -Id $PID
Write-Output "PID          - $PID"
Write-Output "ProcessName  - $($me.ProcessName)"
Write-Output "StartTime    - $($me.StartTime)"
Write-Output "Host         - $env:COMPUTERNAME"
Write-Output "RunAsUser    - $env:USERDOMAIN\$env:USERNAME"
Write-Output "WorkingDir   - $((Get-Location).Path)"
Write-Output "ScriptPath   - $($MyInvocation.MyCommand.Path)"

# Command line and parent are not on the .NET Process object - use CIM.
$cim = Get-CimInstance Win32_Process -Filter "ProcessId = $PID"
if ($cim) {
    Write-Output "CommandLine  - $($cim.CommandLine)"
    Write-Output "ParentPID    - $($cim.ParentProcessId)"

    $parent = Get-CimInstance Win32_Pross -Filter "ProcessId = $($cim.ParentProcessId)"
    if ($parent) {
        Write-Output "ParentName   - $($parent.Name)"
        Write-Output "ParentCmd    - $($parent.CommandLine)"
    }
    else {
        Write-Output "ParentName   - parent has already exited"
    }
}

Write-Output ""
Write-Output "--- Method 4: full job object for whichever id we resolved ---"

$lookupId = $JobId
if (-not $lookupId -and $matched) { $lookupId = $matched.Id }
if (-not $lookupId -and $running.Count -eq 1) { $lookupId = $running[0].Id }

if ($lookupId) {
    $job = $null
    foreach ($j in $Global:Server.Jobs) {
        if ("$($j.Id)" -eq "$lookupId") { $job = $j }
    }

    if ($job) {
        Write-Output "Id           - $($job.Id)"
        Write-Output "Name         - $($job.Name)"
        Write-Output "GroupName    - $($job.GroupName)"
        Write-Output "Description  - $($job.Description)"
        Write-Output ""
        Write-Output "All non-empty properties:"
        foreach ($p in ($job | Get-Member -MemberType Property | Sort-Object Name)) {
            $v = $null
            try { $v = $job.$($p.Name) } catch { $v = "<error reading>" }
            if ($null -ne $v -and "$v" -ne "") {
                Write-Output ("  {0,-28} {1}" -f $p.Name, $v)
            }
        }
        Write-Output ""
        Write-Output "Tasks in this job:"
        foreach ($t in $job.Tasks) {
            Write-Output "  TaskId: $($t.Id)  Name: $($t.Name)  Type: $($t.TaskType)"
        }
    }
    else {
        Write-Output "No job on the server matched id $lookupId"
    }
}
else {
    Write-Output "No job id resolved - pass -JobId or run with exactly one job active"
}

Write-Output ""
Write-Output "--- Method 5: API surface, looking for a job-context overload ---"

$vars = $Global:Server.Variables
Write-Output "Variables object type - $($vars.GetType().FullName)"
Write-Output ""

Write-Output "Methods on Server.Variables:"
foreach ($m in ($vars | Get-Member -MemberType Method | Sort-Object Name)) {
    Write-Output "  $($m.Name)"
    foreach ($sig in $vars.$($m.Name).OverloadDefinitions) {
        Write-Output "      $sig"
    }
}

Write-Output ""
Write-Output "Methods on Server that mention Variable, Token, Expand or Job:"
foreach ($m in ($Global:Server | Get-Member -MemberType Method | Sort-Object Name)) {
    if ($m.Name -match 'Variable|Token|Expand|Job|Resolve') {
        Write-Output "  $($m.Name)"
        foreach ($sig in $Global:Server.$($m.Name).OverloadDefinitions) {
            Write-Output "      $sig"
        }
    }
}
