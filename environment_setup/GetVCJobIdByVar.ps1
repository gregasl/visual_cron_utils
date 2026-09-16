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

Set-ExecutionPolicy Bypass -Scope Process -Force

# Load the VisualCron API Dlls
$VC		= [Reflection.Assembly]::LoadFrom("C:\Program Files (x86)\VisualCron\VisualCron.dll");
$VCAPI	= [Reflection.Assembly]::LoadFrom("C:\Program Files (x86)\VisualCron\VisualCronAPI.dll");

# Define Client & Server Objects
# Globals to allow sharing of connections
$Global:Client 	= New-Object -TypeName VisualCronAPI.Client
$Global:Server 	= New-Object -TypeName VisualCronAPI.Server

# Read Only VisualCron User for API Access
# VisualCron UserName and Password from your Site
$Conn_Address			=	'ASLDYNAMICS01'

# Standard Settings
$Conn_Port				=	16444
$Conn_ConnectionType	=	'Remote'

# Function to Connect to a VisualCron Server using the API
function VCAPI-ConnectServer ([string]$Conn_Address) {

# Define Connection Object
$Conn = New-Object -TypeName VisualCronAPI.Connection

# Set Connection Values
$Conn.Address  			= 	$Conn_Address
$Conn.UserName  		= 	$Conn_UserName
$Conn.PassWord			= 	$Conn_PassWord
$Conn.Port				= 	$Conn_Port
$Conn.ConnectionType 	= 	$Conn_ConnectionType

# Try to Connect to the VisualCron Server
try
	{
    	$Global:Server = $Client.Connect($conn, $true);

	}
catch 
	{
	write-output "failed"
    MessageBox.Show(ex.Message);
	
	}

}

# Function to retrieve a User Variable Value using the API
# wrapper for generic get variable API call below
function VCAPI-Get-User-Variable ([string]$Variable_Name) {

$Variable_Value = VCAPI-Get-Variable("USERVAR(" + $Variable_Name + ")")

Return $Variable_Value

}

# wrapper for the get-variable API call
# Returns Varian;e Value
function VCAPI-Get-Variable ([string]$Variable_Name) {

$Variable_Name 	= "{" + $Variable_Name + "}"

$Variable_Value = $Global:Server.Variables.GetGenericVariable($Variable_Name)

Return $Variable_Value
}

# . \\aslfile01\aslcap\IT\software\Utilities\VisualCron_API.ps1

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

$job_guid = $Global:Client.Variables.GetGenericVariable("{JOB(JobId)}")
write-Output "JOB ID (GUID) - $job_guid"

# $job_env      = $Global:Server.Variables.Get("{JOB(Active|Variable|ASL_ENV)}")
# $job_env_vv   = $Global:Server.Variables.GetGenericVariable("{JOB(Active|Variable|ASL_ENV)}")

$job_env      = $Global:Client.Variables.Get("{JOB(5f542375-74dd-4829-8ed9-fc7d023e8c6a|Variable|JobId)}")
$job_env_vv   = VCAPI-Get-Job-Variable $job_guid_added "ASL_ENV"

Write-Output "JOB ASL_ENV 1  - $($job_env.Value)"
Write-Output "JOB ASL_ENV VV - $job_env_vv"

$task_env      = $Global:Server.Variables.Get("{TASK(Active|Name)}")
$task_env_vv   = $Global:Server.Variables.GetGenericVariable("{TASK(Active|Name)}")

Write-Output "Task Name   - $($task_env.Value)"
Write-Output "Task Name VV - $task_env_vv"
