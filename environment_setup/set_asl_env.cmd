@echo off
REM set_asl_env.cmd - pick the ASL environment, point PYTHONPATH at it, activate the venv.
REM CALL it, do not run it. No setlocal on purpose: the caller keeps the variables.
REM   call "\\aslfile01\aslcap\IT\software\Utilities\set_asl_env.cmd"
REM   if errorlevel 1 exit /b %ERRORLEVEL%
REM Switches: /quiet /noactivate /help. ASL_QUIET=1 is the same as /quiet.
REM Sets: ASL_ENV, ASL_LIB, PYTHONPATH, ASL_VENV, ASL_ENV_SOURCE, ASL_LIB_SOURCE
REM ASL_LIB is PROD unless preset, or ASL_LIB_OVERRIDE names PROD, UAT or DEV.
REM ASL_ENV only labels the run - it no longer selects the library.
REM Exit: 0 ok, 2 ASL_ENV unusable, 3 could not detect. Both print why.
REM Detected in this order: ASL_ENV, then working dir or this folder, then inherited PYTHONPATH.

set "ASL_LIB_PROD=\\aslfile01\aslcap\IT\software\Production\Python"
set "ASL_LIB_UAT=\\aslfile01\aslcap\IT\software\UAT\Python"
set "ASL_LIB_DEV=\\aslfile01\aslcap\IT\software\Development\Python"

REM Caller may preset ASL_VENV to override.
if not defined ASL_VENV set "ASL_VENV=C:\Applications\VirtualEnvironments\Operations"

REM ASL_QUIET=1 does the same as /quiet, for callers that cannot risk an unknown switch.
set "_ASL_QUIET=%ASL_QUIET%"
set "_ASL_NOACTIVATE="
:args
if "%~1"=="/?"             goto :usage
if /I "%~1"=="/help"       goto :usage
if /I "%~1"=="/quiet"      set "_ASL_QUIET=1"      & shift & goto :args
if /I "%~1"=="/noactivate" set "_ASL_NOACTIVATE=1" & shift & goto :args
if not "%~1"=="" (
    echo set_asl_env.cmd: unknown switch "%~1"
    goto :fail_args
)

REM %~dp0 is this file's folder, not the caller's.
set "_ASL_HERE=%~dp0"
if "%_ASL_HERE:~-1%"=="\" set "_ASL_HERE=%_ASL_HERE:~0,-1%"

if defined ASL_ENV (
    REM No parentheses in this value - the banner echoes it from inside an if-block.
    set "ASL_ENV_SOURCE=ASL_ENV was already set by VisualCron or the caller"
    goto :normalise
)

REM Separator must not be a pipe - :_probe pipes this string into findstr.
set "ASL_ENV_SOURCE=detected from the working directory"
set "_ASL_PROBE=%CD% ; %_ASL_HERE%"
call :_probe
if defined ASL_ENV goto :normalise

set "ASL_ENV_SOURCE=detected from the inherited PYTHONPATH"
set "_ASL_PROBE=%PYTHONPATH%"
call :_probe
if defined ASL_ENV goto :normalise

echo ERROR: set_asl_env.cmd cannot tell which ASL environment to use.
echo        working directory : %CD%
echo        set_asl_env.cmd   : %_ASL_HERE%
echo        PYTHONPATH        : %PYTHONPATH%
echo        Set ASL_ENV to PROD, UAT or DEV on the job and re-run.
goto :fail_detect

:normalise
REM A VisualCron job variable easily carries a space, and " PROD " would not match.
:_trim_lead
if not defined ASL_ENV goto :_trim_done
if "%ASL_ENV:~0,1%"==" " set "ASL_ENV=%ASL_ENV:~1%" & goto :_trim_lead
:_trim_trail
if "%ASL_ENV:~-1%"==" " set "ASL_ENV=%ASL_ENV:~0,-1%" & goto :_trim_trail
:_trim_done

if /I "%ASL_ENV%"=="PROD"        set "ASL_ENV=PROD"
if /I "%ASL_ENV%"=="PRODUCTION"  set "ASL_ENV=PROD"
if /I "%ASL_ENV%"=="UAT"         set "ASL_ENV=UAT"
if /I "%ASL_ENV%"=="DEV"         set "ASL_ENV=DEV"
if /I "%ASL_ENV%"=="DEVELOPMENT" set "ASL_ENV=DEV"

REM ASL_LIB is PROD unless overridden. ASL_ENV labels the run, it no longer picks
REM the library. A preset ASL_LIB wins outright; else ASL_LIB_OVERRIDE names the tier.
if defined ASL_LIB (
    set "ASL_LIB_SOURCE=ASL_LIB was preset by the caller"
    goto :have_lib
)

