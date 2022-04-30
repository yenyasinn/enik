---
layout: post
title:  "Antibot vs Honeypot. What spam protector to prefer in Drupal"
date:   2019-12-15 10:00:00 +0000
categories: Drupal modules
canonical_url: https://www.enik.pro/drupal/modules/2019/12/15/antibot-vs-honeypot.html
---
If there are forms for anonymous users on your site then sooner or later you will think about how to protect them against bots. It is tiringly to remove spam comments or irrelevant webform submissions manually.

You can force people to solve tasks provided by [Captcha](https://www.drupal.org/project/captcha) module. It works well but such solution is annoying for constant visitors.

As a free alternative you can install [Antibot](https://www.drupal.org/project/antibot) or  [Honeypot](https://www.drupal.org/project/honeypot) modules. They work absolutely invisibly for users that is better for user experience. At the same time they protect forms and don’t allow robots to send spam. Let’s clarify how they work to make proper choice.

## Antibot

Antibot module works based on assumption that robots don’t support javascript. It contains two methods of protection:

1. Antibot changes **action** form attribute on the path `/antibot`. Original action attribute is saved in attribute **data-action**. If javascript is enabled in user’s browser then value is copied data-action back to action by javascript. Thus bot with disabled javascript will be sent to the page `/antibot`.
2. Antibot adds special hidden field for the key. This key is passed through drupalSettings into javascript. Script sets this key to the special field and form validator checks whether the key exists and the correctness of this key.

You can configure what forms should be protected in the module configuration.

This module protects forms from simple bots. But if bot is built based on browser’s engine and the support of javascript is enabled then such robot will bypass such protection method. 

![Antibot configuration form](/assets/content/2019-12-15-antibot-vs-honeypot/antibot_settings.png)

## Honepot

There are also two protection methods in Honepot as in previous module:

1. It adds empty hidden text field to the form. If field validator find value in this field then it defines this request as invalid.
2. Hidden field with current timestamp is added to the form. Assumption is that people can not fill and send the form faster then some amount of time. If form is submitted faster than specified time limit so such request won’t pass form validation.

The module provides settings to choose what forms have to be protected, to set name of hidden field and time limit that is considered during form submission. Logging of invalid attempts to send spam can be enabled. Also there is an API to extend functionality.

![Honepot configuration form](/assets/content/2019-12-15-antibot-vs-honeypot/honeypot_settings.png)


## Problems of performance

The disadvantages of these modules include the fact that although they solve the problem with spam attacks, they do not help to deal with the load that bots create. We can cache GET requests using reverse proxy and don’t pass requests to Drupal. But by default POST requests that are created using forms are passed to Drupal. When there are lots of robots they create big load on the server.

## Cache Antibot

Antibot is built in the way that all requests are sent to the path `/antibot`. Would be great to cache this URL not to pass request to the application. POST requests contain unique values so we should remove all parameters that are passed to `/antibot` path. Also would be great if GET request was used to use it with standard configuration of reverse proxy.

My team mate, [Maxim Podorov](https://www.drupal.org/u/maximpodorov), has proposed [interesting decision of this issue](https://www.drupal.org/project/antibot/issues/3098088#comment-13378664). Idea is to redirect users to path `/antibot-static` usin GET if javascript is disabled. Page `/antibot-static` will be cached by proxy servers. Web server returns 403 Forbidden error for the robots and blocks these requests.

## What to choose?

As we see both modules provides different methods of protection against bots. It is hard to say which method is more effective. Unfortunately there isn’t one common method to protect forms that work effectively for different types of robots.

In fact you can combine these modules and use them together. Also, for the additional protection, you can enable Captcha module. You can decide what forms and how to defend. For instance, the comment form can be protected by hidden methods that provide Antibot and Honeypot, but login form can be protected also by Captcha. Or vise-versa, or all together based on your site and activity of bots.

**Links:**

* [Antibot module](https://www.drupal.org/project/antibot);
* [Honeypot module](https://www.drupal.org/project/honeypot);
* [Captcha module](https://www.drupal.org/project/captcha);
* [Antibot caching](https://www.drupal.org/project/antibot/issues/3098088#comment-13378664).
