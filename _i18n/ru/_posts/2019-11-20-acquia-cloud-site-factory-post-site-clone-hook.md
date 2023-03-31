---
layout: post
title:  "Выполняем код после клонирования сайта в Acquia Cloud Site Factory"
date:   2019-11-20 10:00:00 +0000
categories: ru Drupal ACSF
canonical_url: https://www.enik.pro/ru/drupal/acsf/2019/11/20/acquia-cloud-site-factory-post-site-clone-hook.html
---
Работая над фабрикой сайтов на Drupal 8 на платформе Acquia Cloud Site Factory (ACSF) мы столкнулись с интересной проблемой.

В ACSF есть возможность сделать копию сайта и, таким образом, получить новый сайт с точно таким же содержимым, но с другим URL. Проблема оказалась в том, что склонированный сайт использовал тот же самый SOLR индекс, что и оригинал. В общем-то все логично, ведь мы сделали полную копию сайта, включая конфигурацию SOLR. Решение проблемы заключается в инициализации новых настроек для SOLR после клонирования сайта.

Покопавшись в документации [Hooks in Acquia Cloud Site Factory](https://docs.acquia.com/site-factory/extend/hooks/) мы не обнаружили хуков, которые бы запускались при окончании клонирования.

Решение мы нашли в модуле [acsf_duplication](https://git.drupalcode.org/project/acsf/tree/8.x-2.x/acsf_duplication). В модуле [acsf](https://git.drupalcode.org/project/acsf/tree/8.x-2.x) реализована система событий. ACSF запускает событие `site_duplication_scrub` после завершения клонирования сайта. Пример, как определяются обработчики, можно посмотреть в [acsf_duplication_acsf_registry()](https://git.drupalcode.org/project/acsf/blob/8.x-2.x/acsf_duplication/acsf_duplication.module).

Осталось только реализовать обработчик для этого события в который мы поместили всю необходимую логику. Также мы добавили обновление настроек acquia_connector, чтобы данные с сайта отправлялись в Acquia Insight правильно.

{% gist 3b8c93673840f5e74317d2af577062dd %}

**Ссылки:**
* [Hooks in Acquia Cloud Site Factory](https://docs.acquia.com/site-factory/extend/hooks/);
* [Duplicating a site in Acquia Cloud Site Factory](https://docs.acquia.com/site-factory/manage/website/duplicate/);
* [acsf module](https://git.drupalcode.org/project/acsf/tree/8.x-2.x).
