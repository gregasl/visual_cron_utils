@echo off
REM DEV label and DEV script root. Libraries stay PROD.
call "%~dp0_set_tier.cmd" DEV
exit /b %ERRORLEVEL%
