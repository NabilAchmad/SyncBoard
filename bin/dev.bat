@echo off
where ruby >nul 2>&1
if errorlevel 1 (
  if exist "C:\Ruby34-x64\bin\ruby.exe" set "PATH=C:\Ruby34-x64\bin;%PATH%"
)
if not defined PORT set PORT=3000
set RUBY_DEBUG_OPEN=true
set RUBY_DEBUG_LAZY=true
foreman start -f Procfile.dev %*
