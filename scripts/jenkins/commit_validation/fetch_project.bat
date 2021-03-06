@REM Fetches a project by project name, path and Git ref
@REM This script is normally used in conjunction with allcommits.py
@REM ./allcommits.py <change-id>|xargs -n 3 ./fetchproject.sh

set PROJECT=%1
set PROJECT_PATH=%2
set REFSPEC=%3

cd %PROJECT_PATH%
git reset --hard HEAD
git fetch ssh://review.couchbase.org:29418/%PROJECT% %REFSPEC%
git checkout FETCH_HEAD
cd ..
