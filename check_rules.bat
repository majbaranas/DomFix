@echo off
echo ========================================
echo DomFix - Quick Firestore Rules Check
echo ========================================
echo.

echo [1/3] Checking current Firestore rules...
firebase firestore:rules

echo.
echo [2/3] Downloading current deployed rules...
firebase firestore:rules > firestore.rules.deployed

echo.
echo [3/3] Comparing local vs deployed rules...
fc firestore.rules firestore.rules.deployed

echo.
echo ========================================
echo Rules check complete!
echo ========================================
echo.
echo If rules differ, redeploy with:
echo   firebase deploy --only firestore:rules
echo.
pause
