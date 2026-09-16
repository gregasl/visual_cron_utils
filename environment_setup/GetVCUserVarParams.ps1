param(
    [string]$computer = "",
    [string]$code = "",
    [string]$JobId = "",
    [string]$TaskId = ""
)

Set-ExecutionPolicy Bypass -Scope Process -Force
write-output "GetVCUserVarParams.ps1 JobId $JobId TaskId $TaskId"

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

$job_env      = $Global:Server.Variables.GetGenericVariable("{JOB($JobId|Variable|ASL_ENV)}")
$job_env_vv   = VCAPI-Get-Job-Variable $JobId "ASL_ENV"
write-Output "JOB ASL_ENV 1  - $($job_env)"
write-Output "JOB ASL_ENV VV - $job_env_vv"

Write-Debug("To GetGenericVariable")
$task_env      = $Global:Server.Variables.GetGenericVariable("{TASK($TaskId|Variable|ASL_ENV)}")
Write-Debug("To Get-Task-Variable")
$task_env_vv   = VCAPI-Get-Task-Variable $TaskId "ASL_ENV"
write-Output "Task ASL_ENV 1  - $($task_env)"
write-Output "Task ASL_ENV VV - $task_env_vv"

