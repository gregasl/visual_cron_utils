@echo off
REM set_asl_env.cmd - point python at an ASL environment and activate the venv.
REM CALL it, do not run it. No setlocal on purpose: the caller keeps the variables.
REM   call "\\aslfile01\aslcap\IT\software\Utilities\environment_setup\set_asl_env.cmd"
REM   if errorlevel 1 exit /b %ERRORLEVEL%
REM Two independent axes: ASL_LIB is what python IMPORTS, ASL_ROOT is where the
REM .py you RUN lives. ASL_LIB defaults to PROD; ASL_ROOT follows the working dir.
REM Run /help for the full contract.

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

REM One pass over the working directory, feeding both axes below.
call :_tier_of "%CD%"
set "_ASL_CWDTIER=%_ASL_TIERNAME%"

REM --- ASL_ENV: a label. Preset wins, else the CWD, else this folder, else PYTHONPATH.
if defined ASL_ENV (
    REM No parentheses in this value - the banner echoes it from inside an if-block.
    set "ASL_ENV_SOURCE=preset by VisualCron or the caller"
    goto :normalise
)
set "_ASL_TIERNAME=%_ASL_CWDTIER%"
set "ASL_ENV_SOURCE=working directory"
if defined _ASL_TIERNAME goto :from_tier
call :_tier_of "%_ASL_HERE%"
set "ASL_ENV_SOURCE=the folder this helper runs from"
if defined _ASL_TIERNAME goto :from_tier
call :_tier_of "%PYTHONPATH%"
set "ASL_ENV_SOURCE=inherited PYTHONPATH"
if defined _ASL_TIERNAME goto :from_tier

echo ERROR: set_asl_env.cmd cannot tell which ASL environment to use.
echo        working directory : %CD%
echo        set_asl_env.cmd   : %_ASL_HERE%
echo        PYTHONPATH        : %PYTHONPATH%
echo        Set ASL_ENV to PROD, UAT or DEV on the job and re-run.
goto :fail_detect

:from_tier
if /I "%_ASL_TIERNAME%"=="Production"  set "ASL_ENV=PROD"
if /I "%_ASL_TIERNAME%"=="UAT"         set "ASL_ENV=UAT"
if /I "%_ASL_TIERNAME%"=="Development" set "ASL_ENV=DEV"

:normalise
call :_norm ASL_ENV
if /I "%ASL_ENV%"=="PRODUCTION"  set "ASL_ENV=PROD"
if /I "%ASL_ENV%"=="DEVELOPMENT" set "ASL_ENV=DEV"
if /I "%ASL_ENV%"=="PROD"        set "ASL_ENV=PROD"
if /I "%ASL_ENV%"=="UAT"         set "ASL_ENV=UAT"
if /I "%ASL_ENV%"=="DEV"         set "ASL_ENV=DEV"

REM --- ASL_LIB: what python imports. PROD unless preset or overridden.
if defined ASL_LIB (
    set "ASL_LIB_SOURCE=preset by the caller"
    goto :have_lib
)
set "_ASL_TIER=PROD"
set "ASL_LIB_SOURCE=default"
if defined ASL_LIB_OVERRIDE (
    set "_ASL_TIER=%ASL_LIB_OVERRIDE%"
    set "ASL_LIB_SOURCE=ASL_LIB_OVERRIDE"
)
call :_norm _ASL_TIER
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

REM --- ASL_ROOT: where the job's own .py lives. From the CWD tier parsed above.
REM Only Production and UAT are recognised there; anything else is Development.
REM The path is rebuilt from our own UNC roots, so a mapped drive cannot leak in.
if defined ASL_ROOT (
    set "ASL_ROOT_SOURCE=preset by the caller"
    goto :have_root
)
if not defined ASL_ROOT_OVERRIDE goto :root_from_cwd
set "_ASL_TIER=%ASL_ROOT_OVERRIDE%"
call :_norm _ASL_TIER
set "ASL_ROOT_SOURCE=ASL_ROOT_OVERRIDE"
if /I "%_ASL_TIER%"=="PROD"        set "ASL_ROOT=%_ASL_ROOT_PROD%"
if /I "%_ASL_TIER%"=="PRODUCTION"  set "ASL_ROOT=%_ASL_ROOT_PROD%"
if /I "%_ASL_TIER%"=="UAT"         set "ASL_ROOT=%_ASL_ROOT_UAT%"
if /I "%_ASL_TIER%"=="DEV"         set "ASL_ROOT=%_ASL_ROOT_DEV%"
if /I "%_ASL_TIER%"=="DEVELOPMENT" set "ASL_ROOT=%_ASL_ROOT_DEV%"
if not defined ASL_ROOT (
    echo ERROR: set_asl_env.cmd - ASL_ROOT_OVERRIDE=%ASL_ROOT_OVERRIDE% is not one of PROD, UAT, DEV.
    goto :fail_args
)
goto :have_root

