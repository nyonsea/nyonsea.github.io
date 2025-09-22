@echo off
REM =============================================
REM InfraUtility 自動実行タスク登録バッチ
REM     /RL HIGHEST ：管理者権限で実行
REM     /SC DAILY /ST 03:00 ：毎日午前3時に実行
REM     -ExecutionPolicy Bypass ：スクリプト署名がなくても実行可能
REM     "%PSPath%" はフルパス指定
REM =============================================

SET TaskName=InfraUtility_Auto
SET PSPath=C:\Scripts\InfraUtility_Enterprise_Full.ps1

REM タスク登録（毎日 3:00AM 実行、管理者権限）
schtasks /Create /F /RL HIGHEST /SC DAILY /TN "%TaskName%" /TR "powershell.exe -ExecutionPolicy Bypass -File \"%PSPath%\" " /ST 03:00

echo スケジュールタスク "%TaskName%" を登録しました。
pause
