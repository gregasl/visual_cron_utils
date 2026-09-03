@echo off
REM ===========================================================================
REM set_asl_env.bat - work out which ASL environment this machine is running as,
REM               point PYTHONPATH at it, and activate the venv.
REM
REM CALL it, do not run it. There is no setlocal in here on purpose: the whole
REM point is that the variables it sets survive into the calling bat file.
REM
REM   call "\\aslfile01\aslcap\IT\software\Utilities\set_asl_env.bat"
REM   if errorlevel 1 exit /b %ERRORLEVEL%
REM   python my_script.py
REM
REM Switches (any order):
REM   /quiet        do not print the banner
REM   /noactivate   set the variables but leave the venv alone
REM
REM Sets, for the caller:
REM   ASL_ENV     PROD | UAT | DEV
REM   ASL_LIB     the library root for that environment
REM   PYTHONPATH  = ASL_LIB, and nothing else
REM   ASL_VENV    the virtual environment that was activated
REM
REM Exit codes: 0 ok, 2 ASL_ENV held an unusable value, 3 could not tell which
REM environment this is. Both failures print why.
REM
REM How the environment is decided, most explicit first:
REM   1. ASL_ENV already set (a VisualCron job/task variable, or the caller).
REM   2. The working directory, or this helper's own location, containing
REM      ...\IT\software\Production\ | \UAT\ | \Development\
REM   3. The PYTHONPATH the machine already had. VisualCron servers carry a
REM      machine-level PYTHONPATH naming their environment, while a job's
REM      working directory is usually somewhere neutral like C:\temp.
REM
REM Nothing is guessed beyond that - no fallback environment, and no git
REM working copy, which a job may never assume exists. If none of the three
REM apply, this stops with exit code 3 and the caller should stop too.
REM ===========================================================================

REM --- The only lines to edit when a path moves. -----------------------------
set "ASL_LIB_PROD=\\aslfile01\aslcap\IT\software\Production\Python"
set "ASL_LIB_UAT=\\aslfile01\aslcap\IT\software\UAT\Python"
set "ASL_LIB_DEV=\\aslfile01\aslcap\IT\software\Development\Python"

REM Caller may pick a different venv by setting ASL_VENV before the call.
if not defined ASL_VENV set "ASL_VENV=C:\Applications\VirtualEnvironments\Operations"

REM --- Switches --------------------------------------------------------------
set "_ASL_QUIET="
set "_ASL_NOACTIVATE="
:args
if /I "%~1"=="/quiet"      set "_ASL_QUIET=1"      & shift & goto :args
if /I "%~1"=="/noactivate" set "_ASL_NOACTIVATE=1" & shift & goto :args
if not "%~1"=="" (
    echo set_asl_env.bat: unknown switch "%~1"
    goto :fail_args
)

REM This helper's own folder. Note that %~dp0 here is set_asl_env.bat's directory,
REM not the caller's - cmd gives a called bat its own path. Still worth
REM probing, because the helper and its callers normally live in one tree.
set "_ASL_HERE=%~dp0"
if "%_ASL_HERE:~-1%"=="\" set "_ASL_HERE=%_ASL_HERE:~0,-1%"

REM ===========================================================================
REM Decide the environment.
REM ===========================================================================
if defined ASL_ENV (
    REM No parentheses in this value - the banner echoes it from inside an
    REM if-block, and a closing paren would end that block early.
    set "ASL_ENV_SOURCE=ASL_ENV was already set by VisualCron or the caller"
    goto :normalise
)

REM The separator must not be a character cmd parses - a pipe here would be
REM read as a real pipe by the findstr lines in :_probe.
set "ASL_ENV_SOURCE=detected from the working directory"
set "_ASL_PROBE=%CD% ; %_ASL_HERE%"
call :_probe
if defined ASL_ENV goto :normalise

set "ASL_ENV_SOURCE=detected from the inherited PYTHONPATH"
set "_ASL_PROBE=%PYTHONPATH%"
call :_probe
if defined ASL_ENV goto :normalise

echo ERROR: set_asl_env.bat cannot tell which ASL environment to use.
echo        working directory : %CD%
echo        set_asl_env.bat       : %_ASL_HERE%
echo        PYTHONPATH        : %PYTHONPATH%
echo        Set ASL_ENV to PROD, UAT or DEV on the job and re-run.
goto :fail_detect

