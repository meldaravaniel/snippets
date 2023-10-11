# How to Convert from Subversion to Git

## Summary

1) Cleanup step
    * Large files that are unneeded
    * Jenkins jobs?
        * if people will still be working while you do this, you might want to make a copy of the current Jenkins build, but pointed to your new git repo so you can ensure stuff works before switching folks over.
    * Code collaborator? 
        * gitlab/github has merge requests, which work okay for smaller sets of file changes
        * you can [still use code collaborator, though](https://support.smartbear.com/collaborator/docs/source-control/git.html).
1) Converting svn repo to git repo
    * Follow atlassian steps
        * This takes several hours.
    * Make a gitlab/github repo
    * link up the repo with the remote gitlab/github repo
1) Set up structure on gitlab/github
    * Permissions, lock down master, etc
1) Converting builds to pull from git repo instead of svn repo
1) Teach the devs to git
    * Everyone needs to have git on their computer (many may already have it from working with other projects)
1) Drink champagne
    * Ding dong, subversion's dead!

![a gif of Michael Scott (The Office; Steve Carrell) holding a mug that reads "World's Best Boss".  The gif caption reads, "I think that pretty much sums it up"](https://media.giphy.com/media/dsKnRuALlWsZG/giphy.gif)

## Notes before you start:

This doesn't work super well for branches.  It seems to bring over tags just fine, but not all branches make it through.  I have chosen to not care about that, I recommend you do so as well, because trying to make EVERYTHING work perfectly is probably too much work to bother.  The SVN repo will be around for at least a little while longer so if you NEED a branch, it'll be there.  Chances are if SVN goes away, no one's going to remember wtf is in those branches anyways.  Be like Elsa.  Let it go.

![a gif of former president Obama saying, "Why don't we move on."](https://media.giphy.com/media/xUySTxQp21GMZhX916/giphy.gif)

Thanks, Obama.

If your repo is really big, you need to:
1) make sure your computer will be connected to the network the whole time (if you're trying to do this on a company VPN that will log you off after a certain time period...don't.)
   * make sure your computer won't encounter a windows update that will force shut down
   * consider running it over night OR over the weekend
   * OR use a VM within the network, it can also be kind of computer resource intensive (if this, and you have to do something like ssh in, you might also want to [use screen](https://www.howtogeek.com/662422/how-to-use-linuxs-screen-command/) so that the process isn't killed if your connection gets cut.
1) Although this process **CAN** be used to keep around both the Svn _AND_ Git repos at the same time, I don't recommend this.  It's frustrating to set up, and I guarantee someone will forget to sync and you'll miss stuff.  I strongly recommend you coordinate with your team and choose a time (I do it over weekends) that will be when no one/few people are committing to the repo, clone it into git, and then HARD SWITCH everyone over all in one swell foop.
   * If you rely on a separate build team, keep in mind you are also going to have to get them to change any builds you rely on over, BUT you can have people start using the repo before this is complete.  You just won't be able to get any of their code through any pipelines until the builds are fixed.

## Actual Conversion Process

### Mise en Place

![A gif of Chef Rosanna Pansino rolling up her sleeves; captioned "I'm gonna roll up my sleeves"](https://media.giphy.com/media/OuePMznpbHyrw34608/giphy.gif)

1) Decide on a name for your new git repo.  This may take the most time. ;)
1) Ensure all [branches](http://blog.tatedavies.com/2015/05/14/rename-a-branch-in-svn/) and [tags](https://stackoverflow.com/a/15270466/8679470) have no spaces in their names, this will break the git clone operation.
1) If you have unnecessary large files, delete them from the trunk and commit that.  We'll take care of them later.
   * [this](https://stackoverflow.com/questions/10622179/how-to-find-identify-large-commits-in-git-history) may be helpful
1) As I have done this frequently, I have a folder dedicated to this migration process where I keep the `svn-migration-scripts.jar` and the `bfg.jar` files.
1) You can (probably) skip the "Mount a case-sensitive disk image" section.  I've never had to do this (I was working on Windows at the time)
1) Compile a list of author names so that git can make history shinier
   * instructions for this are in the link below.  You don't have to guarantee the email addresses work or the names are actually fully correct, so don't kill yourself over it if your project has seen many devs.

### Git Svn Clone

