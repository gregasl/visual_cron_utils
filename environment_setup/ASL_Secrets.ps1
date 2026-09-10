# PowerShell reader for the shared ASL secrets store.
#
# Same file and same format the Python side uses via
# ASL.utils.secrets.my_secrets: one key=value per line, split on the
# FIRST '=' so values may contain '=' themselves.
#
# Dot-source before use:
#   . \\aslfile01\aslcap\IT\Software\Utilities\environment_setup\ASL_Secrets.ps1

$Global:ASL_SECRETS_PATH = '\\aslfile01\aslcap\IT\software\production\utilities\python_env'

# Returns the raw value for a key, or $null when the key is absent.
function Get-ASLSecret ([string]$Key, [string]$Path = $Global:ASL_SECRETS_PATH) {

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "ASL secrets file not readable: $Path"
    }

    foreach ($line in (Get-Content -LiteralPath $Path)) {
        $line = $line.Trim()
        $i = $line.IndexOf('=')
        if ($i -lt 1) { continue }
        if ($line.Substring(0, $i) -eq $Key) {
            Return $line.Substring($i + 1)
        }
    }

    Return $null
}

# Returns a PSCredential-shaped pair for a 'user:password' style value.
# The password may itself contain ':' - only the first one splits.
function Get-ASLSecretUserPass ([string]$Key, [string]$Path = $Global:ASL_SECRETS_PATH) {

    $value = Get-ASLSecret $Key $Path
    if (-not $value) {
        throw "ASL secret '$Key' not found in $Path"
    }

    $i = $value.IndexOf(':')
    if ($i -lt 1) {
        throw "ASL secret '$Key' is not in user:password form"
    }

    Return [pscustomobject]@{
        UserName = $value.Substring(0, $i)
        Password = $value.Substring($i + 1)
    }
}
