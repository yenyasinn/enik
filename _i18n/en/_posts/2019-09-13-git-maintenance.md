---
layout: post
title:  "Git repository maintenance"
date:   2019-09-13 10:00:00 +0000
categories: tools
canonical_url: https://www.enik.io/tools/2019/09/13/git-maintenance.html
---
GIT repository size is increased during project lifetime due to it stores all files modifications.
At some moment we realise that repository weights too much and it’s complicated to work with it. In this case it is proper time for GIT repository maintenance.

## Repository preparation

For the beginning let’s download repository:

```shell
git clone --mirror git@hosting.com:path/project.git
```

We have just created a mirror of the repository. It contains repository files - everything that is stored in the .git folder, without project files.

## Create an archive copy of the repository

First of all we should create a backup of our repository, that we could restore, if something will go wrong:

```shell
tar czf achive_name.tgz project.git
```

## Clean up repository from big files

Sometimes big files are put to the repository. Usually it happens by mistake but information about changes in these files are already in repository and will be stored there till we won’t remove it.

[BFG Repo-Cleaner](https://rtyley.github.io/bfg-repo-cleaner/) can help us in removing big files.

Please download jar file from the site. Rename it to bfg.jar and move this file to the folder where your repository project.git is already situated.

Run removing files bigger 50 megabytes:

```shell
java -jar bfg.jar --strip-blobs-bigger-than 50M project.git
```

> *There can be error on the MacOSX*

> ```
Looks like your version of Java (1.6) is too old to run this program.
```

> *It is due to shell uses the system version of Java. You should download last version of [Oracle Java](https://www.java.com/en/download/mac_download.jsp). If you have already downloaded Oracle Java, then you should update it to the latest version through System Preference -> Java.*

> *Oracle Java is installed in `/Library/Internet\ Plug-Ins/JavaAppletPlugin.plugin/Contents/Home/bin/java`*

> *Then need to create an alias for this version of Java in shell:*

> ```shell
echo alias java_jre='/Library/Internet\ Plug-Ins/JavaAppletPlugin.plugin/Contents/Home/bin/java' >> ~/.profile
```

> *Let’s execute BFG once again:*

> ```shell
java_jre -jar bfg.jar --strip-blobs-bigger-than 50M project.git
```

> *Use `java_jre` instead of `java` further.*

Also BFG allows to remove files by extension:

```shell
java -jar bfg.jar --delete-files *.mp4 project.git
```

by name:

```shell
java -jar bfg.jar --delete-files id_{dsa,rsa} project.git
```

or even remove whole folder:

```shell
java -jar --delete-folders folder_name --delete-files folder_name  --no-blob-protection  project.git
```

## Remove unnecessary data from repository

On this step we should remove unnecessary data from repository

Remove logs:
```shell
git reflog expire --expire=now --all
```

Launch garbage collector that removes needless files and optimizes repository:

```shell
git gc --prune=now --aggressive
```

## Finishing process
We have to push changes back after repository maintenance is done:

```shell
git push
```

All team members should clone updated repository again to prevent pushing back old commits from local version of repository by mistake.

## Best practices of using GIT.

You should follow few rules using GIT repository if you wish to maintain it rare and keep it in adequate size.

* If possible, you should not store there archives, media files, logs, database dumps, data for migrations and another big files.
* If you use package manager, for example composer, npm or bower then only file with packages description have to be stored in repository. Don’t add installed packages to the repository.
* When you work on some feature you can combine few commits into one using **git rebase** or **git merge --squash**.
