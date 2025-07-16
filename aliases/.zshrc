########################
## Terraform Commands ##
########################

# format all tf files in directory and subdirs
alias tfmt="terraform fmt --recursive"

##################
## Git Commands ##
##################

# will return master or main, depending on how old your repo is
# probably not useful if you have both a main and a master in your repo
git_main_branch () {
    git branch | cut -c 3- | grep -E '^master$|^main$'
}

alias gc='git checkout '

# switch to main branch
alias gcm='gc $(git_main_branch)'

# get all the stuff
alias gp="git pull --all"

# update! if you're on the main branch, will stash any changes and then will run git pull
# if on a branch, will stash any changes, check out the main branch, run git pull, check out branch you were on again and do a rebase
# does not try to complete the rebase or do any pushing; does not attempt to unstash
gitup() {
  mainbranch=$(git_main_branch)
  branch=$(git branch --show-current)
  echo "Current branch: $branch"
  branchstatus=$(git status -s)
  if [ -z $branchstatus ]; then
    ## do nothing
  else
    echo 'Changes detected. Stashing now. Unstash after updating.'
    git add .
    git stash
  fi
  if [ $branch = $mainbranch ]; then
    echo 'Getting latest from remote'
    gp
  else
    gcm
    echo "On $(git branch --show-current). Getting latest from remote"
    gp
    git checkout $branch
    echo "Attempting a rebase from $mainbranch"
    git rebase $mainbranch
  fi
  unset mainbranch
  unset branch
  unset branchstatus
}

# if on main branch, run git pull
# if on a branch, will switch to main and then delete teh branch and then run git pull
gitdel() {
  mainbranch=$(git_main_branch)
  branch=$(git branch --show-current)
  if [ $branch != $mainbranch ]; then
    gcm
    git branch -D $branch
  fi
  gp
}
