Custom "git update" command solves the problem of not knowing what changes will be merged to your local 
working copy when you do "pull" from remote repository.

Note, that TortoiseGit's "Fetch" command effectively makes "Pull" because it updates files in your working directory.
On the other hand, "git fetch" only updates "origin" branch and doesn't change local working copy.

The "git update" command runs "git fetch" to update your "origin" branch and then shows the list of 
commits in remote repository which need to be merged into your "master" branch.

Then it asks you if you want to make the merge right away, and if so, merges (and rebases).

To enable the command, copy the "git-update" file into the directory with git commands 
(on Windows: C:\Program Files (x86)\Git\libexec\git-core\)


Even on Windows, we want to use Unix line endings. Make sure your Git is configured to use Unix line-endings:

  git config --global core.eol lf
  git config --global core.autocrlf input

With an existing repo that you have already checked out – that has the correct line endings
in the repo but not your working copy – you can run the following commands to fix it:

  git rm -rf --cached .
  git reset --hard HEAD 