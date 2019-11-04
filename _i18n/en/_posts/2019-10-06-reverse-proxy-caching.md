---
layout: post
title:  "High performance caching of Drupal 8 using reverse proxy and CDN"
date:   2019-10-06 10:00:00 +0000
categories: Drupal performance
canonical_url: https://www.enik.io/drupal/performance/2019/10/06/reverse-proxy-caching.html
---
As you may already know - it isn’t necessary to pass all client’s request directly to Drupal. Content can be cached and be returned by proxy servers (for example Varnish) or by CDN servers (CloudFront, CloudFlare etc.). Even Nginx can be configured to return cached requests independently. Such practice allows decrease load on the server in a few times and rise velocity of content delivery.

## Cache expiration

The simplest cache strategy is **cache expiration** - proxy server checks header that it received from Drupal and depending on its parameters decides whether page has to be cached and how long or not. The main header that proxy servers take into consideration is  **Cache-Control** and its parameter **max-age**.

It’s worthwhile to note that not all pages are cached. Usually proxy servers don’t cache POST requests (for example when form has been submitted) and requests containing session cookies (it means that user is authorised). Also different systems can check another parameters in the page header. For instance, Acquia Cloud doesn’t cache requests if parameter **Authorization** exist in the header (it’s required to disable Shield module and http authentication in .htaccess to allow Acquia Cloud’s Varnish cache pages).

Cache clearing in the strategy “cache expiration” occurs when the cache expires. This value is set by parameter max-age in the header Cache-Control for each page. You don’t see content changes until cache won’t be flushed after some time or you won’t flush cache manually.

This cache strategy is easy in configuration and can be used as the initial configuration for the application.

But value of max-age has to be chosen as a compromise between your wish of decreasing the load on the server and provide users actual content. I think that you don’t want to show updated content day later after updating. Therefore, based on the load on the site and frequency of content update, cache lifetime can be from a few minutes to a few hours.

## Cache invalidation

There is also another cache strategy - **cache invalidation**. This option allows use cache longer - days, months or even years. Cache is flushed by request using special key. Example of such key can be URL or tag.

This strategy is more sophisticated in implementation but it has several advantages. Main of them is that cache is cleared when it is definitely needed. Thereby we can decrease the load on the server significantly. But this method requires dealing with cache invalidation very carefully. If we don’t show actual content to the users, it also will be an issue. 

## Drupal 8 configuration in the Cache expiration strategy

We can use both strategies with Drupal 8.

It’s enough to set cache lifetime on the page /admin/config/development/performance in the setting “Browser and proxy cache maximum age” in the “cache expiration” strategy.

## Drupal 8 configuration in the Cache invalidation strategy

You can use standard Drupal 8 cache invalidation by tags, if “cache invalidation” option has been chosen. In the beginning you have to ensure that you invalidate cache tags when content and configuration is updated. If you have changed the site's title so cache has to be cleaned for all pages. If news has been added then news listing page has to be updated also. Or when node is updated we have to check that search shows updated version.

Tags that are used on the page can be found in the page header “X-Drupal-Cache-Tags”.

## Purge module

Next step is installation of module [Purge](https://www.drupal.org/project/purge) and one of its plugin that works with your proxy server.

Purge module architecture is pretty elegant. It consist of main module “purge” and modules-plugins that extends its functionality.

![Purge module architecture](/assets/content/2019-10-06-reverse-proxy-caching/purge_architecture.png "Purge module architecture")

Purge module has four main parts:

* **Queue** - defines storage for the queue. Purge implements queue in database, file system and memory. It’s recommended to use database queue for the typical project. Such option provides necessary compromise between reliability and performance.
* **Queuer** - defines handler that checks what have to cleared and add information about it to the queue. Module **purge_queuer_coretags** is used for flushing cache by tags.
* **Processor** - defines how purger will be started. You can use **purge_processor_cron** - it launches cleaning by cron, or **purge_processor_lateruntime** - cache is cleaned after each request to Drupal when response has been generated but isn’t sent. Also cleaning can be launched by drush command `drush p:queue-work`. Only a limited number of queue items can be processed during each processor run, so you can combine different processors based on your tasks or use them all together simultaneously.
* **Purger** - implements communication with proxy server or CDN. List of supported servers you can find on the module’s page [Purge](https://www.drupal.org/project/purge).

**Purge UI** (purge_ui) provides interface for the Purge, that is convenient for configuration, but it has to be disabled on the production site

Module purge_drush provides useful drush commands for monitoring Purge processes:

```shell
drush p:diagnostics # prints information about Purge configuration.
drush p:queue-browse # prints queue data.
drush p:queue-volume # prints number of items in the queue.
drush p:queue-work # launches cleaning.
```

**Links:**

* [Drupal 8 Acquia Purge & cache tags invalidation](https://support.acquia.com/hc/en-us/articles/360005311513--Drupal-8-Acquia-Purge-cache-tags-invalidation-Public-Beta-Q-A)
* [Cache tags + Varnish](https://www.drupal.org/docs/8/api/cache-api/cache-tags-varnish)
* [Use Drupal 8 Cache Tags with Varnish and Purge](https://www.jeffgeerling.com/blog/2016/use-drupal-8-cache-tags-varnish-and-purge)
* [A Guide to Caching with NGINX and NGINX Plus](https://www.nginx.com/blog/nginx-caching-guide/)
