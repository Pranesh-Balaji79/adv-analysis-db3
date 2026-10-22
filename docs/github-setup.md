# GitHub Upload Guide

1. Download and extract the project ZIP.
2. Open PowerShell in the extracted `advanced_sql_analytics` folder (the folder containing `README.md`).
3. Confirm the root with `Get-ChildItem`.
4. Create an empty repository on GitHub; do not initialize it with a README if you plan to push this folder as-is.
5. Run:

```powershell
git init
git add .
git status
git commit -m "Add advanced SQL analytics queries"
git branch -M main
git remote add origin https://github.com/YOUR-USERNAME/YOUR-REPOSITORY.git
git push -u origin main
```

Replace `YOUR-USERNAME` and `YOUR-REPOSITORY`. If Git requests authentication, use GitHub's supported HTTPS sign-in or SSH key setup; do not paste credentials into SQL files or README.

Before committing, verify `git status` and make sure only intended source/docs are staged. `docs/local-test-output.txt` is not included until you create it from your actual local run, so the repository will not misrepresent unrun tests as executed evidence.
