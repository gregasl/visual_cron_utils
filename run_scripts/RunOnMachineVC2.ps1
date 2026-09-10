param(
    $computer=”ASLDB03”, 
    #$code="\\aslfile01\aslcap\IT\Software\Development\utilities\runHello.bat",
    $code ="\\aslfile01\aslcap\IT\Software\Development\GLMX\runGLMX_APP.bat",
	$filename=""
)

# this is the script for starting jobs in visual cron. It was written to enable us to run scripts on various machines.
# it will run a remote command on the selected machines. It takes the following parameters
# -computer - default is ASLDB03. Set as parameter to script in VisualCron
# -code - this is what we want to run. Typically a .bat file but could be a .py or a .exe
# -filename - this is used to hand in the filename if the job is started by a file based trigger in VisualCron
#             This can be hijacked to hand in parameters to the script by handing in a string with PARAM:parm_info. The PARAM: will be stripped off
#             and the parameter will be handed into teh command


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

# set up the parameters to the job - if there are any

$exitcode = 0
If (($filename -ne "") -and (-Not (test-path $filename -PathType Leaf))) {
    if ($filename -like "PARAM:*") {
        $filename = $filename.Replace("PARAM:","")
    } else {
        $filename = ""
    }
} 

$python = "\\aslfile01\ASLCAP\IT\Python\python.exe"

$jn = $code | Split-Path -Leaf
if ($code[1] -ne ":") {
    $outputDir = $code | split-Path -Parent
} else {
    $outputDir = 'c:\temp'
}

md -force "$outputDir\Output" | out-Null
$fileDate = Get-Date -format "_yyyy_MM_dd_HH_mm"
$outputFile = "$outputDir\Output\" + $jn + $fileDate + ".txt"  

$parentHost = $env:computername

# we need to check is CREDSSP is set up to enable remoting. It should be on all machines
# it checks and enables it if needed

$ans = Invoke-Command -ComputerName $computer -Credential $cred -ScriptBlock { Get-WSManCredSSP }
if( $ans -like "*is not configured to receive*") { 
    write-output "Configuring Enable-WSManCredSSP on $computer" 
    Invoke-Command -ComputerName $computer -ScriptBlock { Enable-WSManCredSSP Server -Force } -Credential $cred
} 
  
$result = "" 
# this is the main command that is invoked on the remote box. It will start a watcher job and the actual job to be run. The job is run in the foreground so 
# if you use python -u in the script (unbuffered i/o) you can get real time updates into Visual Cron while the job is running.
# The watcher job checks that the powershell script on the launch box (ASLDYNAMICS01) is still running. This is to handle the case where somebody does a 
# stop on the job in Visual Cron. This only kills the lauch poershell and not the invoked command. The watch will check that the launch task is still running - if not, 
# it will kill whatever has been launched on the remote box

Invoke-Command -ComputerName $computer -Credential $cred -Authentication CredSSP -ScriptBlock { 
    [System.Environment]::SetEnvironmentVariable("PYTHONPATH","\\aslfile01\aslcap\IT\software\production\python")

    # this is the script used for the monitor process

    $monitorBlock = {
        param([string]$guid, [string]$parentHostMachine, [int]$parentProcessId)

        $cnt = 1
        while ($true) {
            #write-output "Checker is sleeping - $cnt - looking for $parentProcessId on $parentHostMachine"
            #Get-Process -Id $parentProcessId -ComputerName $parentHostMachine

            Start-Sleep -Seconds 4
            # Check if parent process still exists
            if ( -not (Get-Process -Id $parentProcessId -ComputerName $parentHostMachine -ErrorAction SilentlyContinue)) {

            # when we launch the remote task it adds a guid on the commandline and this is what we search for in the process tree when
            # we need to kill the remote process

                Write-Output "Parent process terminated, killing main process - looking for $guid"
                $like = '*' + $guid + '*'

                $processes = Get-CimInstance -ClassName Win32_Process | where {$_.CommandLine -like $like} 

                if ($processes) {
                    foreach ($proc in $processes) {
                        write-output "Killing $proc $($proc.CommandLine) $($proc.ProcessId)"
                        # we need to kill the process with taskkill as this will kill the script and all it children
                        invoke-expression "taskkill /pid $($proc.ProcessId) /T /F"
                    }
                }
                break
            }
            $cnt += 1
        }
    }

    $address = Get-NetIPAddress -AddressFamily IPv4 | Where PrefixOrigin -ne WellKnown |Select-Object -First 1
    $parts = $address.ipaddress.Split(".")

    # if the script is a .py then we have to find a good interpreter to run it

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
    $guid = New-Guid
    $parentHost = $using:parentHost
    $parentPid = $using:PID

    write-output "Starting monitor job using $guid and $parentPid on $parentHost"
    $monitorJob = start-job -ScriptBlock $monitorBlock -ArgumentList $guid.toString(), $parentHost, $parentPid 

    if ([System.IO.Path]::GetExtension($using:code) -ne ".py") {
        if ($using:code[1] -eq ":") {
            $parent = $using:code | split-path -Parent
            set-location $parent
            write-output "Setting run location to $parent" 
        } else {
            set-location "c:\temp"
        }
        write-output "Running executable $using:code on $env:computername with filename $using:filename and guid $guid"
        # this is where we lauch the main process - usually a .bat or .exe
        invoke-expression "& '$using:code' '$using:filename' '$guid'" -ErrorVariable errout | Tee-Object $using:outputFile
        
    } else {
        write-output "Running $execPython $using:code on $env:computername" 
        # here we are lauinching a python script with teh correct launcher
        invoke-expression "$execPython '$using:code' '$using:filename'" -ErrorVariable errout | Tee-Object $using:outputFile
    }

    $exitCode = $LASTEXITCODE
    stop-job $monitorJob
    $out = Receive-Job -Job $monitorJob

    return New-Object -TypeName PSCustomObject -Property @{Output=$out; ExitCode=$exitCode; Errortext=$errout}
} | Tee-Object -Variable result

$now = Get-Date
$err = $result.ErrorText | Out-String
$exitCode = $Result.ExitCode | Out-String
$exitcode = $exitCode -as [int]


if ($code[1] -ne ":") {
    write-output $err >>  $outputFile
}

# we now check to see if things ran correctly - mostly dependent on error code so if Python fails but is caught and it does a clean exit then it wil be zero
# to try and counter that, we look for Traceback and ERROR in the erro file and set the return code to non zero if found (which tells Visual Cron
# to mark it as failed).

if ($exitCode -eq 0 ) {
	if ($result.ErrorText -like "*Traceback*" -or $result.ErrorText -like "* ERROR *" -or $result.Output -like "* ERROR *") {
        #write-error "Job $jn has error in output on host $computer at $now"
		Log "Job $jn has error in output on host $computer at $now"
		$exitcode = 1
	} else {
		Log "Job $jn completed OK on host $computer at $now"
		$exitcode = 0
		break
	}
    write-output $res $err
} else {
    if ($eExitCode) {
        write-output $res
        #write-error $err
        Log "Job $jn returned $exitCode on host $computer at $now"
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
