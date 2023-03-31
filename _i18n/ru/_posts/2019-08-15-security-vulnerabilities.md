---
layout: post
title:  "Типы уязвимостей в безопасности Drupal 8 и способы их устранения."
date:   2019-08-15 18:54:53 +0000
categories: ru Drupal security
canonical_url: https://www.enik.pro/ru/drupal/security/2019/08/15/security-vulnerabilities.html
---
Drupal сайт, как и любая сложная система, может иметь уязвимости в безопасности. Важно знать и уметь устранять их для создания по-настоящему надежных информационных систем. В этой статье я бы хотел рассмотреть наиболее часто встречающиеся уязвимости и способы, как можно предотвратить их.

## Cross site scripting (XSS)

Эта уязвимость заключается в возможности разместить на сайте javascript код, который будет затем выполняться у всех пользователей, которые зайдут на страницу с вредоносным кодом. Используя эту уязвимость злоумышленник может похитить куки с вашей сессией и заполучить доступ к сайту или выполнить от имени пользователя какое-то действие, или просто сломать отображение страницы. 
Как можно определить есть ли у вас такая проблема? Самый простой способ - введите в форму html код (например `<strong>Check</strong>` или `<script>alert(‘!’)</script>`) и посмотрите, как этот код будет отображаться на сайте.
Чтобы пресечь это, нужно обязательно очищать данные от пользователя, которые выводятся на сайте, от возможной вставки javascript кода.

В Drupal для этого есть следующие возможности.

**FormattableMarkup** - используется для вывода форматированного текста.

```php
use Drupal\Component\Render\FormattableMarkup;
$string = new FormattableMarkup('<a href=":variable">link text</a>', [':variable' => $variable]);
```

**Html::escape()** - конвертирует специальные символы в html аналог. Так, например, `&` конвертируется в `&amp;`, `<` конвертируется в `&lt;`, а `>` конвертируется `&gt;`.
 
```php
use Drupal\Component\Utility\Html;
$safe_string = Html::escape($string);
```

**t(), formatPlural()** - используются для вывода переводимых строк.

```php
t(‘My name is - @name’, [‘@name’ => $var]);
\Drupal::translation()->formatPlural($comment_count, '1 comment', '@count comments')]]
```

**UrlHelper::stripDangerousProtocols(), UrlHelper::filterBadProtocol()** - используются когда нужно вывести URL. Удаляет потенциально опасные протоколы (например javascript:) из адреса.

```php
use Drupal\Component\Utility\UrlHelper;

$page['#attached']['html_head_link'][][] = [
 'rel' => 'shortcut icon',
 'href' => UrlHelper::stripDangerousProtocols($favicon),
 'type' => $type,
];
```

**Link::createFromRoute(), Link::fromTextAndUrl()** - используются для вывода ссылок. Текст ссылки и все атрибуты будут очищены от вредоносного кода.

```php
use Drupal\Core\Link;
$link = Link::fromTextAndUrl($text, $url)->toString();
```

**Xss::filter()** - используется, когда нужно вывести html код. Только разрешенные html теги будут выведены. 

```php
use Drupal\Component\Utility\Xss;
$page_text = Xss::filter($raw_content, []);
```

Проблема XSS стоит довольно остро, поэтому очистка текста происходит и в теме. Например, Twig преобразует все специальные символы html при выводе текста через {% raw %}`{{ variable }}`{% endraw %}.
Также при использовании **#markup**, **#plain_text**, **#item_list**, **#inline_template** происходит перекодировка символов.

```php
$markup = "<strong>Content will be processed by \Drupal\Component\Utility\Xss::filterAdmin()</strong>";
$build = ['#markup' => $markup];

$value = "<strong>It will be shown as plain text.</strong>";
$render = ['#plain_text' => $value];

$item_list = [
  '#theme' => 'item_list',
  '#items' => ['one', 'two', 'three'],
];

$build['string'] = [
  '#type' => 'inline_template',
  '#template' => '<span>{{ var }}</span>',
  '#context' => [
    'var' => $possible_unsafe_var,
  ],
];
```

