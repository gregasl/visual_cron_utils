# Local add-on helpers for VisualCron_API.ps1.
# Dot-source AFTER the production API script:
#
#   . \\aslfile01\aslcap\IT\software\production\scheduler\VisualCron_API.ps1
#   . \\aslfile01\aslcap\IT\Software\Utilities\environment_setup\VCAPI_Job_Extensions.ps1
#
# The production script is not modified.

# Reads a job-scoped variable.
#
# The token is one string parsed server side as Context|Kind|Name.
# "Active" only resolves while VisualCron itself is expanding a task
# field, so an API client must supply an explicit job GUID instead.
function VCAPI-Get-Job-Variable ([string]$JobId, [string]$Variable_Name) {

    if (-not $JobId) {
        Write-Output "VCAPI-Get-Job-Variable: no JobId supplied"
        Return $null
    }

    $Variable_Value = VCAPI-Get-Variable("JOB(" + $JobId + "|Variable|" + $Variable_Name + ")")

    Return $Variable_Value
}

function VCAPI-Get-Task-Variable ([string]$TaskId, [string]$Variable_Name) {

    if (-not $TaskId) {
        Write-Output "VCAPI-Get-Task-Variable: no TaskId supplied"
        Return $null
    }

    Write-Output "VCAPI-Get-Task-Variable: Task $TaskId - Var $Variable_Name"
    $Variable_Value = VCAPI-Get-Variable("TASK(" + $TaskId + "|Variable|" + $Variable_Name + ")")

    Return $Variable_Value
}
