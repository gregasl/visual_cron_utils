@echo off
REM set_asl_env.cmd - pick the ASL environment, point PYTHONPATH at it, activate the venv.
REM CALL it, do not run it. No setlocal on purpose: the caller keeps the variables.
REM   call "\\aslfile01\aslcap\IT\software\Utilities\set_asl_env.cmd"
REM   if errorlevel 1 exit /b %ERRORLEVEL%
REM Switches: /quiet /noactivate /help. ASL_QUIET=1 is the same as /quiet.
REM Sets: ASL_ENV, ASL_LIB, ASL_ROOT, PYTHONPATH, ASL_VENV, and a _SOURCE for each.
REM Two independent axes: ASL_LIB is what python IMPORTS, ASL_ROOT is where the
REM .py you RUN lives. ASL_LIB defaults to PROD; ASL_ROOT follows the working dir.
REM ASL_LIB is PROD unless preset, or ASL_LIB_OVERRIDE names PROD, UAT, DEV or LOCAL.
REM ASL_ENV only labels the run - it no longer selects the library.
REM Exit: 0 ok, 2 bad switch or ASL_LIB_OVERRIDE, 3 could not detect ASL_ENV.
REM Detected in this order: ASL_ENV, then working dir or this folder, then inherited PYTHONPATH.

set "_ASL_ROOT_PROD=\\aslfile01\aslcap\IT\software\Production"
set "_ASL_ROOT_UAT=\\aslfile01\aslcap\IT\software\UAT"
set "_ASL_ROOT_DEV=\\aslfile01\aslcap\IT\software\Development"

set "ASL_LIB_PROD=%_ASL_ROOT_PROD%\Python"
set "ASL_LIB_UAT=%_ASL_ROOT_UAT%\Python"
set "ASL_LIB_DEV=%_ASL_ROOT_DEV%\Python"
set "ASL_LIB_LOCAL=C:\Program Files\Python"

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
if /I "%_ASL_TIER%"=="LOCAL"       set "ASL_LIB=%ASL_LIB_LOCAL%"

if not defined ASL_LIB (
    echo ERROR: set_asl_env.cmd - ASL_LIB_OVERRIDE=%ASL_LIB_OVERRIDE% is not one of PROD, UAT, DEV, LOCAL.
    goto :fail_args
)

:have_lib

REM ASL_ROOT is where job SCRIPTS live, and is independent of ASL_LIB above.
REM Taken from the working directory: only a Production CWD gets Production,
REM anything unrecognised gets Development. The tier name is matched from the
REM CWD but the path is rebuilt from our own UNC roots, so a mapped drive or
REM a lower-case Software folder cannot leak into the result.
if defined ASL_ROOT (
    set "ASL_ROOT_SOURCE=ASL_ROOT was preset by the caller"
    goto :have_root
)
set "ASL_ROOT=%_ASL_ROOT_DEV%"
set "ASL_ROOT_SOURCE=default, working directory names no tier"
set "_ASL_CWD=%CD:\software\=|%"
if "%_ASL_CWD%"=="%CD%" goto :have_root
for /f "tokens=2 delims=|" %%A in ("%_ASL_CWD%") do set "_ASL_CWD=%%A"
for /f "tokens=1 delims=\" %%A in ("%_ASL_CWD%") do set "_ASL_CWD=%%A"
if /I "%_ASL_CWD%"=="Production"  set "ASL_ROOT=%_ASL_ROOT_PROD%" & set "ASL_ROOT_SOURCE=working directory"
if /I "%_ASL_CWD%"=="UAT"         set "ASL_ROOT=%_ASL_ROOT_UAT%"  & set "ASL_ROOT_SOURCE=working directory"
if /I "%_ASL_CWD%"=="Development" set "ASL_ROOT=%_ASL_ROOT_DEV%"  & set "ASL_ROOT_SOURCE=working directory"

:have_root

REM Package root only. ASL\utils holds a secrets.py that would shadow the stdlib
REM secrets module, which numpy needs. One environment only, never a fallback.
set "PYTHONPATH=%ASL_LIB%"

if not defined _ASL_QUIET (
    echo ===========================================================================
    echo ASL_ENV     : %ASL_ENV%
    echo how         : %ASL_ENV_SOURCE%
    echo library     : %ASL_LIB%   (imports)
    echo lib from    : %ASL_LIB_SOURCE%
    echo script root : %ASL_ROOT%   (the .py to run)
    echo root from   : %ASL_ROOT_SOURCE%
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

REM Idempotent: python_venv_setup.cmd activates the same venv, and either may run first.
if /I "%VIRTUAL_ENV%"=="%ASL_VENV%" goto :done

REM Missing venv is a warning, not a failure - fall back to the system python.
if not exist "%ASL_VENV%\Scripts\activate.bat" (
    echo WARNING: no venv at %ASL_VENV% - continuing on the system python.
    set "ASL_VENV="
    goto :done
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
set "_ASL_CWD="
set "_ASL_QUIET="
set "_ASL_NOACTIVATE="
set "ASL_LIB_PROD="
set "ASL_LIB_UAT="
set "ASL_LIB_DEV="
set "ASL_LIB_LOCAL="
set "_ASL_ROOT_PROD="
set "_ASL_ROOT_UAT="
set "_ASL_ROOT_DEV="
goto :eof

:usage
echo Usage: call set_asl_env.cmd [/quiet] [/noactivate]
echo   /quiet        no banner, or set ASL_QUIET=1
echo   /noactivate   set the variables, leave the venv alone
echo Sets ASL_ENV, ASL_LIB, PYTHONPATH, ASL_VENV, ASL_ENV_SOURCE.
echo ASL_ENV comes from ASL_ENV, else the working dir or this folder, else PYTHONPATH.
echo ASL_LIB (imports) is PROD unless preset, or ASL_LIB_OVERRIDE is PROD, UAT, DEV or LOCAL.
echo ASL_ROOT (script root) comes from the working directory - only Production and UAT
echo are recognised there, anything else is Development. Preset ASL_ROOT to force it.
echo A missing venv is a warning, not a failure - the run continues on the system python.
echo Exit: 0 ok, 2 bad switch or ASL_LIB_OVERRIDE, 3 could not detect ASL_ENV.
call :_cleanup
exit /b 0

:fail_args
call :_cleanup
exit /b 2

:fail_detect
call :_cleanup
exit /b 3