Важно отметить, что если вы используете для вывода объект типа **\Drupal\Component\Render\MarkupInterface**, то такой объект будет выводиться без преобразования. Это удобно если нужно вывести html текст или избежать двойного преобразования специальных символов.

## SQL injection

Уязвимость заключается в возможности модифицировать sql запрос и выполнить вредоносную команду в базе данных. 

Например у нас есть код:

```sql
$sql = “SELECT * FROM users WHERE uid = $_GET[‘uid’];”;
```

Как мы видим данные передаются в sql запрос как есть. Если `$_GET[‘uid’]` будет содержать `“1; TRUNCATE node;”`, то запрос будет выглядеть так: 

```sql
SELECT * FROM users WHERE uid = 1; TRUNCATE node;
```

и вы можете потерять все данные в таблице node.

Если `$_GET[‘uid’]` содержит `“1 or 1 = 1”`, то выполнится sql запрос 

```
SELECT * FROM users WHERE uid = 1 or 1 = 1
```
 
который выведет всех пользователей потому, что 1 = 1 это TRUE.

Как вы видите SQL injection это довольно серьезная уязвимость.
Чтобы предотвратить модифицирование sql запроса всегда используйте уровень абстракции базы данных и не передавайте данные в базу данных напрямую.

```php
use Drupal\Core\Database\Database;
Database::getConnection()->query("SELECT * FROM {users} WHERE uid = :uid", [‘:uid’ => $_GET[‘uid’]]);
```

или

```php
use Drupal\Core\Database\Database;
$result =Database::getConnection()->select('users', 'u')
 ->fields('u')
 ->condition('u.uid', $_GET[‘uid’])
 ->execute();
```

## Cross-site request forgeries (CSRF)

Смысл уязвимости в том, что вредоносный код может быть передан от пользователя, которому приложение доверяет. Причем сам пользователь об этом знать не будет.
Чтобы избежать этого всегда используйте Drupal Form API. Каждая форма будет помечаться специальным токеном и при отправке формы Drupal будет проверять, что такой токен существует и значит форма была отправлена с вашего сайта.

## HTTP Host header spoofing

Drupal использует `$_SERVER[‘HOST’]` для определения адреса сайта. Но эта переменная приходит от пользователя. Таким образом доверять ей нельзя. Например если у нас есть код

```js
<script src="http://<?php echo $_SERVER['HOST'] ?>/script.js">
```

то, отправив запрос с заголовком HOST “hacker.com”, получим в итоге 

```js
<script src="http://hacker.com/script.js">
```

Если эта страница будет сохранена в кеше CDN, то остальные пользователи получат измененную версию страницы и загрузят вредоносный код.
Чтобы это предотвратить, в Drupal можно определить список доменов, которым мы доверяем. Для этого в settings.php нужно определить настройку “trusted_host_patterns”.

```php
$settings['trusted_host_patterns'] = [
   '^example\.com$',
   '^.+\.example\.com$',
   '^example\.org$',
   '^.+\.example\.org$',
 ];
```

Drupal считается одной из самых защищенных систем по управлению контентом. Как вы видите в него встроено множество средств для предотвращения взлома. Главное знать о возможных угрозах и пользоваться возможностями, которые Drupal предлагает для противодействия им.

**Ссылки**
* [Twig autoescape enabled and text sanitization APIs updated](https://www.drupal.org/node/2296163)
* [Handle text in a secure fashion](https://www.drupal.org/node/28984)
* [Create forms in a safe way to avoid cross-site request forgeries (CSRF)](https://www.drupal.org/docs/7/security/writing-secure-code/create-forms-in-a-safe-way-to-avoid-cross-site-request-forgeries)
* [What is a Host Header Attack?](https://www.acunetix.com/blog/articles/automated-detection-of-host-header-attacks/)
