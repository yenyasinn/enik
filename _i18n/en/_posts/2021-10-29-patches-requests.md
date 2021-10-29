---
layout: post
title: "Never use patches based on merge/pull requests"
date: 2021-10-29 06:00:00 +0000
categories: Drupal security
canonical_url: https://www.enik.io/drupal/security/2021/10/29/patches-requests.html
---
There is a great feature that can be used after Drupal code migration into GitLab infrastructure - [merge requests](https://www.drupal.org/docs/develop/git/using-git-to-contribute-to-drupal/creating-issue-forks-and-merge-requests). It is more convenient than the old method when patches had to be created and uploaded on drupal.org to the task for a review. Everyone who already worked on GitHub with pull requests evaluated this approach.

Currently it’s a standard to use composer to manage site modules. If it’s required to add some changes to the module from drupal.org or external library we, usually, use composer to patch them using  cweagans/composer-patches plugin:

```yaml
{
  "require": {
    "cweagans/composer-patches": "~1.0",
    "drupal/core-recommended": "^9",
  },
  "extra": {
    "patches": {
      "drupal/core": {
        "Add startup configuration for PHP server": "https://www.drupal.org/files/issues/add_a_startup-1543858-30.patch"
      }
    }
  }
}
```
Pull/merge requests form GitHub/GitLab can be rendered as patches by adding .diif to the end of requests, like `https://gitlab.com/weitzman/drupal-test-traits/-/merge_requests/90.diff` or `https://patch-diff.githubusercontent.com/raw/drush-ops/drush/pull/4758.diff`.

Such addresses can be used in composer for patching, but, unfortunately, it’s risky.

**The main issue is that requests can be changed at any time!** Therefore the patch from the request can be broken at the most inappropriate moment or include changes you don’t expect. Even worse, **the patch can include an exploit that will make your site vulnerable**.

Thus, do not use patches based on pull/merge requests, especially on the “live” sites. Generate a patch file and use it. It’s safer.
