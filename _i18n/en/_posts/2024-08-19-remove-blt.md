---
layout: post
title: "Using Acquia CLI instead of BLT for deployment to Acquia Cloud"
date: 2024-08-19 10:00:00 +0000
categories: Drupal tools
canonical_url: https://www.enik.pro/drupal/tools/2024/08/19/remove-blt.html
---
If you have worked with Acquia Cloud, then you know that Acquia offered [BLT](https://github.com/acquia/blt) as the main tool for website deployment. As time goes on, Acquia has announced that it will no longer support this tool. Therefore, the question arose - how to deploy to Acquia Cloud without using BLT?

To solve this problem we need:
- Remove BLT from the project;
- Send code to Acquia Cloud;
- Perform automated tasks after deploying a project to Acquia Cloud.

## Remove BLT from the project

BLT brings with it a large number of *.settings.php files (found in `vendor/acquia/blt/settings`), which you most likely include in your project's `settings.php` via include `blt.settings.php` .

You can see what settings you need in `vendor/acquia/blt/settings` and assemble your `settings.php` from them. To work with environments on Acquia Cloud, you may need the https://github.com/acquia/drupal-environment-detector package. This method is suitable for advanced programmers who clearly know what and how they want to configure.

Another approach is to install the package with recommended settings https://github.com/acquia/drupal-recommended-settings.

After installing the package

```
composer require acquia/drupal-recommended-settings
```
The code for enabling the recommended settings will appear in your `sites/default/settings.php`:

```
require DRUPAL_ROOT . "/../vendor/acquia/drupal-recommended-settings/settings/acquia-recommended.settings.php";
```

Replace `require DRUPAL_ROOT is located. "/../vendor/acquia/blt/settings/blt.settings.php";` by this code.

In `*.settings.php` project files replace:

```
use Acquia\Blt\Robo\Common\EnvironmentDetector;
```
on
```
use Acquia\Drupal\RecommendedSettings\Helpers\EnvironmentDetector;
```

Now you can remove BLT from the project:
```
composer remove acquia/blt
```

Delete the `blt` folder in the project root.

If you used the `mikemadison13/blt-gitlab-pipelines` package, you can remove it

```
composer remove mikemadison13/blt-gitlab-pipelines
```

Delete the `blt` folder in the project root.

Delete blt.yml files in the `sites/*/` folders.

Replace the files `sites/*/settings/default.includes.settings.php`, `docroot/sites/*/settings/default.local.settings.php` with the corresponding ones from `vendor/acquia/drupal-recommended-settings/settings/site`.

## Configuring automatic execution of tasks after deploying code on Acquia Cloud

Once the code is sent to Acquia Cloud, we will need to complete the tasks of resetting the cache, running updates, importing the configuration.

### Cloud Actions

If you are using **Acquia Cloud Next**, then the best way is to use **Cloud Actions**. You can configure them in the admin panel in the Configuration / Cloud Actions section in the environment settings https://cloud.acquia.com/a/environments/[uuid]/config/cloud-actions. Setting up Cloud Actions is described in https://docs.acquia.com/acquia-cloud-platform/manage-apps/cloud-actions.

If you are using Cloud Actions, then **delete the `hooks` folder** in the project root.

### Cloud Hooks

If the capabilities of Cloud Actions are not sufficient for you, then you can use [Cloud Hooks](https://docs.acquia.com/acquia-cloud-platform/develop-apps/api/cloud-hooks).

In general, place the `drush deploy` code instead of `blt artifact:...` in files in `hooks/common/*`.

Example of the `hooks/common/post-code-deploy/post-code-deploy.sh`:

```
#!/bin/sh

set -ev

site="$1"
target_env="$2"
db_name="$3"
source_env="$4"

repo_root="/var/www/html/$site.$target_env"
export PATH=$repo_root/vendor/bin:$PATH
cd $repo_root

drush deploy

set +v
```

## Sending the code to Acquia Cloud

In order to send the code to Acquia Cloud we will use [Acquia CLI](https://docs.acquia.com/acquia-cloud-platform/add-ons/acquia-cli/acquia-cli)

First we need to install [Acquia CLI](https://docs.acquia.com/acquia-cloud-platform/add-ons/acquia-cli/install):

```shell
curl -OL https://github.com/acquia/cli/releases/latest/download/acli.phar
chmod +x acli.phar
mv acli.phar /usr/local/bin/acl
```

Then we must authorize Acquia CLI by running the command:
```shell
acli auth:login
```

Acquia CLI will ask for **API Key** and **API Secret**, which can be created on the [API Tokens](https://cloud.acquia.com/a/profile/tokens) page in your Acquia Cloud account settings.

Next, Acquia CLI will ask which application on Acqua Cloud we will connect to and create the `.acquia-cli.yml` file. Add it to the repository so you don't have to log in every time.

([More about Acquia CLI authorization](https://docs.acquia.com/acquia-cloud-platform/add-ons/acquia-cli/start))

If you are using **Gitlab CI**, then you need to set the environment variables
**ACLI_KEY** and **ACLI_SECRET** in the CI/CD settings https://gitlab.com/[name]/[repo_name]/-/settings/ci_cd that were created
on the [API Tokens](https://cloud.acquia.com/a/profile/tokens) page.

The next step is to create a folder in which Acquia CLI will build the project:

```
mkdir /tmp/acli-push-artifact
```

If you need to perform any additional operations, for example building a theme, clearing the assembly of unnecessary files, then add the necessary commands to composer.json in the `scripts/post-install-cmd` section:

```
"scripts": {
    "post-install-cmd": [
        "./scripts/frontend-setup.sh",
        "./scripts/frontend-build.sh"
    ]
}
```

Now you need to `git commit` all changes and you can build the project in test mode, in which it will not be sent to Acquia Cloud:

```
acli push:artifact --no-clone
```

This command will copy the code to the `/tmp/acli-push-artifact` folder and run `composer install`.

Open `/tmp/acli-push-artifact` and check that the project was built as expected.

I found a lot of files in my project that I would not like to see on the production server. Previously, they were removed by BLT, but now I need to take care of them myself.

Unfortunately, the `push:artifact` command does not have an option to specify how to clean up. So I wrote a script `clean-up.sh` that removes unnecessary files (don't forget to make *.sh files executable `chmod 755 clean-up.sh`):

```
#!/usr/bin/env bash

set -ev

# Clean the project if only it is built by ACLI.
if [ `pwd` != "/tmp/acli-push-artifact" ] ; then
  exit;
fi

find . -name tests -prune -exec rm -rf {} \;
find . -name .github -prune -exec rm -rf {} \;
find . -name node_modules -prune -exec rm -rf {} \;

find . -name LICENSE.txt -prune -exec rm {} \;
find . -name README.md -prune -exec rm {} \;

find docroot/modules/contrib/ -name .gitignore -prune -exec rm {} \;
find . -name package.json -prune -exec rm {} \;
find . -name package-lock.json -prune -exec rm {} \;
find . -name *.css.map -prune -exec rm {} \;

set +v
```

And added it to composer.json so that the cleanup happens after running `composer install`:

```
"scripts": {
    "post-install-cmd": [
        "./scripts/frontend-setup.sh",
        "./scripts/frontend-build.sh",
        "./scripts/clean-up.sh"
    ]
}
```

To ensure that cleaning only occurs when building a project via ACLI, a condition has been added to the beginning that checks that we are in the "/tmp/acli-push-artifact" folder. This way, the cleaning script will not be called when installing the project locally.

You can run the project build in test mode again. If everything is OK, then we send the project to Acquia Cloud by the application name:

```
acli push:artifact [application name]
```

or send to a specific branch:

```
acli push:artifact --destination-git-branch=[branch]
```

(See `acli push:artifact –help` for advanced settings).

The project will be compiled and sent to the appropriate environment/branch.

Once the code reaches Acuia Cloud, Cloud Actions and Cloud Hooks will be executed.