:normalise
REM Trim spaces off the ends. A VisualCron job variable easily carries one,
REM and " PROD " would otherwise fall through as an unusable value.
:_trim_lead
if not defined ASL_ENV goto :_trim_done
if "%ASL_ENV:~0,1%"==" " set "ASL_ENV=%ASL_ENV:~1%" & goto :_trim_lead
:_trim_trail
if "%ASL_ENV:~-1%"==" " set "ASL_ENV=%ASL_ENV:~0,-1%" & goto :_trim_trail
:_trim_done

REM Fold the value to one of the three names we understand.
if /I "%ASL_ENV%"=="PROD"        set "ASL_ENV=PROD"
if /I "%ASL_ENV%"=="PRODUCTION"  set "ASL_ENV=PROD"
if /I "%ASL_ENV%"=="UAT"         set "ASL_ENV=UAT"
if /I "%ASL_ENV%"=="DEV"         set "ASL_ENV=DEV"
if /I "%ASL_ENV%"=="DEVELOPMENT" set "ASL_ENV=DEV"

set "ASL_LIB="
if "%ASL_ENV%"=="PROD" set "ASL_LIB=%ASL_LIB_PROD%"
if "%ASL_ENV%"=="UAT"  set "ASL_LIB=%ASL_LIB_UAT%"
if "%ASL_ENV%"=="DEV"  set "ASL_LIB=%ASL_LIB_DEV%"

if not defined ASL_LIB (
    echo ERROR: set_asl_env.bat - ASL_ENV=%ASL_ENV% is not one of PROD, UAT, DEV.
    goto :fail_args
)

REM ===========================================================================
REM Point python at it.
REM
REM Package root only. ASL\utils must NOT go on the path: it holds a secrets.py
REM that would shadow the stdlib secrets module, and numpy needs the real one
REM (from secrets import randbits). One environment only - no dev-then-prod
REM fallback, or you cannot tell afterwards which copy actually ran.
REM ===========================================================================
set "PYTHONPATH=%ASL_LIB%"

if not defined _ASL_QUIET (
    echo ===========================================================================
    echo ASL_ENV     : %ASL_ENV%
    echo how         : %ASL_ENV_SOURCE%
    echo library     : %ASL_LIB%
    echo PYTHONPATH  : %PYTHONPATH%
    echo venv        : %ASL_VENV%
    echo host / user : %COMPUTERNAME% / %USERNAME%
    echo ===========================================================================
)

if not exist "%ASL_LIB%\ASL\__init__.py" (
    echo WARNING: %ASL_LIB%\ASL\__init__.py not found - is the share reachable?
)

if "%ASL_ENV%"=="PROD" if not defined _ASL_QUIET (
    echo *** Running against PRODUCTION libraries. ***
)

if defined _ASL_NOACTIVATE goto :done

if not exist "%ASL_VENV%\Scripts\activate.bat" (
    echo ERROR: set_asl_env.bat - no venv at %ASL_VENV%\Scripts\activate.bat
    goto :fail_args
)
call "%ASL_VENV%\Scripts\activate.bat"

:done
call :_cleanup
exit /b 0

REM ===========================================================================
REM Subroutines
REM ===========================================================================

REM Match one probe string against the environment folder names.
:_probe
echo %_ASL_PROBE% | findstr /I /C:"\software\Production" >nul
if not errorlevel 1 set "ASL_ENV=PROD" & goto :eof
echo %_ASL_PROBE% | findstr /I /C:"\software\UAT" >nul
if not errorlevel 1 set "ASL_ENV=UAT" & goto :eof
echo %_ASL_PROBE% | findstr /I /C:"\software\Development" >nul
if not errorlevel 1 set "ASL_ENV=DEV" & goto :eof
goto :eof

REM Drop our scratch variables. ASL_ENV, ASL_LIB, PYTHONPATH, ASL_VENV and
REM ASL_ENV_SOURCE are deliberately left behind for the caller.
:_cleanup
set "_ASL_PROBE="
set "_ASL_HERE="
set "_ASL_QUIET="
set "_ASL_NOACTIVATE="
set "ASL_LIB_PROD="
set "ASL_LIB_UAT="
set "ASL_LIB_DEV="
goto :eof

:fail_args
call :_cleanup
exit /b 2

:fail_detect
call :_cleanup
exit /b 3
