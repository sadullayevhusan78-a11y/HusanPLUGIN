@echo off
cd /d "%~dp0"
if not exist .venv (
  py -3.11 -m venv .venv
)
call .venv\Scripts\activate.bat
python -m pip install -r backend\requirements.txt
python backend\server.py
pause