![a gif from a Nickelodeon show; a young femme person stands just behind a workbench in what looks like a garage. They hold a flashlight above their head and a duplicate of them appears beside them.](https://media.giphy.com/media/Z8koEOoTT2rgghCzXK/giphy.gif)

Follow the steps [here](https://www.atlassian.com/git/tutorials/migrating-prepare) but **STOP before "Clean the new Git Repository"**

1) Run the `git clone`
   * this may take forever.  One of my repos took 5.5 hrs.  It was big, but it's definitely not the biggest thing I've ever seen...your clone may vary. ;D
   * use `--prefix=''` or the git svn fetch on top later won't be able to be applied with a sync rebase. :(
   * If you were living in a massive, shared SVN repo, it would behoove you to research at what revision number your repo starts, or the git clone will start at revision 0 and search until it finds the first record of your repo.  Some of mine didn't start until the 350K mark and it takes a LONG time for it to get to there.  A bit of [mise en place](https://en.wikipedia.org/wiki/Mise_en_place) will save you a ton of time.
     * Add `-r###:HEAD` to the clone command (where '###' is a revision number).  You don't have to be exact, either.  I just round down to the nearest nice-looking number.
     * An example command looks like: `git svn clone --stdlayout --prefix='' --r 35000:HEAD --authors-file=authors.txt https://svn.atlassian.com/Confluence ConfluenceAsGit`

### Prune massive files

![a gif of a femme of color cutting off a lock of their hair to show solidarity with Iranian women after the killing of Mahsa Amini. Women, life, freedom.](https://media.giphy.com/media/J77HxyT0lez2nvfH20/giphy.gif)

Clean up repo using BFG. This is optional, but recommended, especially if you had big a$$ files.
* Follow [this guide](https://rtyley.github.io/bfg-repo-cleaner/)
* Can delete those giant files you deleted back up at the top, and can also make it run `--strip-biggest-blobs` or `--strip-blogs-bigger-than` to clean up even more.

After doing this it will break the link between git and git svn [see here](https://help.github.com/articles/removing-sensitive-data-from-a-repository/), you have to glue it back together:

1) `git fsck --full`
1) `git prune`
1) `rm -rf .git/svn/refs/remotes/origin/*/.rev_map.*`
1) `rm -rf .git/svn/refs/remotes/origin/tags/*/.rev_map.*`
1) `rm -rf .git/svn/refs/remotes/origin/tags/*/index`
1) `rm .git/svn/refs/remotes/origin/*/index`
1) `rm .git/index`
1) `git svn rebase`

### Cleaning your Repo

![a gif of DW (Dora Winefred) from the kid show "Arthur" sitting at her desk. There's a book and a stuffed rabbit on it.  She pushes both off, onto the floor and the caption reads, "And...clean!"  I feel attacked. ;)](https://media.giphy.com/media/9D6KXW8kgJDxabuQrt/giphy.gif)

Resume with the atlassian steps at "Clean the new Git Repository"

* if you did this when no one was committing, you can skip the `git svn fetch` step, but you should check the commit history in the svn repo just to be sure.
* Stop at "Share" cuz you don't need a bitbucket account.  Probably.

### Make a Git-based Repo

![a gif of a bearded masq person wearing a black beanie and caution orange jacket, carrying a large roll of...roofing paper? Caption: "Keep pushing, baby. Keep pushing."](https://media.giphy.com/media/4Jxt2yVZGJuLYjfuxA/giphy.gif)

I'm going to assume you know how to do this, so make a gitlab/hub project within your group with the name you used when cloning the svn repo. **Do not create it with a readme or git ignore or anything.**  Deal with those later.

1) Resume with the atlassian steps at "Add an origin remote" 
1) Convert any builds you have from SVN to Git.  You'll need the url of your new gitlab/hub repository, and what branch you want your main builds pulling from. (now is a good time to switch branches called `master` to `main`...)
1) Maven/Java-specific: Switch over your pom
   * if you're using maven, the parent pom will need to be changed from `<artifactId>base-pom-pipeline-svn</artifactId>` to `<artifactId>base-pom-pipeline-git</artifactId>`
   * you will also need to change the `<scm>` section from `scm:svn:formerSvnUrl` to `scm:git:newGitlabUrl`
   * I recommend you do a full text search for "svn" to make sure you've found everything
   * check that all in!

### CELEBRATE!!!!!!

![a gif of Taylor Swift standing up to cheer from a box at a sportsball game](https://media.giphy.com/media/ncTvVeWqvnNu4lZQIH/giphy.gif)

If you're doing the "svn at the same time as git" the atlassian steps have steps on how to do that, but I'll say it again: **I do not recommend it.**  It'll just lead to tears.

## Next Steps

1) Figure out your team's [git flow](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow)
1) lock down you main branch(es), set up user permissions on the repos, etc
1) fight over `git rebase` vs `git pull`

![a gif of two armies running towards each other on a grassy plain.  They crash into each other and just form a globby pile. Caption, "Git merge" hehe](https://media.giphy.com/media/cFkiFMDg3iFoI/giphy.gif)
