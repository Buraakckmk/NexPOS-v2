@echo off
title NexPOS Backend Server
cd /d "%~dp0"
echo ==========================================
echo       NexPOS Backend Baslatiliyor
echo ==========================================

rem Veritabani tablosu yoksa otomatik olusturur
node src/scripts/init-db.js

rem Backend sunucusunu baslatir
node src/server.js

pause
