@echo off
REM Internal, called by setdev / setalldev / setprod / setallprod.
REM %1 tier for ASL_ENV and the script root. %2 tier for libraries, blank keeps the PROD default.
REM Clears preset ASL_LIB and ASL_ROOT: set_asl_env leaves them set, so without this
REM a second call in the same console would keep the first call's paths.
set "ASL_LIB="
set "ASL_ROOT="
set "ASL_ENV=%~1"
set "ASL_ROOT_OVERRIDE=%~1"
set "ASL_LIB_OVERRIDE=%~2"
call "%~dp0set_asl_env.cmd"
exit /b %ERRORLEVEL%
