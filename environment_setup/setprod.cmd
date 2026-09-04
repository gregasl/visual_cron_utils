@echo off
REM PROD label and PROD script root. Also resets any leftover DEV overrides.
call "%~dp0_set_tier.cmd" PROD
exit /b %ERRORLEVEL%
