@echo off
REM set_asl_env.cmd - point python at an ASL environment and activate the venv.
REM CALL it, do not run it. No setlocal on purpose: the caller keeps the variables.
REM   call "\\aslfile01\aslcap\IT\software\Utilities\environment_setup\set_asl_env.cmd"
REM   if errorlevel 1 exit /b %ERRORLEVEL%
REM Three independent axes: ASL_LIB is what python IMPORTS, ASL_ROOT is where the
REM .py you RUN lives, ASL_ENV is which databases and log targets the job uses.
REM ASL_LIB defaults to PROD; ASL_ROOT follows the working dir.
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

REM %~dp0 is this file's folder, not the caller's. Captured before :args:
REM shift moves %0 along with the switches, and %~dp0 of a switch is the
REM working directory, not this file.
set "_ASL_HERE=%~dp0"
if "%_ASL_HERE:~-1%"=="\" set "_ASL_HERE=%_ASL_HERE:~0,-1%"

REM ASL_QUIET=1 suppresses the banner. A switch does not survive being passed
REM through a wrapper variable, so quiet is an environment variable only.
set "_ASL_QUIET=%ASL_QUIET%"
set "_ASL_NOACTIVATE="
:args
if "%~1"=="/?"             goto :usage
if /I "%~1"=="/help"       goto :usage
if /I "%~1"=="/noactivate" set "_ASL_NOACTIVATE=1" & shift & goto :args
if not "%~1"=="" (
    echo set_asl_env.cmd: unknown switch "%~1"
    goto :fail_args
)

REM One pass over the working directory, feeding both axes below.
call :_tier_of "%CD%"
set "_ASL_CWDTIER=%_ASL_TIERNAME%"

REM --- ASL_ENV: picks the databases and log targets the job uses, so it is never
REM guessed from PYTHONPATH - that names the library being imported, which is a
REM different axis and is PROD by default. A DEV job importing PROD libraries
REM must not be handed the PROD databases. Preset wins, else the CWD, else the
REM folder this helper runs from, else DEV - never PROD by accident.
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
REM Nothing named a tier. DEV is the least destructive answer: it points the
REM job at the play databases and the dev log targets, so a misconfigured job
REM cannot write to production. Loud, because it is a guess.
set "ASL_ENV=DEV"
set "ASL_ENV_SOURCE=default - nothing named a tier, see the warning above"
echo WARNING: set_asl_env.cmd cannot tell which ASL environment to use.
echo          working directory : %CD%
echo          set_asl_env.cmd   : %_ASL_HERE%
echo          Defaulting to ASL_ENV=DEV. Set ASL_ENV to PROD, UAT or DEV on the
echo          job to say so explicitly.
goto :normalise

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
echo Usage: call set_asl_env.cmd [/noactivate]
echo   /noactivate   set the variables, leave the venv alone
echo   ASL_QUIET=1   no banner. An environment variable, not a switch.
echo.
echo Sets ASL_ENV, ASL_LIB, ASL_ROOT, PYTHONPATH, ASL_VENV, and a _SOURCE for each.
echo   ASL_LIB   what python IMPORTS. PROD unless preset, or ASL_LIB_OVERRIDE
echo             names PROD, UAT, DEV or LOCAL. PYTHONPATH is set to it, alone.
echo   ASL_ROOT  where the .py you RUN lives, eg %%ASL_ROOT%%\Futures\job.py.
echo             From the working directory: only Production and UAT are
echo             recognised there, anything else is Development.
echo   ASL_ENV   which databases and log targets the job uses. Preset, else the
echo             working directory, else this helper's folder, else DEV with a
echo             warning. Never PYTHONPATH, never PROD by accident.
echo.
echo A missing venv is a warning, not a failure - the run continues on system python.
echo Exit: 0 ok, 2 bad switch or ASL_LIB_OVERRIDE.
call :_cleanup
exit /b 0

:fail_args
call :_cleanup
exit /b 2
