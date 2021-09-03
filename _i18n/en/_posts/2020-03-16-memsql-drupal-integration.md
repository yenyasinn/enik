---
layout: post
title: "Integration MemSQL and Drupal."
date: 2020-03-16 10:00:00 +0000
categories: Drupal memsql
canonical_url: https://www.enik.io/drupal/memsql/2020/03/16/memsql-drupal-integration.html
---
If you don’t know what DBMS MemSQL is you can read the article with [MemSQL overview](/memsql/2020/02/09/memsql-overview.html). Difference in performance with MySQL and for what applications MemSQL is suitable is described in the [“MySQL and MemSQL performance comparison.”](/memsql/2020/02/29/memsql-mysql-performance-comparison.html). In this article I describe how to integrate MemSQL with Drupal.

## MemSQL installation

First of all, you have to install MemSQL on the server. MemSQL can be installed from the packages on Linux or Docker container can be used (in this case MemSQL will be available on Windows). You should ensure that the server satisfies minimal resource requirements for MemSQL - 4 vCPU and 8 GB RAM. If you install MemSQL on the virtual machine and Vagrant is used, then need to add to the config.yml:

```yml
vagrant_memory: 8192
vagrant_cpus: 4
```

All required steps for MemSQL installation with detailed description you can find on the official site [https://docs.memsql.com/v7.0/guides/deploy-memsql/memsql-tools/deploy-cluster/step-1/](https://docs.memsql.com/v7.0/guides/deploy-memsql/memsql-tools/deploy-cluster/step-1/).

In case you need MySQL and MemSQL on the same server, I would recommend to change MySQL port and to set it, for example, 3308. You should set such value in the `port` configuration in the **mysqld.cnf** file. MemSQL uses ports 3306 (for aggregator) and 3307 (for leaves) if you install it as described in the installation guide. MemSQL can work on any ports but such configuration requires manual setup that is longer and complex for newcomers.

## PHP configuration

MemSQL is compatible with MySQL’s client softwares. MemSQL says to the clients that it is MySQL version 5.5.8. It means that you can connect to MemSQL using any MySQL clients: Sequel Pro, PHP MySQLi, PHP PDO_MySQL etc. So you can use the same tools and libraries that you know well in the familiar LAMP stack.

You should install PHP PDO_MySQL driver if it is absent on the server. Command for Debian or Ubuntu that installs database driver for PHP 7.3:

`apt-get install php7.3-mysql`

## MemSQL driver installation on Drupal.

MemSQL database driver has to be installed to work with this database in Drupal. Use the Drupal module [MemSQL](https://www.drupal.org/project/memsql) for it.

Install module as usual -  `composer require drupal/memsql`.

I recommend to use composer for installation. In this case Drush support will be enabled automatically.

After module installation please copy folder **memsql/drivers** to **[docroot]/drivers** - main folder of the site where index.php is placed. This path is used by Drupal to find custom database drivers.

![Path with MemSQL driver in Drupal](/assets/content/2020-03-16-memsql-drupal-integration/drupal_driver_folder_structure.png){:width="300px"}

If you want to avoid updating driver manually each time after update, you can add a script to the composer.json file to copy driver each time when modules are updated:

```yml
"post-update-cmd": [
   "cp -r web/modules/contrib/memsql/drivers web/"
]
```
In this example `web` it is name of the docroot folder. It can be different on your system.

If everything has been done correctly you will see option “MemSQL” on the step “Set up database” in the field “Database type”. Choose it and enter database credentials.

![Database configuration](/assets/content/2020-03-16-memsql-drupal-integration/drupal_install_db_type.png)

If you install Drupal from the console then add database settings to the settings.php:

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

## Differences in MemSQL and MySQL drivers implementation.

MemSQL driver extends Drupal core MySQL driver. Though MemSQL is compatible with MySQL there are little differences:

* **SHARD KEY**.  MemSQL uses `SHARD KEY` to set columns that are used for hash calculation. This hash is used to define on what leaf row has to be saved. Shard key has to include `PRIMARY KEY` and is defined in `CREATE TABLE` sql query. If `SHARD KEY` isn’t set then `PRIMARY KEY` is used for hash calculation.
* **UNIQUE index**. MemSQL requires columns from the `UNIQUE` index have to be a part of  `SHARD KEY`.
* **Default sorting**. MySQL returns data sorted by `PRIMARY KEY` by default. SQL standard doesn’t guarantee such behaviour. MemSQL returns data unordered if `ORDER BY` isn’t set. Therefore if you need to get sorted data you have to use `ORDER BY`.
* MemSQL doesn’t support **sorting in UNION requests**. More details here - [sorting in UNION request](https://www.drupal.org/project/memsql/issues/3112865).
