@echo off
chcp 65001 >nul
title Servidor de pruebas Bel-Aaktun
python "%~dp0servidor.py"
pause
