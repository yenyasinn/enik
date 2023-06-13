---
layout: post
title: "About cache in Drupal 10"
date: 2023-06-12 10:00:00 +0000
categories: Drupal performance
canonical_url: https://www.enik.pro/drupal/performance/2023/06/12/drupal-cache.html
---
Drupal provides wide and convenient options for posting content on the site. Unfortunately, this comes at the cost of performance degradation. We don't really need to render the content on every request - we can store it in the cache and retrieve it when needed.

Drupal begins rendering the page first, then the layout, then the blocks, and finishes with the contents of the blocks. Each content part has certain cache settings - max age, cache tags and cache context ([Cache API basics](https://www.drupal.org/docs/8/api/cache-api/cache-api)). Drupal collects the cache parameters of each element, and you can see the general parameters for the response in the page header if you enable the `http.response.debug_cacheability_headers` parameter in services.yml.

```
parameters:
  http.response.debug_cacheability_headers: true
```
![Cache parameters in the response header](/assets/content/2023-06-12-drupal-cache/cache_headers.png)

If you need to find blocks with certain cache parameters on the page, then you can use the [Renderviz](https://www.drupal.org/project/renderviz) module.

By default, Drupal caches content blocks. But you can also cache the entire response. Drupal 10 has two modules for this - Internal page cache and Internal Dynamic Page Cache.

## Internal Page Cache module.
This module caches requests from anonymous users. All anonymous users will see the same response/page. If you need to show some personal information on the page to an anonymous user, then you need to either disable the module or use an ajax request to get the desired block.

A user is considered anonymous if he does not have an open session. If the user has cookies like `SSESS5a5813d2457b0cadd870939bdf9bbfd0`, then the user session is open and requests will not be cached by the Internal page cache module.

Also note that only `GET` and `HEAD` requests are cached (see `\Symfony\Component\HttpFoundation\Request::isMethodCacheable`). By default, Drupal uses the `POST` method for ajax requests, so if you want to cache ajax requests, you should use the `GET` method for them.

Also, requests that were initiated from the command line, for example through drush, are not cached.

If the page was served from the cache, then the response header will contain the entry `X-Drupal-Cache: HIT`.

The internal page cache sets the cache expiration only if such an expiration was set for the response - `$response->setExpires(\DateTimeInterface $date)`. Block max age values are ignored ([but this may change in Drupal 11](https://www.drupal.org/project/drupal/issues/2352009)). The cache will be retained until either one of the cache tags is invalidated or the page cache is cleared.

## Internal Dynamic Page Cache module
This module will be useful if the page contains dynamic (personalised) content. By default, content is considered dynamic if it has a `session` or `user` context, or the max age is 0. This is defined in `core.services.yml` and, if necessary, the settings can be changed (for example, specify certain tags):
```yaml
renderer.config:
  auto_placeholder_conditions:
  max age: 0
  contexts: ['session', 'user']
  tags: []
```
If the content is dynamic and a `#lazy_builder` handler is defined for it (for blocks it is defined by default in `\Drupal\block\BlockViewBuilder`), then when the page is rendered, such a block will be replaced by a placeholder string. The page with placeholders will be cached. When requested, the page will be taken from the cache, and instead of placeholders, generated blocks for a specific user will be substituted.

![Example of the block that won’t be cached](/assets/content/2023-06-12-drupal-cache/page_rendering.png)

When using the `user` context, be aware that all anonymous users are the same user. If you need to show different content to anonymous users, then it is better to use the `session` context.

To determine if the Dynamic Page Cache was used, you need to look in the response header - there should be an entry `X-Drupal-Dynamic-Cache: HIT` if the page was taken from the cache.

## About setting “Browser and proxy cache maximum age”

It is important to know that the “Browser and proxy cache maximum age” setting on the `/admin/config/development/performance` page is used to set the Cache-Control parameter in the page header that is only read by the browser or [reverse proxy systems](/drupal/performance/2019/10/06/reverse-proxy-caching.html) (e.g. Varnish).

Below is the code from `\Drupal\Core\EventSubscriber\FinishResponseSubscriber::setResponseCacheable()` where this is used:

```php
   $max_age = $this->config->get('cache.page.max_age');
   $response->headers->set('Cache-Control', 'public, max-age=' . $max_age);
```

This setting does not affect the behavior of the Internal page cache and Internal Dynamic Page Cache.
