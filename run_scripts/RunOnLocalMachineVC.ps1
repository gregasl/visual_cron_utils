param(
    $computer=”ASLWKS23”, 
    $code="\\aslfile01\aslcap\IT\Software\Development\bw\test\runSleeper.bat",
	$filename=""
)

Function Log {
    param(
        [Parameter(Mandatory=$true)][String]$msg
    )
    $now = Get-Date -Format "MM/dd/yy HH:mm:ss"
    write-output "$now $msg" 
}
try {
if ([System.IO.Path]::GetExtension($code) -ne ".py") {
    if ($code[1] -eq ":") {
        $parent = $code | split-path -Parent
        set-location $parent
        write-output "Setting run location to $parent" 
    } else {
        set-location "c:\temp"
    }
    write-output "Running executable $code on $env:computername"
    $out = invoke-expression "& '$code' '$filename'" -ErrorVariable errout
} else {
    if (Test-Path "C:\Program Files\Python39\python.exe" ) {
        $execPython = "\\aslhost01\Python\python.exe"

    } elseif (Test-Path "C:\Windows\py.exe" ) {
        $execPython = "C:\Windows\py.exe"
        $execPython = "\\aslhost01\Python\python.exe"

    } else {
        $execPython = $using:python           
    }

    write-output "Running $execPython $code on $env:computername" 
    $out = invoke-expression "$execPython '$code' '$filename'" -ErrorVariable errout                
}
$exitCode = $LASTEXITCODE

    
$now = Get-Date
$res = $out
$err = $errout
$jn = $code | Split-Path -Leaf

if ($code[1] -ne ":") {
    $outputDir = $code | split-Path -Parent
    md -force "$outputDir\Output" | out-Null
    $fileDate = Get-Date -format "_yyyy_MM_dd_HH_mm"
    $outputFile = "$outputDir\Output\" + $jn + $fileDate + ".txt"

    write-output $res >  $outputFile
    write-output $err >>  $outputFile
}

if ($exitCode -eq 0 ) {
	if ($res -like "*Traceback*" -or $err -like "* ERROR *" -or $res -like "* ERROR *") {
        #write-error "Job $jn has error in output on host $computer at $now"
		Log "Job $jn has error in output on host $computer at $now"
		$exitcode = 1
	} else {
        write-output $res 
		Log "Job $jn completed OK on host $env:computername at $now"
		$exitcode = 0
		break
	}
    write-output $res $err
} else {
    if ($($exitCode)) {
        write-output $res
        #write-error $err
        Log "Job $jn returned $($exitCode) on host $env:computername at $now"
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
}
finally {
    Log "In finally"
}