set "_ASL_TIER=PROD"
set "ASL_LIB_SOURCE=default"
if defined ASL_LIB_OVERRIDE (
    set "_ASL_TIER=%ASL_LIB_OVERRIDE:"=%"
    set "ASL_LIB_SOURCE=ASL_LIB_OVERRIDE"
)

:_tier_lead
if "%_ASL_TIER:~0,1%"==" " set "_ASL_TIER=%_ASL_TIER:~1%" & goto :_tier_lead
:_tier_trail
if "%_ASL_TIER:~-1%"==" " set "_ASL_TIER=%_ASL_TIER:~0,-1%" & goto :_tier_trail

if /I "%_ASL_TIER%"=="PROD"        set "ASL_LIB=%ASL_LIB_PROD%"
if /I "%_ASL_TIER%"=="PRODUCTION"  set "ASL_LIB=%ASL_LIB_PROD%"
if /I "%_ASL_TIER%"=="UAT"         set "ASL_LIB=%ASL_LIB_UAT%"
if /I "%_ASL_TIER%"=="DEV"         set "ASL_LIB=%ASL_LIB_DEV%"
if /I "%_ASL_TIER%"=="DEVELOPMENT" set "ASL_LIB=%ASL_LIB_DEV%"

if not defined ASL_LIB (
    echo ERROR: set_asl_env.cmd - ASL_LIB_OVERRIDE=%ASL_LIB_OVERRIDE% is not one of PROD, UAT, DEV.
    goto :fail_args
)

:have_lib

REM Package root only. ASL\utils holds a secrets.py that would shadow the stdlib
REM secrets module, which numpy needs. One environment only, never a fallback.
set "PYTHONPATH=%ASL_LIB%"

if not defined _ASL_QUIET (
    echo ===========================================================================
    echo ASL_ENV     : %ASL_ENV%
    echo how         : %ASL_ENV_SOURCE%
    echo library     : %ASL_LIB%
    echo lib from    : %ASL_LIB_SOURCE%
    echo PYTHONPATH  : %PYTHONPATH%
    echo venv        : %ASL_VENV%
    echo host / user : %COMPUTERNAME% / %USERNAME%
    echo ===========================================================================
)

if not exist "%ASL_LIB%\ASL\__init__.py" (
    echo WARNING: %ASL_LIB%\ASL\__init__.py not found - is the share reachable?
)

REM PROD libs are the norm, so only the mismatch is worth saying out loud.
if "%ASL_LIB%"=="%ASL_LIB_PROD%" if not "%ASL_ENV%"=="PROD" (
    echo *** ASL_ENV=%ASL_ENV% but running against PRODUCTION libraries. ***
)

if defined _ASL_NOACTIVATE goto :done

if not exist "%ASL_VENV%\Scripts\activate.bat" (
    echo ERROR: set_asl_env.cmd - no venv at %ASL_VENV%\Scripts\activate.bat
    goto :fail_args
)
call "%ASL_VENV%\Scripts\activate.bat"

:done
call :_cleanup
exit /b 0

:_probe
echo %_ASL_PROBE% | findstr /I /C:"\software\Production" >nul
if not errorlevel 1 set "ASL_ENV=PROD" & goto :eof
echo %_ASL_PROBE% | findstr /I /C:"\software\UAT" >nul
if not errorlevel 1 set "ASL_ENV=UAT" & goto :eof
echo %_ASL_PROBE% | findstr /I /C:"\software\Development" >nul
if not errorlevel 1 set "ASL_ENV=DEV" & goto :eof
goto :eof

REM ASL_ENV, ASL_LIB, PYTHONPATH, ASL_VENV and ASL_ENV_SOURCE stay for the caller.
:_cleanup
set "_ASL_PROBE="
set "_ASL_HERE="
set "_ASL_TIER="
set "_ASL_QUIET="
set "_ASL_NOACTIVATE="
set "ASL_LIB_PROD="
set "ASL_LIB_UAT="
set "ASL_LIB_DEV="
goto :eof

:usage
echo Usage: call set_asl_env.cmd [/quiet] [/noactivate]
echo   /quiet        no banner, or set ASL_QUIET=1
echo   /noactivate   set the variables, leave the venv alone
echo Sets ASL_ENV, ASL_LIB, PYTHONPATH, ASL_VENV, ASL_ENV_SOURCE.
echo ASL_ENV comes from ASL_ENV, else the working dir or this folder, else PYTHONPATH.
echo ASL_LIB is PROD unless preset, or ASL_LIB_OVERRIDE is PROD, UAT or DEV.
echo Exit: 0 ok, 2 ASL_ENV unusable, 3 could not detect.
call :_cleanup
exit /b 0

:fail_args
call :_cleanup
exit /b 2

:fail_detect
call :_cleanup
exit /b 3
