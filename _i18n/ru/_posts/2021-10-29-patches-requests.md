---
layout: post
title: "Не используйте патчи на основе реквестов из GitHub и GitLab"
date: 2021-10-29 06:00:00 +0000
categories: ru Drupal security
canonical_url: https://www.enik.io/ru/drupal/security/2021/10/29/patches-requests.html
---
После миграции кода Drupal в GitLab, появилась отличная возможность создавать ["мерж" реквесты](https://www.drupal.org/docs/develop/git/using-git-to-contribute-to-drupal/creating-issue-forks-and-merge-requests) для работы над задачами. Это намного более удобно, чем старый способ, когда мы создавали патчи и загружали их на drupal.org в задачу для ревью. Те, кто работал над проектами в GitHub, давно оценили прелесть использования реквестов.

В данное время стандартом считается использование composer для управления модулями сайта. Если нужно внести изменения в код модуля с drupal.org или сторонюю библиотеку, обычно используется патчинг через composer используя cweagans/composer-patches:

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

Реквесты с GitLab и GitHub можно вывести в виде патча, добавив .diff к URL реквеста, например, `https://gitlab.com/weitzman/drupal-test-traits/-/merge_requests/90.diff` или `https://patch-diff.githubusercontent.com/raw/drush-ops/drush/pull/4758.diff`.

Такие адреса можно использовать в composer чтобы патчить модули, но к сожалению, это рискованно.

Основная проблема в том, что **реквесты могут быть изменены в любое время**! Поэтому патч может оказаться сломанным в самый неподходящий момент или включать изменения, которые вы не планировали. Что еще хуже, **в реквест могут быть добавлены изменения, через которые сайт может быть взломан**!

Поэтому нельзя использовать патчи на основе реквестов, особенно на “живых” сайтах. Лучше сгенерируйте патч файл и используйте его. Так безопаснее.
