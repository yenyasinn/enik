---
layout: post
title:  "Сравнение производительности MySQL и MemSQL."
date: 2020-02-29 10:00:00 +0000
categories: ru memsql
canonical_url: https://www.enik.io/ru/memsql/2020/02/29/memsql-mysql-performance-comparison.html
---
Недавно я рассмотрел [базу данных MemSQL](/ru/memsql/2020/02/09/memsql-overview.html), которая может хранить данные как построчно, так и поколоночно. Создатели MemSQL утверждают, что их решение работает супер быстро. Было интересно проверить это и понять насколько быстро работает MemSQL в сравнении с MySQL, и в чем отличие работы колоночной и построчной систем хранения.

## Окружение

Для тестирования я использовал виртуальный сервер с 6 CPU 16 GB RAM с SSD дисками. Операционная система - Ubuntu 18.04. MySQL версия 5.7.29 InnoDB, MemSQL - 7.0. Настройки баз данных использовались по-умолчанию, кроме случаев о которых указано отдельно.

В качестве источника данных были использованы сведения о поездках такси в Нью-Йорке за январь 2016 года. Ссылки на исходные данные можно найти в репозитории [https://github.com/toddwschneider/nyc-taxi-data](https://github.com/toddwschneider/nyc-taxi-data), в котором есть статистика по поездкам такси в Нью-Йорке за несколько лет.  Для удобства использования и идентичности повторяемости замеры выполнялись shell или PHP скриптами ([репозиторий со скриптами](https://github.com/yenyasinn/memsql_test/)). Все измерения приведены в миллисекундах. 

Было интересно проверить разные аспекты работы с базами данных - загрузка, чтение, изменение, удаление данных. Поэтому были написаны разные тесты для тестирования разных вариантов использования.

Для тестирования была создана отдельная база данных в MySQL и две разных базы данных в MemSQL. Одна содержала таблицу для хранения данных построчно (rowstore), другая база данных содержала таблицу для хранения данных поколоночно (columnstore).

**Таблицы для построчных таблиц MySQL и MemSQL:**

```sql
/* Rowstore */
CREATE TABLE yellow_tripdata_staging (
  id int(11) unsigned NOT NULL AUTO_INCREMENT,
  vendor_id tinyint,
  tpep_pickup_datetime datetime,
  tpep_dropoff_datetime datetime,
  passenger_count smallint,
  trip_distance float,
  pickup_longitude double(15,15),
  pickup_latitude double(15,15),
  rate_code_id tinyint,
  store_and_fwd_flag varchar(10),
  dropoff_longitude double(15,15),
  dropoff_latitude double(15,15),
  payment_type tinyint,
  fare_amount float,
  extra float,
  mta_tax float,
  tip_amount float,
  tolls_amount float,
  improvement_surcharge float,
  total_amount float,
  pickup_location_id varchar(255),
  dropoff_location_id varchar(255),
  congestion_surcharge varchar(255),
  junk1 varchar(255),
  junk2 varchar(255),
  PRIMARY KEY (`id`)
  /* INDEX (`rate_code_id`), */
  /* INDEX (`payment_type`) */
);

/* Rate code */
CREATE TABLE rate_code (
  rate_code_id tinyint,
  name varchar(255),
  PRIMARY KEY (`rate_code_id`)
);
INSERT INTO rate_code VALUES (1, 'Standard rate'), (2, 'JFK'), (3, 'Newark'), (4, 'Nassau or Westchester'), (5, 'Negotiated fare'), (6, 'Group ride');

/* Payment type */
CREATE TABLE payment_type (
  payment_type tinyint,
  name varchar(255),
  PRIMARY KEY (`payment_type`)
);
INSERT INTO payment_type VALUES (1, 'Credit card'), (2, 'Cash'), (3, 'No charge'), (4, 'Dispute'), (5, 'Unknown'), (6, 'Voided trip');
```

**Таблицы для поколоночной таблицы MemSQL:**

```sql
/* MemSQL columnstore */

DROP TABLE IF EXISTS yellow_tripdata_staging;

CREATE TABLE yellow_tripdata_staging (
  id int(11) unsigned NOT NULL AUTO_INCREMENT,
  vendor_id tinyint,
  tpep_pickup_datetime datetime,
  tpep_dropoff_datetime datetime,
  passenger_count smallint,
  trip_distance float,
  pickup_longitude double(15,15),
  pickup_latitude double(15,15),
  rate_code_id tinyint,
  store_and_fwd_flag varchar(10),
  dropoff_longitude double(15,15),
  dropoff_latitude double(15,15),
  payment_type tinyint,
  fare_amount float,
  extra float,
  mta_tax float,
  tip_amount float,
  tolls_amount float,
  improvement_surcharge float,
  total_amount float,
  pickup_location_id varchar(255),
  dropoff_location_id varchar(255),
  congestion_surcharge varchar(255),
  junk1 varchar(255),
  junk2 varchar(255),
  KEY (`id`) USING CLUSTERED COLUMNSTORE
);

/* Rate code */
CREATE TABLE rate_code (
  rate_code_id tinyint,
  name varchar(255),
  KEY (`rate_code_id`) USING CLUSTERED COLUMNSTORE
);

INSERT INTO rate_code VALUES (1, 'Standard rate'), (2, 'JFK'), (3, 'Newark'), (4, 'Nassau or Westchester'), (5, 'Negotiated fare'), (6, 'Group ride');

/* Payment type */
CREATE TABLE payment_type (
  payment_type tinyint,
  name varchar(255),
  KEY (`payment_type`) USING CLUSTERED COLUMNSTORE
);

INSERT INTO payment_type VALUES (1, 'Credit card'), (2, 'Cash'), (3, 'No charge'), (4, 'Dispute'), (5, 'Unknown'), (6, 'Voided trip');
```

Основная таблица в которой хранились данные - `yellow_tripdata_staging`. Таблицы `rate_code` и `payment_type` были использованы для хранения вспомогательных данных.

## Загрузка данных из файла.

MemSQL, как и MySQL поддерживают импортирование данных из файлов с помощью команды `LOAD DATA INFILE` . Для теста использовался файл в формате CSV. Размер файла 1.5 GB и содержит 10 906 859 строк. 

<iframe width="100%" height="600px" src="https://docs.google.com/spreadsheets/d/e/2PACX-1vSCMdONS93B-lhyn7aOG9Q3TigjNn55hDdQp4-lkdm5LIGLwnFjGVI-3uHuLzDYeAaY72H400ADNDbq/pubhtml?gid=662724928&amp;single=true&amp;widget=true&amp;headers=false"></iframe>

Результаты теста показывают, что быстрее всего данные импортируются в MemSQL columnstore таблицу.

После импорта columnstore база данных занимает 3.2GB, rowstore база данных - 4.8GB.

## Чтение данных.

Для тестирования чтения данных были составлены разные типы SQL запросов:

<table width="100%">
  <tr>
    <td colspan="2"><strong>Поиск по первичному ключу.</strong></td>
  </tr>
  <tr>
    <td>S1:</td>
    <td>SELECT * FROM yellow_tripdata_staging WHERE id = 50</td>
  </tr>
  <tr>
    <td colspan="2"><strong>Поиск по параметру.</strong></td>
  </tr>
  <tr>
    <td>S2:</td>
    <td>SELECT * FROM yellow_tripdata_staging WHERE payment_type = 2</td>
  </tr>
  <tr>
    <td colspan="2"><strong>Поиск по диапазону.</strong></td>
  </tr>
  <tr>
    <td>S3:</td>
    <td>SELECT * FROM yellow_tripdata_staging WHERE fare_amount >= 10 AND fare_amount <= 20</td>
  </tr>
  <tr>
    <td colspan="2"><strong>Вычисление среднего значения.</strong></td>
  </tr>
  <tr>
    <td>S4:</td>
    <td>SELECT avg(fare_amount) FROM yellow_tripdata_staging WHERE payment_type = 2</td>
  </tr>
  <tr>
    <td colspan="2"><strong>Вычисление количества элементов.</strong></td>
  </tr>
  <tr>
    <td>S5:</td>
    <td>SELECT count(*) FROM yellow_tripdata_staging WHERE payment_type = 2</td>
  </tr>
  <tr>
    <td colspan="2"><strong>Поиск строки.</strong></td>
  </tr>
  <tr>
    <td>S6:</td>
    <td>SELECT * FROM yellow_tripdata_staging WHERE store_and_fwd_flag LIKE 'Y%'</td>
  </tr>
  <tr>
    <td colspan="2"><strong>Использование небольшого интервала.</strong></td>
  </tr>
  <tr>
    <td>S7:</td>
    <td>SELECT payment_type, pickup_longitude, pickup_latitude FROM yellow_tripdata_staging WHERE payment_type > 3 LIMIT 100</td>
  </tr>
  <tr>
    <td colspan="2"><strong>Использование большого интервала.</strong></td>
  </tr>
  <tr>
    <td>S8:</td>
    <td>SELECT payment_type, pickup_longitude, pickup_latitude FROM yellow_tripdata_staging WHERE payment_type > 3 LIMIT 100000</td>
  </tr>
  <tr>
    <td colspan="2"><strong>Использование интервала со смещением. Эмуляция пагинации.</strong></td>
  </tr>
  <tr>
    <td>S9:</td>
    <td>SELECT * FROM yellow_tripdata_staging LIMIT 100 OFFSET 100</td>
  </tr>
  <tr>
    <td colspan="2"><strong>Поиск дат в диапазоне с сортировкой.</strong></td>
  </tr>
  <tr>
    <td>S10:</td>
    <td>SELECT tpep_pickup_datetime, tpep_dropoff_datetime FROM yellow_tripdata_staging WHERE tpep_pickup_datetime >= '2016-01-01 00:00:00' AND tpep_pickup_datetime <= '2016-01-01 01:00:00' ORDER BY tpep_pickup_datetime DESC</td>
  </tr>
  <tr>
    <td colspan="2"><strong>Вычисление количества элементов с группировкой.</strong></td>
  </tr>
  <tr>
    <td>S11:</td>
    <td>SELECT COUNT(tip_amount), payment_type FROM yellow_tripdata_staging GROUP BY payment_type;</td>
  </tr>
  <tr>
    <td colspan="2"><strong>Один inner join.</strong></td>
  </tr>
  <tr>
    <td>S12:</td>
    <td>SELECT pickup_longitude, pickup_latitude, r.name FROM yellow_tripdata_staging as t INNER JOIN rate_code as r ON t.rate_code_id = r.rate_code_id</td>
  </tr>
  <tr>
    <td colspan="2"><strong>Два inner join.</strong></td>
  </tr>
  <tr>
    <td>S13:</td>
    <td>SELECT pickup_longitude, pickup_latitude, r.name, p.name FROM yellow_tripdata_staging as t INNER JOIN rate_code as r ON t.rate_code_id = r.rate_code_id INNER JOIN payment_type as p ON t.payment_type = p.payment_type</td>
  </tr>
</table>

Для rowstore таблиц в MySQL и MemSQL были проведены тесты с одним первичным ключом `id`. Такие тесты помечены как **“MySQL”** и **“MemSQL”**. Также были проведены тесты с индексами на полях `rate_code_id` и `payment_type`. Эти тесты названы **“MySQL (index)”** и **“MemSQL (index)”**. Они используются только в тех тестах, где задействованы поля с индексом. При тестах с индексами, MySQL параметр `innodb_buffer_pool_size` равнялся ~2.5 GB. С настройками по-умолчанию на больших объемах данных результаты были в два раза хуже.

MemSQL columnstore таблица может иметь только один индекс. Поэтому для нее представлен только один вариант.

Тесты проводились на таблице `yellow_tripdata_staging` размером ~11 миллионов, 1 миллион, 50 тысяч  и 1 тысяча строк чтобы проверить зависимость производительности базы данных от размера таблицы.

Каждый тест запускался 3 раза. Тест, показавший меньшее время, считается лучшим. Лучшие тесты из первого запуска выделены зеленым.

Результаты тестов вы можете увидеть ниже:

<iframe width="100%" height="1200px" src="https://docs.google.com/spreadsheets/d/e/2PACX-1vSCMdONS93B-lhyn7aOG9Q3TigjNn55hDdQp4-lkdm5LIGLwnFjGVI-3uHuLzDYeAaY72H400ADNDbq/pubhtml?gid=1689700170&amp;single=true&amp;widget=true&amp;headers=false"></iframe>

Сразу что бросается в глаза это то, что MySQL проигрывает почти во всех тестах с большими объемами данных (больше миллиона строк). Добавление индексов на больших данных в некоторых случаях помогает производительности (тесты S5, S7), но в других случаях запросы выполняются даже медленнее (тесты S11, S12, S13).

В чем MySQL хорош всегда - это поиск по первичному ключу, который работает быстрее всех на любых объемах данных (тест S1). Также MySQL хорошо удается выбирать данные из небольшого интервала (тесты S7 и S9). Но при увеличении интервала производительность MySQL падает катастрофически (тест S8).

При размере таблицы в 50 тысяч строк MySQL уже удается конкурировать с MemSQL. Добавление индексов начинает показывать эффективность. Думаю, что при тонкой настройке параметров MySQL может показать результаты лучше на таком объеме данных и показать значения сопоставимые с MemSQL.

Но что меня удивило больше всего, это то, что при размере таблицы 1000 строк MySQL оказывается быстрее чем MemSQL! С одной стороны разница всего лишь несколько десятков миллисекунд, но если нужно выполнить тысячу запросов, то общее время выполнения запросов может составлять секунды и различие в производительности всего приложения будет видна.

MemSQL лучше работает на больших объемах. И чем больше данных у нас есть, тем более преимущественно выглядит превосходство MemSQL над MySQL. Columnstore таблица хороша для выборки больших объемов данных в определенном диапазоне (тесты S3, S8, S10). У меня не было возможности проверить, но я предполагаю, что чем больше будет объем обрабатываемых данных тем больше будет преимущество columnstore над rowstore. Rowstore быстрее ищет по строкам (тест S6) и быстрее справляется c JOIN.

Использование JOIN в запросах во всех базах данных негативно сказывается на производительности (тесты S12, S13). Поэтому если мы работает с очень большими массивами информации, то будет эффективнее их заранее подготовить и хранить уже обработанные данные, либо же проводить пост-обработку после получения данных, чтобы избежать присоединение таблиц.

## Обновление данных

В тесте на обновление данных было рассмотрено два случая - обновление 10 000 записей последовательно (U1 - `UPDATE yellow_tripdata_staging SET tip_amount = 0, tolls_amount = 0 WHERE id = %d`) и обновление записей в заданном диапазоне (D2 - `UPDATE yellow_tripdata_staging SET tip_amount = 0, tolls_amount = 0 WHERE id >= 1 AND id <= 10000`). Тесты запускались два раза сразу один за одним.

<iframe width="100%" height="520px" src="https://docs.google.com/spreadsheets/d/e/2PACX-1vSCMdONS93B-lhyn7aOG9Q3TigjNn55hDdQp4-lkdm5LIGLwnFjGVI-3uHuLzDYeAaY72H400ADNDbq/pubhtml?gid=1483495826&amp;single=true&amp;widget=true&amp;headers=false"></iframe>

Из результатов мы видим, что MemSQL columnstore справляется с обновлением одиночных записей очень медленно. Это было ожидаемо, т.к. из теории мы знаем что поколоночные таблицы не предназначены для частого обновления.

Обновление диапазона значений также ожидаемо быстрее чем обновление отдельных записей т.к. по-сути выполняется только одна транзакция.

Обновление записей при первом тесте происходит быстрее в MemSQL rowstore. Но, как мы уже видели в тестах на чтение, MySQL хорошо работает с первичным ключом. Поэтому при обновлении строк повторно MySQL работает быстрее.

## Добавление данных

Добавление данных тестировалось два раза. В первом случае было добавлено 10 000 строк одна за одной. В другом случае было выполнено 10 запросов на добавление по 1000 строк в каждом.

<iframe width="100%" height="520px" src="https://docs.google.com/spreadsheets/d/e/2PACX-1vSCMdONS93B-lhyn7aOG9Q3TigjNn55hDdQp4-lkdm5LIGLwnFjGVI-3uHuLzDYeAaY72H400ADNDbq/pubhtml?gid=2086513471&amp;single=true&amp;widget=true&amp;headers=false"></iframe>

Как и ожидалось, данные намного эффективнее добавлять большими группами в любой базе данных. Если же мы данные добавляем построчно, то MemSQL справляется с этим быстрее.

## Удаление данных

В данном тесте было рассмотрено три случая:

* **Тест D1** - удаление 10 000 случайных записей;
* **Тест D2** - удаление 10 000 записей используя диапазон по первичному ключу. 
* **Тест D3** - удаление 10 000 000 записей.

<iframe width="100%" height="650px" src="https://docs.google.com/spreadsheets/d/e/2PACX-1vSCMdONS93B-lhyn7aOG9Q3TigjNn55hDdQp4-lkdm5LIGLwnFjGVI-3uHuLzDYeAaY72H400ADNDbq/pubhtml?gid=1003358391&amp;single=true&amp;widget=true&amp;headers=false"></iframe>

Как мы уже видели по прошлым тестам, эффективнее обновлять и удалять строки большими группами.

MemSQL columnstore оказалась намного медленее при удалении 10 000 записей, но при удалении 10 000 000 записей этот вариант самый быстрый.

В тесте D1 на удалении 10 000 записей лучшую скорость показал MemSQL rowstore. Но, я думаю, что если бы в MySQL первичные ключи были бы проиндексированы, то именно этот вариант победил.

## Заключение
   
Проведя тестирования можем сделать вывод, что разница в производительности MySQL и MemSQL очень зависит от размера таблиц. Для таблиц с несколькими десятками тысяч строк отлично работает MySQL, особенно если используются ключи. Учитывая, что MemSQL довольно требовательна к минимальным ресурсам сервера, то, думаю, использование её на таких объемах данных нецелесообразно.
   
При количестве записей от миллиона строк MemSQL показывает результаты значительно лучшие, чем MySQL. Это и есть сфера применения MemSQL - большие данные. Видимо это и есть причина почему MemSQL бесплатна в использовании на кластере с ограниченными ресурсами - больше сотни гигабайт в rowstore конфигурации вы не сможете использовать (правда, этого может быть более чем достаточно для многих приложений). У меня не было возможности протестировать на таблицах с миллиардами строк, но предполагаю, что на очень больших объемах (сотни гигабайт, терабайты) columnstore будет выигрывать у rowstore в чтении и записи информации, если вам не нужно часто обновлять и удалять данные.
   
**Сферу применения этих баз данных я бы охарактеризовал как:**
   
* Таблицы до нескольких десятков тысяч строк - MySQL
* Таблицы больше миллиона строк с частым обновлением данных - MemSQL rowstore.
* Таблицы больше миллиона строк с редким обновлением данных - MemSQL columnstore.

