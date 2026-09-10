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

# NOTE: job-scoped variables use {JOB(JobId|Variable|VarName)}.
# VisualCron's own UI shows this as {JOB(Active|Variable|ASL_ENV)}.
# "Active" only resolves inside the running job; the API server object
# has no current job, so the job GUID is used here instead. The job
# name did not resolve - only the GUID is reliable via the API.
$job_guid_added = "5f542375-74dd-4829-8ed9-fc7d023e8c6a"
$job_guid = $Global:Client.Variables.GetGenericVariable("{JOB(JobId)}")
write-Output "JOB ID (GUID) - $job_guid"

# $job_env      = $Global:Server.Variables.Get("{JOB(Active|Variable|ASL_ENV)}")
# $job_env_vv   = $Global:Server.Variables.GetGenericVariable("{JOB(Active|Variable|ASL_ENV)}")

$job_env      = $Global:Client.Variables.Get("{JOB(5f542375-74dd-4829-8ed9-fc7d023e8c6a|Variable|ASL_ENV)}")
$job_env_vv   = VCAPI-Get-Job-Variable $job_guid_added "ASL_ENV"

Write-Output "JOB ASL_ENV 1  - $($job_env.Value)"
Write-Output "JOB ASL_ENV VV - $job_env_vv"

$task_env      = $Global:Server.Variables.Get("{TASK(Active|Name)}")
$task_env_vv   = $Global:Server.Variables.GetGenericVariable("{TASK(Active|Name)}")

Write-Output "Task Name   - $($task_env.Value)"
Write-Output "Task Name VV - $task_env_vv"
