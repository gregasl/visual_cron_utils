@echo off
REM DEV label, DEV script root and DEV libraries.
call "%~dp0_set_tier.cmd" DEV DEV
exit /b %ERRORLEVEL%
