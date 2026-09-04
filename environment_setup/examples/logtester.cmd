@echo off

REM ---------------------------------------------------------------------------
REM logtester.cmd - run logging_test.py against one ASL environment.
REM
REM All of the environment work lives in set_asl_env.cmd now. This file only
REM reports what it inherited, calls the helper, and runs the script.
REM ---------------------------------------------------------------------------
set "ASL_ENV=DEV"
set "ASL_LIB_OVERRIDE=DEV"
echo ===========================================================================
echo logtester.cmd starting %DATE% %TIME%
echo ===========================================================================
echo.
echo --- working directory (pwd) ---
cd
echo.
echo --- this.cmd file lives in ---
echo %~dp0
echo.
echo --- inherited environment (set) ---
set
echo.

REM Override ASL_ENV_HELPER to test another copy. Args default with it, so an
REM overridden helper is never handed a switch it does not know.
if not defined ASL_ENV_HELPER (
    set "ASL_ENV_HELPER=\\aslfile01\aslcap\IT\software\Utilities\environment_setup\set_asl_env.cmd"
    set "ASL_ENV_ARGS=/quiet"
)
call "%ASL_ENV_HELPER%" %ASL_ENV_ARGS%
if errorlevel 1 (
    echo logtester.cmd stopping: set_asl_env.cmd returned %ERRORLEVEL%.
    exit /b %ERRORLEVEL%
)

REM --- What python actually ended up with. ----------------------------------
echo.
echo --- python being used ---
python -c "import sys; print(sys.version); print(sys.executable)"
echo.
echo --- sys.path as python sees it ---
python -c "import sys; [print(' ', p) for p in sys.path]"
echo.
echo --- secrets module resolved (must be the stdlib one) ---
python -c "import secrets; print(secrets.__file__)"
echo.
echo --- asl_logging that will actually be imported ---
python -c "import ASL.utils.asl_logging as m; print(m.__file__)"
echo.

echo --- where the two roots point ---
echo   imports from : %ASL_LIB%
echo   scripts from : %ASL_ROOT%   (%ASL_ROOT_SOURCE%)
echo.

REM Name the project, never the tier - ASL_ROOT follows the working directory.
echo --- running logging_test.py ---
REM python "%ASL_ROOT%\EOD\logging_test.py"
set "RC=%ERRORLEVEL%"

REM Guarded: an interactive prompt hangs forever under VisualCron.
if defined ASL_DEBUG_SHELL (
    echo.
    echo --- interactive PowerShell, type exit to resume logtester.cmd ---
    PowerShell -NoProfile -NoExit -Command "gci env: | sort Name | ft Name,Value -Auto"
)

echo.
echo ===========================================================================
echo logtester.cmd finished, ASL_ENV=%ASL_ENV%, exit code %RC%
echo ===========================================================================

exit /b %RC%
