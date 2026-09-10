# Dumps VisualCron user variables and all job-scoped variables for a job.
#
# Run as a PowerShell task inside VisualCron. Set the task Arguments to:
#     -JobId "{JOB(Active|Id)}" -TaskId "{TASK(Active|Id)}"
# VisualCron expands those tokens before the script starts, so the job
# identifies itself.
#
# Or pass a literal job GUID to inspect any other job:
#     -JobId "8f3c1d2a-4b5e-4a6f-9c7d-0e1f2a3b4c5d"
# Job name also works; the script falls back to a name match.

param(
    [string]$computer = "",
    [string]$code = "",
    [string]$JobId = "",
    [string]$TaskId = ""
)

Set-ExecutionPolicy Bypass -Scope Process -Force
write-output "GetVCJobIdByVar.ps1 JobId $JobId TaskId $TaskId"

. \\aslfile01\aslcap\IT\software\production\scheduler\VisualCron_API.ps1
. \\aslfile01\aslcap\IT\Software\Utilities\environment_setup\VCAPI_Job_Extensions.ps1

$serverName = 'ASLDYNAMICS01'
VCAPI-ConnectServer $serverName

if (-not $Global:Server.Connected) {
    Write-Output "Failed to connect to VisualCron server $serverName"
    exit 1
}

write-Output "Connected to VisualCron server $serverName Global $Global Local $Local"
# GetGenericVariable resolves the token and returns the value as a string.
# Variables.Get() returns the variable definition object whose .Value is empty.
$asl_env = $Global:Server.Variables.GetGenericVariable("{USERVAR(ASL_ENV)}")

# VCAPI-Get-User-Variable is the wrapper for the same call in VisualCron_API.ps1
$asl_env_wrapped = VCAPI-Get-User-Variable "ASL_ENV"

Write-Output "ASL_ENV (direct)  - $asl_env"
Write-Output "ASL_ENV (wrapper) - $asl_env_wrapped"


# $job_env      = $Global:Server.Variables.Get("{JOB(Active|Variable|ASL_ENV)}")
# $job_env_vv   = $Global:Server.Variables.GetGenericVariable("{JOB(Active|Variable|ASL_ENV)}")

$job_env      = $Global:Server.Variables.Get("{JOB($JobId|Variable|ASL_ENV)}")
$job_env_vv   = VCAPI-Get-Job-Variable $JobId "ASL_ENV"
write-Output "JOB ASL_ENV 1  - $($job_env)"
write-Output "JOB ASL_ENV VV - $job_env_vv"



# ---------------------------------------------------------------------------
# All job-scoped variables for $JobId.
#
# GetGenericVariable only resolves a name you already know. To enumerate we
# need the Job object itself: Jobs.GetById() returns it, and its .Variables
# collection holds every user-defined job variable (Name / Value / Description).
# ---------------------------------------------------------------------------
function VCAPI-Get-Job-Variables ([string]$JobId) {

    if (-not $JobId) {
        Write-Output "VCAPI-Get-Job-Variables: no JobId supplied"
        Return $null
    }

    # VisualCronAPI.Jobs has no GetById. The lookup by GUID is
    # Get(id, bolRaiseErrors, bolGetCloned); by name it is GetJobByName().
    $job = $null
    try {
        $job = $Global:Server.Jobs.Get($JobId, $false, $false)
    } catch {
        Write-Output "VCAPI-Get-Job-Variables: Get failed - $($_.Exception.Message)"
    }

    if (-not $job) {
        # Fall back in case the id was supplied as a job name.
        try { $job = $Global:Server.Jobs.GetJobByName($JobId) } catch { }
    }

    if (-not $job) {
        Write-Output "VCAPI-Get-Job-Variables: job not found for '$JobId'"
        Return $null
    }

    # JobVariableClass exposes only Key (the name) and ValueObject, a
    # serialised byte[]. The readable value has to come back through the
    # server by resolving the {JOB(id|Variable|name)} token.
    $results = @()
    foreach ($v in $job.Variables) {
        $resolved = $null
        try {
            $resolved = VCAPI-Get-Job-Variable $job.Id $v.Key
        } catch {
            $resolved = "<resolve failed: $($_.Exception.Message)>"
        }

        $results += [pscustomobject]@{
            JobName  = $job.Name
            JobId    = $job.Id
            Name     = $v.Key
            Value    = $resolved
        }
    }

    Return $results
}

$job_vars = VCAPI-Get-Job-Variables $JobId

if ($job_vars) {
    Write-Output "--- All job variables for $JobId ---"
    $job_vars | Format-Table -AutoSize | Out-String -Width 4096 | Write-Output
} else {
    Write-Output "--- No job variables found for $JobId ---"
}
