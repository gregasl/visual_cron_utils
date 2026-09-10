param(
    $file=”C:\temp\aslwks23.txt”, 
    $code="\\aslfile01\ASLCAP\IT\Temp\MacroTest.ps1",
	$parm="",
    $sleep=60,
    $times=1
)

Function Log {
    param(
        [Parameter(Mandatory=$true)][String]$msg
    )
    
    $fn = "RunOnAvailableMachineVC.ps1"
    $now = Get-Date -Format "MM/dd/yy HH:mm:ss"
    #write-output "$now $msg" | Tee-Object -FilePath "c:\temp\$($fn).log" -Append

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

$hosts = Get-Content $file
$exitcode = 0

$python = "\\aslfile01\ASLCAP\IT\Python\python.exe"
$pythonx = "\\aslfile02\dfstest\Python\python.exe"

$attempt = 1


While ($attempt -le $times ) {
    Log "Attempt $attempt of $times"
    if ($attempt -gt 1 ) {
        Log "Sleeping for $sleep seconds"
        start-sleep -s $sleep
    }

    foreach ($computer in $hosts ) {
        $ans = Invoke-Command -ComputerName $computer -Credential $cred -ScriptBlock { Get-WSManCredSSP }
        if( $ans -like "*is not configured to receive*") { 
            write-output "Configuring Enable-WSManCredSSP on $computer" 
            Invoke-Command -ComputerName $computer -ScriptBlock { Enable-WSManCredSSP Server -Force } -Credential $cred
        } 
    
        $job = Invoke-Command -ComputerName $computer -Credential $cred -asJob -Authentication CredSSP -ScriptBlock { 
            if (Test-Path "C:\Program Files\Python39\python.exe" ) {
                $execPython = "\\aslhost01\Python\python.exe"

            } elseif (Test-Path "C:\Windows\py.exe" ) {
                $execPython = "C:\Windows\py.exe"
                $execPython = "\\aslhost01\Python\python.exe"

            } else {
                $execPython = $using:python           
            }

            $out = ""
            if ([System.IO.Path]::GetExtension($using:code) -ne ".py") {
                write-output "Running executable $using:code on $env:computername"
                $out = invoke-expression "& '$using:code' $using:parm" -ErrorVariable errout
            } else {
                write-output "Running $execPython $using:code on $env:computername"
                $out = invoke-expression "$execPython '$using:code' $using:parm" -ErrorVariable errout
                
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

        $outputDir = $code | split-Path -Parent
        md -force "$outputDir\Output" | out-Null
        $fileDate = Get-Date -format "_yyyy_MM_dd_HH_mm"
        $outputFile = "$outputDir\Output\" + $jn + $fileDate + ".txt"

        write-output $res >  $outputFile
        write-output $err >>  $outputFile

        if ($result.ExitCode -eq 0 ) {
		    if ($result.ErrorText -like "*Traceback*" -or $result.ErrorText -like "*ERROR*" -or $result.Output -like "*ERROR*") {
			    Log "Job $jn has error in output on host $computer at $now"
			    $exitcode = 1
		    } else {
			    Log "Job $jn completed OK on host $computer at $now"
                write-output $res $err
			    $exitcode = 0
			    break
		    }
            write-output $res $err
        } else {
            if ($($result.ExitCode)) {
                Log "Job $jn returned $($result.ExitCode) on host $computer at $now"
                write-output $res $err
            } else {
                Log "Job $jn could not run on host $computer at $now"
            }
            $exitcode = 1
        }
    }

    $attempt += 1
    if ($exitcode -eq 0) {
        break
    }
}
$ac = $PSBoundParameters.Count

Log "Setting return code for $jn to $exitcode"
$host.SetShouldExit($exitcode)
exit $exitcode

