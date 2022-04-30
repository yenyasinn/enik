---
layout: post
title: "Интеграция MemSQL c Drupal."
date: 2020-03-16 10:00:00 +0000
categories: ru Drupal memsql
canonical_url: https://www.enik.pro/ru/drupal/memsql/2020/03/16/memsql-drupal-integration.html
---
Если вы еще не знаете, что из себя представляет СУБД MemSQL, то можете ознакомиться в статье по [обзору MemSQL](/ru/memsql/2020/02/09/memsql-overview.html). В чем различие в производительности MemSQL и MySQL вы можете прочитать в статье [“Cравнение производительности MySQL и MemSQL”](/ru/memsql/2020/02/29/memsql-mysql-performance-comparison.html). В этой статье я опишу как интегрировать MemSQL с Drupal.

## Установка MemSQL

Для начала, нужно установить MemSQL на ваш сервер. Можно установить базу данных из пакетов на Linux или использовать Docker (в этом случае можно будет использовать MemSQL и на Windows). Перед установкой удостоверьтесь, что вы предоставляете минимально требуемые ресурсы - 4 ядра CPU и 8 ГБ ОЗУ. Если вы используете Vagrant, то в config.yml нужно добавить 

```yml
vagrant_memory: 8192
vagrant_cpus: 4
```

Шаги по установке MemSQL с подробным описанием вы можете найти на официальном сайте [https://docs.memsql.com/v7.0/guides/deploy-memsql/memsql-tools/deploy-cluster/step-1/](https://docs.memsql.com/v7.0/guides/deploy-memsql/memsql-tools/deploy-cluster/step-1/).

В случае, когда вам нужно иметь одновременно MySQL и MemSQL на сервере, я рекомендую поменять порт MySQL на, например, 3308. Для этого установите это значение в параметре `port` в файле mysqld.cnf. MemSQL будет использовать порты 3306 и 3307 при установке по шагам из ссылки выше. MemSQL может работать на любых портах, но в таком случае кластер придется настраивать вручную, что потребует больше времени на изучение и установку. 

## Настройка PHP

MemSQL совместима с клиентским программным обеспечением для MySQL. Она представляется MySQL версией 5.5.8. Это значит, что вы можете подключиться к ней используя Sequel Pro, PHP MySQLi и  PHP PDO_MySQL драйвер и клиент будет считать, что работает с MySQL. Т.е. вы можете использовать все те инструменты к которым привыкли.

Если PHP PDO_MySQL драйвер не установлен, то установите его. Например, команда для Debian или Ubuntu для установки драйвера для PHP 7.3
 `apt-get install php7.3-mysql` 

## Установка драйвера MemSQL в Drupal.

Чтобы работать с MemSQL в Drupal нужно установить драйвер базы данных. Для этого используйте Drupal модуль [MemSQL](https://www.drupal.org/project/memsql).

Установка происходит как обычно - `composer require drupal/memsql`. 

Рекомендуется использовать composer для инсталляции. В этом случае поддержка Drush подключится сразу.

После того, как модуль установился, необходимо скопировать папку **memsql/drivers** в **[docroot]/drivers** - основная папка, где находится ваш сайт, там, где index.php. Drupal использует это путь для поиска дополнительных драйверов. 

![Путь до драйвера MemSQL в Drupal](/assets/content/2020-03-16-memsql-drupal-integration/drupal_driver_folder_structure.png){:width="300px"}

Чтобы не пришлось обновлять драйвер каждый раз вручную, можно добавить в composer.json скрипт для обновления папки с драйвером каждый раз после обновления модулей:

```yml
"post-update-cmd": [
    "cp -r web/modules/contrib/memsql/drivers web/"
]
```
В данном примере `web` это название docroot папки. У вас она может отличаться.

Если все сделано правильно, то в процессе установки Drupal на шаге “Set up database”  в поле “Database type” появится опция “MemSQL”. Выберите её и введите название базы данных, логин и пароль.

![Database configuration](/assets/content/2020-03-16-memsql-drupal-integration/drupal_install_db_type.png)

Если вы устанавливаете сайт из консоли, то добавьте настройки базы в settings.php:

```php
$databases['default']['default'] = array (
  'database' => 'drupal',
  'username' => 'root',
  'password' => '',
  'prefix' => '',
  'host' => '127.0.0.1',
  'port' => '3306',
  'namespace' => 'Drupal\\Driver\\Database\\memsql',
  'driver' => 'memsql',
);
```

## Различия реализации драйвера MemSQL и MySQL.

Драйвер базы данных MemSQL расширяет драйвер MySQL, который реализован в ядре Drupal. Хоть и MemSQL похожа на MySQL, но в реализации есть небольшие отличия:

* **SHARD KEY**.  MemSQL использует `SHARD KEY` для указания колонок, которые используются для вычисления хэша. Данные сохраняются на leaf согласно этому хэшу. Shard key должен включать в себя `PRIMARY KEY` и задается в `CREATE TABLE` sql запросе. Если `SHARD KEY` не указан, то для вычисления хеша  используется `PRIMARY KEY`.
* **UNIQUE index**. MemSQL требует чтобы колонки из `UNIQUE` индекса были частью `SHARD KEY`.
* **Сортировка по-умолчанию**. MySQL по-умолчанию отдает данные отсортированные по `PRIMARY KEY`. SQL стандарт не гарантирует такое поведение. MemSQL возвращает данные согласно своей логике, если `ORDER BY` не указан. Поэтому если вам нужно получить данные в отсортированном виде в MemSQL всегда используйте `ORDER BY`.
* MemSQL не поддерживает **сортировку в UNION запросах**. Подробнее тут - [сортировка в UNION запросе](https://www.drupal.org/project/memsql/issues/3112865).
