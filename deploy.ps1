$env:PATH += ";$env:ProgramFiles\nodejs;$env:APPDATA\npm"
Set-Location "C:\Users\anama\OneDrive\Desktop\DomFix-main"
Write-Host "Step 1: Login to Firebase (browser will open)..." -ForegroundColor Cyan
firebase login
Write-Host "Step 2: Deploying Cloud Functions..." -ForegroundColor Cyan
firebase deploy --only functions
Write-Host "DONE! Notifications are now live." -ForegroundColor Green
Read-Host "Press Enter to close"
