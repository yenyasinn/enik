---
layout: post
title:  "Acquia Cloud Site Factory post site clone hook"
date:   2019-11-20 10:00:00 +0000
categories: Drupal ACSF
canonical_url: https://www.enik.pro/drupal/acsf/2019/11/20/acquia-cloud-site-factory-post-site-clone-hook.html
---
We have faced with interesting issue during our work on the site factory on the Drupal 8 based on Acquia Cloud Site Factory (ACSF) platform.

There is a feature in ACSF that allows you to duplicate existing site and create a new one with the same content but with another URL. Issue was that cloned site has used the same SOLR index as the ancestor. Actually it is logical because as we had made full copy of the site, including configurations. This issue could be resolved by re-initializing SOLR settings for after site cloning. 

We have not found any hooks that are invoked after site duplication in the documentation [Hooks in Acquia Cloud Site Factory](https://docs.acquia.com/site-factory/extend/hooks/). 

Solution has been found in the module [acsf_duplication](https://git.drupalcode.org/project/acsf/tree/8.x-2.x/acsf_duplication). There is event system that is implemented in the [acsf](https://git.drupalcode.org/project/acsf/tree/8.x-2.x) module. ACSF launches event `site_duplication_scrub` when site is duplicated. Example of events definition can be found in [acsf_duplication_acsf_registry()](https://git.drupalcode.org/project/acsf/blob/8.x-2.x/acsf_duplication/acsf_duplication.module).

After this finding we have implemented handler of this event that updates SOLR configuration. Also updating of acquia_connector settings have been added to push data to Acquia Insight correctly.

{% gist 3b8c93673840f5e74317d2af577062dd %}

**Links:**
* [Hooks in Acquia Cloud Site Factory](https://docs.acquia.com/site-factory/extend/hooks/);
* [Duplicating a site in Acquia Cloud Site Factory](https://docs.acquia.com/site-factory/manage/website/duplicate/);
* [acsf module](https://git.drupalcode.org/project/acsf/tree/8.x-2.x).