:root_from_cwd
set "ASL_ROOT=%_ASL_ROOT_DEV%"
set "ASL_ROOT_SOURCE=default, working directory names no tier"
if /I "%_ASL_CWDTIER%"=="Production"  set "ASL_ROOT=%_ASL_ROOT_PROD%" & set "ASL_ROOT_SOURCE=working directory"
if /I "%_ASL_CWDTIER%"=="UAT"         set "ASL_ROOT=%_ASL_ROOT_UAT%"  & set "ASL_ROOT_SOURCE=working directory"
if /I "%_ASL_CWDTIER%"=="Development" set "ASL_ROOT=%_ASL_ROOT_DEV%"  & set "ASL_ROOT_SOURCE=working directory"
:have_root

REM Package root only. ASL\utils holds a secrets.py that would shadow the stdlib
REM secrets module, which numpy needs. One environment only, never a fallback.
set "PYTHONPATH=%ASL_LIB%"

if not defined _ASL_QUIET (
    echo ===========================================================================
    echo ASL_ENV     : %ASL_ENV%   ^(%ASL_ENV_SOURCE%^)
    echo library     : %ASL_LIB%   ^(imports, %ASL_LIB_SOURCE%^)
    echo script root : %ASL_ROOT%   ^(the .py to run, %ASL_ROOT_SOURCE%^)
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

REM in: %1 a path. out: _ASL_TIERNAME = Production, UAT, Development, or empty.
:_tier_of
set "_ASL_TIERNAME="
set "_ASL_T=%~1"
if not defined _ASL_T goto :eof
set "_ASL_T=%_ASL_T:\software\=|%"
if "%_ASL_T%"=="%~1" goto :eof
for /f "tokens=2 delims=|" %%A in ("%_ASL_T%") do set "_ASL_T=%%A"
for /f "tokens=1 delims=\" %%A in ("%_ASL_T%") do set "_ASL_T=%%A"
if /I "%_ASL_T%"=="Production"  set "_ASL_TIERNAME=Production"
if /I "%_ASL_T%"=="UAT"         set "_ASL_TIERNAME=UAT"
if /I "%_ASL_T%"=="Development" set "_ASL_TIERNAME=Development"
goto :eof

REM in: %1 a variable NAME. Strips quotes and outer spaces in place.
:_norm
call set "_ASL_T=%%%~1%%"
set "_ASL_T=%_ASL_T:"=%"
:_norm_lead
if not defined _ASL_T goto :eof
if "%_ASL_T:~0,1%"==" " set "_ASL_T=%_ASL_T:~1%" & goto :_norm_lead
:_norm_trail
if "%_ASL_T:~-1%"==" " set "_ASL_T=%_ASL_T:~0,-1%" & goto :_norm_trail
set "%~1=%_ASL_T%"
goto :eof

REM ASL_ENV, ASL_LIB, ASL_ROOT, PYTHONPATH, ASL_VENV and the _SOURCEs stay for the caller.
:_cleanup
set "_ASL_HERE="
set "_ASL_T="
set "_ASL_TIER="
set "_ASL_TIERNAME="
set "_ASL_CWDTIER="
set "_ASL_QUIET="
set "_ASL_NOACTIVATE="
set "_ASL_ROOT_PROD="
set "_ASL_ROOT_UAT="
set "_ASL_ROOT_DEV="
set "ASL_LIB_PROD="
set "ASL_LIB_UAT="
set "ASL_LIB_DEV="
set "ASL_LIB_LOCAL="
goto :eof

:usage
echo Usage: call set_asl_env.cmd [/quiet] [/noactivate]
echo   /quiet        no banner, or set ASL_QUIET=1
echo   /noactivate   set the variables, leave the venv alone
echo.
echo Sets ASL_ENV, ASL_LIB, ASL_ROOT, PYTHONPATH, ASL_VENV, and a _SOURCE for each.
echo   ASL_LIB   what python IMPORTS. PROD unless preset, or ASL_LIB_OVERRIDE
echo             names PROD, UAT, DEV or LOCAL. PYTHONPATH is set to it, alone.
echo   ASL_ROOT  where the .py you RUN lives, eg %%ASL_ROOT%%\Futures\job.py.
echo             From the working directory: only Production and UAT are
echo             recognised there, anything else is Development.
echo   ASL_ENV   a label only. Preset, else the working directory, else this
echo             helper's folder, else the inherited PYTHONPATH.
echo.
echo A missing venv is a warning, not a failure - the run continues on system python.
echo Exit: 0 ok, 2 bad switch or ASL_LIB_OVERRIDE, 3 could not detect ASL_ENV.
call :_cleanup
exit /b 0

:fail_args
call :_cleanup
exit /b 2

:fail_detect
call :_cleanup
exit /b 3
