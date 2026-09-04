@echo off
REM PROD everything. Same result as setprod today, kept for symmetry and as an explicit reset.
call "%~dp0_set_tier.cmd" PROD PROD
exit /b %ERRORLEVEL%
