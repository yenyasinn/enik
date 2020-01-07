---
layout: post
title: "Performance of Views in Drupal 8"
date: 2020-01-06 10:00:00 +0000
categories: Drupal performance
canonical_url: https://www.enik.io/drupal/performance/2020/01/06/views-performance.html
---
Module Views is one of the most popular modules on the Drupal sites. I think it is enabled on all sites built on Drupal. In this article I would like to describe issues with performance of Views that I’ve faced using this module and ways for optimisation.

## Problem of showing big number of entities in views

Distinctive feature of Views in Drupal 8 from Views in Drupal 7 is a fact that Views in Drupal 8 loads entity every time even if only one field has to be shown ([Drupal\views\Plugin\views\cache\CachePluginBase](https://git.drupalcode.org/project/drupal/blob/8.9.x/core/modules/views/src/Plugin/views/cache/CachePluginBase.php#L132)). If you need to show 10 or 100 elements on the page it won’t be a problem. But if you need to show 1000 entities then their load won’t be fast, especially if entity has a lot of fields. Besides long processing you can face with PHP memory limitation. If you use shared hosting then it can be a serious issue due to usually there isn’t possibility to add additional memory there.

Therefore I would recommend to consider to implement custom block where fields will be loaded using sql query to display big number of entities (more than 500) at once. Yes, you need to spend time and implement it independently but only so you can avoid loading of all entities and increase velocity of page processing.

If you use SOLR as a data storage you should read article [Create a search view that doesn’t load entities from the database](https://www.drupal.org/docs/8/modules/search-api-solr/search-api-solr-howtos/create-a-search-view-that-doesnt-load) that describes how to avoid loading of entities in views when SOLR is used.

If such modules as  **[Views selective filters](https://www.drupal.org/project/views_selective_filters)** or **[Selective better exposed filters](https://www.drupal.org/project/selective_better_exposed_filters)** are used on your projects you should know that these modules execute views to build selective filters again.

For example, there are 1000 nodes and it isn’t an issue to show them by 10 items on the page using 100 pages. But if we have added two selective filters then view will be executed  to show 10 entities, then this view will be executed two times to output 1000 nodes to build possible items for selective filters. You can imagine how it affects performance. 

So if there are few hundreds of entities and few selective filters then these modules can be used. But if there are thousands of entities I would recommend to implement views filter plugin where you can prepare data by himself. 

## Increase cache lifetime in Views

Next, I want to note is how Views works with cache. Views caches results by page   ([Drupal\views\Plugin\views\cache\CachePluginBase](https://git.drupalcode.org/project/drupal/blob/8.9.x/core/modules/views/src/Plugin/views/cache/CachePluginBase.php#L104)). Cache with results is marked by special tag like **[ENTITY_TYPE]_list** (for instance, node_list, taxonomy_term_list, media_list). This listing cache tag is invalidated each time when entity is added, updated or removed. It is needed to add new entity to the views results.

There is a performance issue - when any entity is updated, cache of all views that work with this entity type is flushed.

To increase views cache lifetime we can apply patch from  [https://www.drupal.org/project/drupal/issues/2145751](https://www.drupal.org/project/drupal/issues/2145751) (quite possible that it will be in Drupal 9 core), that provides listing tag **[ENTITY_TYPE]_list:[BUNDLE]**. When entity is updated tags **[ENTITY_TYPE]_list** and **[ENTITY_TYPE]_list:[BUNDLE]** will be invalidated.

After it module [Views custom cache tag](https://www.drupal.org/project/views_custom_cache_tag) has to be installed. This module provides ability to set any cache tags. So we can define listing cache tags of entities that are used in the views:

![Set up views custom cache tag](/assets/content/2020-01-06-views-performance/custom_cache_tags.png)

In my example views outputs list of Page nodes and uses filters with taxonomies One, Two, Three. After this modification views cache will be flushed only when Page node or terms in taxonomies One, Two or Three are updated.

## Cache ajax requests in Views

One of the best practice of caching requests for anonymous users is [using reverse proxy](/drupal/performance/2019/10/06/reverse-proxy-caching.html), for instance Varnish. Issue here is that it doesn’t cache POST requests, but such requests are used in ajax requests in Views.

We can use module [Views ajax get](https://www.drupal.org/project/views_ajax_get) to solve this problem. It extends standard Drupal ajax library and changes the type of request from POST to GET for ajax requests in views. You should enable “Use GET requests” in the views settings "Use AJAX" after enabling this module.

![Set up Views ajax get](/assets/content/2020-01-06-views-performance/views_ajax_get_settings.png)

This simple solution helps reduce load on the server significantly and increases the speed of response of ajax request in views if you use reverse proxy for caching on the project.

## Conclusion

Module Views is a powerful and versatile solution. It is designed to solve typical tasks for content output quickly and easily. But if your tasks go beyond typical, problems may begin. Analyse current state of the project, look at the requirements and don't be afraid to implement optimised solutions for your project - module Views provides wide capabilities to extend functionality.
