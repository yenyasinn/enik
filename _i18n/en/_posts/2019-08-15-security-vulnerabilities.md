---
layout: post
title:  "Drupal 8 security vulnerabilities and ways to fix them."
date:   2019-08-15 18:54:53 +0000
categories: en Drupal security
canonical_url: https://www.enik.io/drupal/security/2019/08/15/security-vulnerabilities.html
---
Drupal site, as every complicated system, can have security vulnerabilities. It is important to know about them and be able to fix them to build secure information systems. I want to review in this article most frequent vulnerabilities and ways to prevent them.

## Cross site scripting (XSS)

This vulnerability lies in the possibility of adding javascript on the site, which will be executed for all users who would visit a page with this code. Intruder can steal cookies with your session and acquire access to the site or perform some action on behalf of user, or just break site view using this vulnerability.
How can we recognise whether we have this issue? The simplest method is to add to the form html code (for example  `<strong>Check</strong>` or `<script>alert(‘!’)</script>`) and check how this code is shown on the site.
You have to clean the user's data that are shown on the site from possible included javascript code to prevent it.
Drupal has different ways for it:

**FormattableMarkup** - is used to print formatted text.

```php
use Drupal\Component\Render\FormattableMarkup;
$string = new FormattableMarkup('<a href=":variable">link text</a>', [':variable' => $variable]);
```

**Html::escape()** - converts special characters to html analogs. For instance `&` is converted to `&amp;`, `<` is converted to `&lt;`, and `>` is converted to `&gt;`.

```php
use Drupal\Component\Utility\Html;
$safe_string = Html::escape($string);
```

**t(), formatPlural()** - is used to print translated strings.

```php
t(‘My name is - @name’, [‘@name’ => $var]);
\Drupal::translation()->formatPlural($comment_count, '1 comment', '@count comments')]]
```

**UrlHelper::stripDangerousProtocols(), UrlHelper::filterBadProtocol()** - is used when URL is printed. It removes potential dangerous protocols (as “javascript:”) from the address. 

```php
use Drupal\Component\Utility\UrlHelper;

$page['#attached']['html_head_link'][][] = [
'rel' => 'shortcut icon',
'href' => UrlHelper::stripDangerousProtocols($favicon),
'type' => $type,
];
```

**Link::createFromRoute(), Link::fromTextAndUrl()** - is used to print links. Text of link and all attributes will be cleaned from malicious code.

```php
use Drupal\Core\Link;
$link = Link::fromTextAndUrl($text, $url)->toString();
```

**Xss::filter()** - it can be used when html code has to be printed. Allowed html tags are printed only.

```php
use Drupal\Component\Utility\Xss;
$page_text = Xss::filter($raw_content, []);
```

Issue of XSS is quite important, therefore text clean up is made in a theme also. For instance, Twig escapes all special characters when text is printed as {% raw %}`{{ variable }}`{% endraw %}.
Also text is escaped when **#markup**, **#plain_text**, **#item_list**, **#inline_template** are used.

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
It’s important to note that if you use object of type **\Drupal\Component\Render\MarkupInterface**, then this object will be printed without escaping. It can be used if you would like to print html code or avoid double escaping.

## SQL injection

This vulnerability lies in the possibility of modifying sql query and execute malicious commands in the database.

For example there is a code:

```sql
$sql = “SELECT * FROM users WHERE uid = $_GET[‘uid’];”;
```

As we see data is passed to sql as is. If `$_GET[‘uid’]` would contain “1; TRUNCATE node;”`, then query will be:

```sql
SELECT * FROM users WHERE uid = 1; TRUNCATE node;
```

and you can lose all data in the node table.

If `$_GET[‘uid’]` would contain “1 or 1 = 1”`, then sql query will be executed

```
SELECT * FROM users WHERE uid = 1 or 1 = 1
```

that prints all users due to 1 = 1 is TRUE.

As you can see, SQL injection is a significant vulnerability.
You have to use database abstraction layer to prevent sql query modification. Also you mustn’t pass data to database directly.

Examples of correct usage:

```php
use Drupal\Core\Database\Database;
Database::getConnection()->query("SELECT * FROM {users} WHERE uid = :uid", [‘:uid’ => $_GET[‘uid’]]);
```

or

```php
use Drupal\Core\Database\Database;
$result =Database::getConnection()->select('users', 'u')
->fields('u')
->condition('u.uid', $_GET[‘uid’])
->execute();
```

## Cross-site request forgeries (CSRF)

Meaning of this vulnerability is in ability of passing malicious code from user to the application that trust this user. Moreover user won’t know about it because malicious javascript code can send request when you visit attacker site.
You have to use Drupal Form API to prevent it. Each form will be marked by special token that is checked during form submit. If token exists then the system knows that it is a valid request.

## HTTP Host header spoofing

Drupal uses `$_SERVER[‘HOST’]` to determine the address of the site. But we can’t trust this variable because it can be changed by user. For example there is code:

```js
<script src="http://<?php echo $_SERVER['HOST'] ?>/script.js">
```

if someone sends a request with the header HOST “hacker.com” site will receive

```js
<script src="http://hacker.com/script.js">
```

If this page is saved in the CDN cache, then rest users will receive changed version of the page and load malicious code.
There is a list of trusted hosts in Drupal to prevent it. You can find setting  “trusted_host_patterns” in settings.php file 

```php
$settings['trusted_host_patterns'] = [
  '^example\.com$',
  '^.+\.example\.com$',
  '^example\.org$',
  '^.+\.example\.org$',
];
```

Drupal is known as one of the most secure systems of content management. As you can see there are lots of tools to prevent hack. It’s important to know about possible vulnerabilities and use them in site building.

**Links**
* [Twig autoescape enabled and text sanitization APIs updated](https://www.drupal.org/node/2296163)
* [Handle text in a secure fashion](https://www.drupal.org/node/28984)
* [Create forms in a safe way to avoid cross-site request forgeries (CSRF)](https://www.drupal.org/docs/7/security/writing-secure-code/create-forms-in-a-safe-way-to-avoid-cross-site-request-forgeries)
* [What is a Host Header Attack?](https://www.acunetix.com/blog/articles/automated-detection-of-host-header-attacks/)
