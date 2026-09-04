@echo off
REM python_venv_setup.cmd - point ASL_VENV at an existing venv. Never creates one.
REM CALL it, do not run it. No setlocal on purpose, same as set_asl_env.cmd.
REM   call "%~dp0python_venv_setup.cmd" /name:operations
REM   if errorlevel 1 exit /b %ERRORLEVEL%
REM Switches, any order, /x:VALUE or /x VALUE:
REM   /root:PATH         default C:\Applications\VirtualEnvironments
REM   /name:NAME         default operations
REM   /quiet             no banner, or set VENV_QUIET=1
REM Precedence: switch, then a preset variable (a VisualCron job variable counts), then default.
REM Sets: VENV_ROOT, ASL_VENV_NAME, ASL_VENV
REM Exit: 0 ok, 2 bad switch or input, 4 venv missing or unusable.

set "_VENV_ROOT_DEFAULT=C:\Applications\VirtualEnvironments"
set "_VENV_NAME_DEFAULT=operations"

REM VENV_QUIET=1 does the same as /quiet, for callers that cannot risk an unknown switch.
set "_VENV_QUIET=%VENV_QUIET%"
set "_VENV_SW_PATH="

REM _VENV_SW_PATH: an explicit /root or /name must beat a leftover ASL_VENV from
REM an earlier call in the same bat file.
:args
set "_VENV_A=%~1"
if not defined _VENV_A goto :args_done
if "%_VENV_A%"=="/?"                      goto :usage
if /I "%_VENV_A%"=="/help"                goto :usage
if /I "%_VENV_A:~0,6%"=="/root:"          set "VENV_ROOT=%_VENV_A:~6%"      & set "_VENV_SW_PATH=1" & shift & goto :args
if /I "%_VENV_A:~0,6%"=="/name:"          set "ASL_VENV_NAME=%_VENV_A:~6%"  & set "_VENV_SW_PATH=1" & shift & goto :args
if /I "%_VENV_A%"=="/root"                set "VENV_ROOT=%~2"      & set "_VENV_SW_PATH=1" & shift & shift & goto :args
if /I "%_VENV_A%"=="/name"                set "ASL_VENV_NAME=%~2"  & set "_VENV_SW_PATH=1" & shift & shift & goto :args
if /I "%_VENV_A%"=="/quiet"               set "_VENV_QUIET=1"      & shift & goto :args
echo python_venv_setup.cmd: unknown switch "%_VENV_A%"
echo python_venv_setup.cmd: /recreate and /python were removed. Create the venv by hand.
goto :fail_args

:args_done

if defined _VENV_SW_PATH set "ASL_VENV="
if not defined VENV_ROOT     set "VENV_ROOT=%_VENV_ROOT_DEFAULT%"
if not defined ASL_VENV_NAME set "ASL_VENV_NAME=%_VENV_NAME_DEFAULT%"

REM A trailing backslash would double up in the joined path.
if "%VENV_ROOT:~-1%"=="\" set "VENV_ROOT=%VENV_ROOT:~0,-1%"

REM A preset ASL_VENV is already a full path, so honour it and take the name back out.
if defined ASL_VENV goto :have_full_path

REM A name carrying a separator is really a path. Tested by substitution because
REM findstr does not reliably match a lone backslash, even inside /C:.
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

REM Idempotent: set_asl_env.cmd activates the same venv, and either may run first.
if /I "%VIRTUAL_ENV%"=="%ASL_VENV%" goto :report
call "%ASL_VENV%\Scripts\activate.bat"
if errorlevel 1 (
    echo ERROR: could not activate %ASL_VENV%
    goto :fail_venv
)

:report
if not defined _VENV_QUIET (
    "%ASL_VENV%\Scripts\python.exe" -c "import sys; print('venv python : ' + sys.version.split()[0])"
    echo venv python exe : %ASL_VENV%\Scripts\python.exe
)
call :_cleanup
exit /b 0

REM VENV_ROOT, ASL_VENV_NAME and ASL_VENV stay for the caller.
:_cleanup
set "_VENV_A="
set "_VENV_QUIET="
set "_VENV_ROOT_DEFAULT="
set "_VENV_NAME_DEFAULT="
set "_VENV_SW_PATH="
set "_VENV_T="
goto :eof

:usage
echo Usage: call python_venv_setup.cmd [/root:PATH] [/name:NAME] [/quiet]
echo   /root:PATH         default C:\Applications\VirtualEnvironments
echo   /name:NAME         default operations
echo   /quiet             no banner, or set VENV_QUIET=1
echo Switches also accept a space: /name operations. Never creates a venv.
echo Sets VENV_ROOT, ASL_VENV_NAME, ASL_VENV.
echo Exit: 0 ok, 2 bad switch or input, 4 venv missing or unusable.
call :_cleanup
exit /b 0

:fail_args
call :_cleanup
exit /b 2

:fail_venv
call :_cleanup
exit /b 4

