@echo off
REM ===========================================================================
REM python_venv_setup.bat - select an existing ASL python virtual environment
REM               under a root folder, then leave ASL_VENV pointing at it.
REM
REM This script does NOT create venvs. The venv must already exist; if it does
REM not, the script prints why and fails. Create venvs by hand, once, outside
REM of the job.
REM
REM CALL it, do not run it, if you want ASL_VENV to survive into your bat file.
REM There is no setlocal in here on purpose, same as set_asl_env.bat.
REM
REM   call "%~dp0python_venv_setup.bat" /name:operations
REM   if errorlevel 1 exit /b %ERRORLEVEL%
REM   call "%~dp0set_asl_env.bat"
REM
REM cmd.exe has no named parameters of its own - only %1..%9. The switches
REM below are parsed by hand in the :args loop, which is why both spellings
REM work:  /root:C:\Venvs   and   /root C:\Venvs
REM
REM Switches, any order:
REM   /root:PATH        where venvs live, default C:\Applications\VirtualEnvironments
REM   /name:NAME        venv folder name, default operations
REM   /requirements:F   pip install -r F into the existing venv
REM   /nopip            skip the pip upgrade
REM   /quiet            do not print the banner
REM
REM Precedence, most explicit first: the switch, then a pre-set environment
REM variable, a VisualCron job/task variable counts, then the default.
REM
REM Sets, for the caller:
REM   VENV_ROOT      the root that was used
REM   ASL_VENV_NAME  the venv folder name
REM   ASL_VENV       the full path, which is the form set_asl_env.bat wants
REM
REM Exit codes: 0 ok, 2 bad switch or bad input, 4 venv missing or unusable,
REM 5 pip install failed. Every failure prints why.
REM ===========================================================================

REM --- The only lines to edit when a path moves. -----------------------------
set "_VENV_ROOT_DEFAULT=C:\Applications\VirtualEnvironments"
set "_VENV_NAME_DEFAULT=operations"

REM --- Switches --------------------------------------------------------------
set "_VENV_NOPIP="
set "_VENV_QUIET="
set "_VENV_REQ="
set "_VENV_SW_PATH="

REM _VENV_SW_PATH records that /root or /name was given explicitly. An
REM explicit switch has to beat a pre-set ASL_VENV, which in a bat file that
REM makes several calls is often just the leftover from the previous one.
:args
set "_VENV_A=%~1"
if not defined _VENV_A goto :args_done
if /I "%_VENV_A:~0,6%"=="/root:"          set "VENV_ROOT=%_VENV_A:~6%"      & set "_VENV_SW_PATH=1" & shift & goto :args
if /I "%_VENV_A:~0,6%"=="/name:"          set "ASL_VENV_NAME=%_VENV_A:~6%"  & set "_VENV_SW_PATH=1" & shift & goto :args
if /I "%_VENV_A:~0,14%"=="/requirements:" set "_VENV_REQ=%_VENV_A:~14%"     & shift & goto :args
if /I "%_VENV_A%"=="/root"                set "VENV_ROOT=%~2"      & set "_VENV_SW_PATH=1" & shift & shift & goto :args
if /I "%_VENV_A%"=="/name"                set "ASL_VENV_NAME=%~2"  & set "_VENV_SW_PATH=1" & shift & shift & goto :args
if /I "%_VENV_A%"=="/requirements"        set "_VENV_REQ=%~2"      & shift & shift & goto :args
if /I "%_VENV_A%"=="/nopip"               set "_VENV_NOPIP=1"      & shift & goto :args
if /I "%_VENV_A%"=="/quiet"               set "_VENV_QUIET=1"      & shift & goto :args
echo python_venv_setup.bat: unknown switch "%_VENV_A%"
echo python_venv_setup.bat: this script no longer creates venvs - /recreate
echo and /python were removed. Create the venv by hand, then call this again.
goto :fail_args

:args_done

REM --- Fill in the blanks ----------------------------------------------------
if defined _VENV_SW_PATH set "ASL_VENV="
if not defined VENV_ROOT     set "VENV_ROOT=%_VENV_ROOT_DEFAULT%"
if not defined ASL_VENV_NAME set "ASL_VENV_NAME=%_VENV_NAME_DEFAULT%"

REM A trailing backslash on the root would double up in the joined path.
if "%VENV_ROOT:~-1%"=="\" set "VENV_ROOT=%VENV_ROOT:~0,-1%"

