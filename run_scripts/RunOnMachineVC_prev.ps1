param(
    $computer=”ASLDB03”, 
    $code="\\aslfile01\aslcap\IT\Software\Production\repo\sub.py",
	$filename=""
)

Function Log {
    param(
        [Parameter(Mandatory=$true)][String]$msg
    )
	$fn = "RunOnMachineVC.ps1"
    $now = Get-Date -Format "MM/dd/yy HH:mm:ss"
    write-output "$now $msg"
    try { 
        Add-Content -Path "c:\temp\$($fn).log" -Value "$now $msg"
    } catch {
        write-output "$now Unable to write to temp log file"
    }
}

$username = "aslcap\asl.pdq"
$pw = Get-Content -Path '\\aslfile01\ASLCAP\IT\Software\PDQ\info.txt' 

$Password  = ConvertTo-SecureString $pw -AsPlainText -Force
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $password

$exitcode = 0
If (($filename -ne "") -and (-Not (test-path $filename -PathType Leaf))) {
    if ($filename -like "PARAM:*") {
        $filename = $filename.Replace("PARAM:","")
    } else {
        $filename = ""
    }
}

$python = "\\aslfile01\ASLCAP\IT\Python\python.exe"

$ans = Invoke-Command -ComputerName $computer -Credential $cred -ScriptBlock { Get-WSManCredSSP }
if( $ans -like "*is not configured to receive*") { 
    write-output "Configuring Enable-WSManCredSSP on $computer" 
    Invoke-Command -ComputerName $computer -ScriptBlock { Enable-WSManCredSSP Server -Force } -Credential $cred
} 
   
$job = Invoke-Command -ComputerName $computer -Credential $cred -asJob -Authentication CredSSP -ScriptBlock { 
    [System.Environment]::SetEnvironmentVariable("PYTHONPATH","\\aslfile01\aslcap\IT\software\production\python")

    $address = Get-NetIPAddress -AddressFamily IPv4 | Where PrefixOrigin -ne WellKnown |Select-Object -First 1
    $parts = $address.ipaddress.Split(".")


    if (Test-Path "C:\Program Files\Python39\python.exe"  ) {
        if ($parts[1] -eq 108) {
            $execPython = "\\aslhost01\Python\python.exe"
        } else {
            $execPython = "\\aslhost01\Python\python.exe"
        }


    } elseif (Test-Path "C:\Windows\py.exe" ) {
        if ($parts[1] -ne 1080) {
            $execPython = "\\aslhost01\Python\python.exe"
        } else {
            $execPython = "C:\Windows\py.exe"
        }

    } else {
        $execPython = $using:python           
    }

    $out = ""
    if ([System.IO.Path]::GetExtension($using:code) -ne ".py") {
        if ($using:code[1] -eq ":") {
            $parent = $using:code | split-path -Parent
            set-location $parent
            write-output "Setting run location to $parent" 
        } else {
            set-location "c:\temp"
        }
        write-output "Running executable $using:code on $env:computername with filename $using:filename"
        $out = invoke-expression "& '$using:code' '$using:filename'" -ErrorVariable errout
    } else {
        write-output "Running $execPython $using:code on $env:computername" 
        $out = invoke-expression "$execPython '$using:code' '$using:filename'" -ErrorVariable errout 
                
    }

    $exitCode = $LASTEXITCODE
    New-Object -TypeName PSCustomObject -Property @{Output=$out; ExitCode=$exitCode; Errortext = $errout}
} 

$j = Wait-job $job
$result = Receive-Job -Job $job 
    
$now = Get-Date
$res = $result.Output | Out-String
$err = $result.ErrorText | Out-String
$jn = $code | Split-Path -Leaf

if ($code[1] -ne ":") {
    $outputDir = $code | split-Path -Parent
    md -force "$outputDir\Output" | out-Null
    $fileDate = Get-Date -format "_yyyy_MM_dd_HH_mm"
    $outputFile = "$outputDir\Output\" + $jn + $fileDate + ".txt"

    write-output $res >  $outputFile
    write-output $err >>  $outputFile
}

if ($result.ExitCode -eq 0 ) {
	if ($result.ErrorText -like "*Traceback*" -or $result.ErrorText -like "* ERROR *" -or $result.Output -like "* ERROR *") {
        #write-error "Job $jn has error in output on host $computer at $now"
		Log "Job $jn has error in output on host $computer at $now"
		$exitcode = 1
	} else {
        write-output $res 
		Log "Job $jn completed OK on host $computer at $now"
		$exitcode = 0
		break
	}
    write-output $res $err
} else {
    if ($($result.ExitCode)) {
        write-output $res
        #write-error $err
        Log "Job $jn returned $($result.ExitCode) on host $computer at $now"
    } else {
        #write-error "Job $jn could not run on host $computer at $now"
        Log "Job $jn could not run on host $computer at $now"
        
    }
    $exitcode = 1
}

Log "Setting return code for $jn to $exitcode"
$host.SetShouldExit($exitcode)
if ($exitcode -ne 0) {
	throw "Job $jn failed with exitcode $exitcode"
}
exit $exitcode

