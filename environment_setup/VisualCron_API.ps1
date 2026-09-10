# Load the VisualCron API Dlls
$VC		= [Reflection.Assembly]::LoadFrom("C:\Program Files (x86)\VisualCron\VisualCron.dll");
$VCAPI	= [Reflection.Assembly]::LoadFrom("C:\Program Files (x86)\VisualCron\VisualCronAPI.dll");

# Define Client & Server Objects
# Globals to allow sharing of connections
$Global:Client 	= New-Object -TypeName VisualCronAPI.Client
$Global:Server 	= New-Object -TypeName VisualCronAPI.Server

# VisualCron API credentials come from the shared ASL secrets store,
# key VisualCronAdmin, stored as user:password. Never inline them here -
# this file is in source control.
. $PSScriptRoot\ASL_Secrets.ps1
$_vc_cred = Get-ASLSecretUserPass 'VisualCronAdmin'
$Conn_UserName			= 	$_vc_cred.UserName
$Conn_PassWord			= 	$_vc_cred.Password
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