REM ASL_VENV may already hold a full path - a caller or a job variable that
REM names the venv outright. Honour it, and take the name back out of it.
if defined ASL_VENV goto :have_full_path

REM A name carrying a separator is really a path, so do not join it to the root.
REM Tested by substitution rather than findstr: findstr does not reliably match
REM a lone backslash even inside /C:, and silently joined C:\... onto the root.
set "_VENV_T=%ASL_VENV_NAME:\=%"
if not "%_VENV_T%"=="%ASL_VENV_NAME%" goto :name_is_path
if "%ASL_VENV_NAME:~1,1%"==":"         goto :name_is_path
set "ASL_VENV=%VENV_ROOT%\%ASL_VENV_NAME%"
goto :have_full_path

:name_is_path
set "ASL_VENV=%ASL_VENV_NAME%"

:have_full_path
for %%I in ("%ASL_VENV%") do set "ASL_VENV_NAME=%%~nxI"

if not defined _VENV_QUIET (
    echo ===========================================================================
    echo VENV_ROOT   : %VENV_ROOT%
    echo venv name   : %ASL_VENV_NAME%
    echo venv path   : %ASL_VENV%
    echo host / user : %COMPUTERNAME% / %USERNAME%
    echo ===========================================================================
)

REM --- Require an existing venv ----------------------------------------------
REM Nothing here creates anything. Say exactly what is missing and stop.
if not exist "%VENV_ROOT%\" (
    echo ERROR: venv root does not exist: %VENV_ROOT%
    echo This script does not create venvs. Create the venv first.
    goto :fail_venv
)
if not exist "%ASL_VENV%\" (
    echo ERROR: venv does not exist: %ASL_VENV%
    echo This script does not create venvs. Create the venv first.
    echo Existing venvs under %VENV_ROOT%:
    dir /B /AD "%VENV_ROOT%" 2>nul
    goto :fail_venv
)
if not exist "%ASL_VENV%\Scripts\activate.bat" (
    echo ERROR: %ASL_VENV% exists but is not a venv - Scripts\activate.bat is missing.
    goto :fail_venv
)
if not exist "%ASL_VENV%\Scripts\python.exe" (
    echo ERROR: %ASL_VENV% exists but is not a venv - Scripts\python.exe is missing.
    goto :fail_venv
)

REM --- Activate, then furnish ------------------------------------------------
call "%ASL_VENV%\Scripts\activate.bat"
if errorlevel 1 (
    echo ERROR: could not activate %ASL_VENV%
    goto :fail_venv
)

if defined _VENV_NOPIP goto :req
echo Upgrading pip
"%ASL_VENV%\Scripts\python.exe" -m pip install --upgrade pip --disable-pip-version-check
if errorlevel 1 echo WARNING: pip upgrade failed - carrying on.

:req
if not defined _VENV_REQ goto :report
if not exist "%_VENV_REQ%" (
    echo ERROR: requirements file not found: %_VENV_REQ%
    goto :fail_args
)
echo Installing from %_VENV_REQ%
"%ASL_VENV%\Scripts\python.exe" -m pip install -r "%_VENV_REQ%" --disable-pip-version-check
if errorlevel 1 (
    echo ERROR: pip install -r %_VENV_REQ% failed.
    goto :fail_pip
)

:report
if not defined _VENV_QUIET (
    "%ASL_VENV%\Scripts\python.exe" -c "import sys; print('venv python : ' + sys.version.split()[0])"
    echo venv python exe : %ASL_VENV%\Scripts\python.exe
)
call :_cleanup
exit /b 0

REM ===========================================================================
REM Subroutines
REM ===========================================================================

REM Drop our scratch variables. VENV_ROOT, ASL_VENV_NAME and ASL_VENV are
REM deliberately left behind for the caller.
:_cleanup
set "_VENV_A="
set "_VENV_NOPIP="
set "_VENV_QUIET="
set "_VENV_REQ="
set "_VENV_ROOT_DEFAULT="
set "_VENV_NAME_DEFAULT="
set "_VENV_SW_PATH="
set "_VENV_T="
goto :eof

:fail_args
call :_cleanup
exit /b 2

:fail_venv
call :_cleanup
exit /b 4

:fail_pip
call :_cleanup
exit /b 5
