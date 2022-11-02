---
layout: post
title: "Особенности использования контейнера сервисов в тестах в Drupal 9"
date: 2022-10-02 10:00:00 +0000
categories: ru Drupal tests
canonical_url: https://www.enik.pro/ru/drupal/tests/2022/10/02/service-containers.html
---
Обращали ли вы внимание что в Kernel и Functional тестах сервисы вызываются через `$this->container->get()` или через `\Drupal::service()`? Казалось бы, что какая разница - мы так и так получаем сервис и тест работает, но есть нюансы. Давайте разберемся.

## Kernel тесты

В Kernel тестах контейнер сервисов доступен через внутреннюю переменную `$this->container` и класс `\Drupal`.

Класс `\Drupal` (находится в core/lib/Drupal.php) - оболочка статичного контейнера сервисов (Static Service Container wrapper). Он был создан, для того, чтобы была возможность достать сервисы из контейнера сервисов в процедурном коде, например в хуках. Если в классах мы можем (и должны) использовать внедрение зависимостей, то в процедурном коде по-другому не получится.

Соответственно для загрузки сервисов мы можем использовать `$this->container->get()` и `\Drupal::service()`. Использование `\Drupal` в тестах считается антипатерном потому, что он создавался для использования в процедурном коде, а не в ООП. 

**Соответственно, в Kernel тестах предпочтительнее вызывать сервисы через $this->container->get().**

## Functional тесты

### Пример 1

Давайте рассмотрим примеры функциональных тестов, где используются контейнеры сервисов `$this->container` и `\Drupal`, в которых нам нужно включить и использовать модуль `book` внутри теста:

```php
namespace Drupal\Tests\example\Functional;

use Drupal\Tests\BrowserTestBase;

class ContainerFunctionalTest extends BrowserTestBase {

  /**
   * Test is failed since 'book.manager' doesn't exist in $this->container service container.
   */
  public function testContainerFail() {
    $this->container->get('module_installer')->install(['book']);
    // Error is shown "Symfony\Component\DependencyInjection\Exception\ServiceNotFoundException: You have requested a non-existent service "book.manager"."
    $all_books = $this->container->get('book.manager')->getAllBooks();
    $this->assertEmpty($all_books);
  }

  /**
   * Test is passed since 'book.manager' exists in \Drupal::service() service container.
   */
  public function testDrupalPass() {
    \Drupal::service('module_installer')->install(['book']);
    $all_books = \Drupal::service('book.manager')->getAllBooks();
    $this->assertEmpty($all_books);
  }
```
Тест `testContainerFail()`, который использует `$this->container`, не будет пройден потому, что после включения модуля “book” контейнер `$this->container` не обновится. Тест `testDrupalPass()` пройдет успешно - `\Drupal::service` будет включать в себя сервисы из только что включенного модуля.

Чтобы тест `testContainerFail()` прошел успешно, нужно контейнер сервисов проинициализировать еще раз используя `$this->rebuildContainer();` либо же  `$this->container = \Drupal::getContainer();`

```php
public function testContainerPass() {
  $this->container->get('module_installer')->install(['book']);
  // Initialise the service container once again to pass the test.
  $this->rebuildContainer();
  $all_books = $this->container->get('book.manager')->getAllBooks();

  $this->assertEmpty($all_books);
}
```

### Пример 2

Давайте рассмотрим другой пример в котором у нас контейнер сервисов используется в хуке:

```php
/**
 * Implements hook_ENTITY_TYPE_load().
 */
function example_user_load(array $entities) {
  // Service container is re-initialised during cache flush.
  drupal_flush_all_caches();
  \Drupal::service('state')->set('test', 'bar');
 }
```

Обратите внимание, что в хуке используется drupal_flush_all_caches().

И есть два Functional теста:

```php
namespace Drupal\Tests\example\Functional;

use Drupal\Tests\BrowserTestBase;

/**
 * Tests behaviour of service containers in Functional tests.
 */
class StateFunctionalTest extends BrowserTestBase {

  protected $defaultTheme = 'stark';

  /**
   * {@inheritdoc}
   */
  protected static $modules = [
    'example',
  ];

  /**
   * Test is passed since the state returns correct value.
   */
  public function testDrupalStatePass() {
    \Drupal::service('state')->set('test', 'foo');
    $this->assertEquals('foo', \Drupal::service('state')->get('test'));
    \Drupal::entityTypeManager()->getStorage('user')->load(1);
    $this->assertEquals('bar', \Drupal::service('state')->get('test'));
  }

  /**
   * Test fails since \Drupal and $this->container point to different instances of State service.
   */
  public function testContainerStateFail() {
    $this->container->get('state')->set('test', 'foo');
    $this->assertEquals('foo', $this->container->get('state')->get('test'));
    $this->container->get('entity_type.manager')->getStorage('user')->load(1);
    $this->assertEquals('bar', $this->container->get('state')->get('test'));
  }
}
```
Первый тест `testDrupalStatePass()`, где используется `\Drupal`, пройдет успешно, а вот второй тест `testContainerStateFail()` пройти не сможет из-за того, что в `example_user_load()` мы очистили кеш и инициализировали контейнер сервисов заново. Теперь мы имеем дело с разными экземплярами контейнера сервисов в `\Drupal` и `$this->container`. Чтобы пройти тест нужно, как и в первом примере, обновить контейнер сервисов `$this->container` вручную используя `$this->rebuildContainer();` либо же `$this->container = \Drupal::getContainer();`
```php
  /**
   * Test passes since $this->container is updated manually.
   */
  public function testContainerStatePass() {
    $this->container->get('state')->set('test', 'foo');
    $this->assertEquals('foo', $this->container->get('state')->get('test'));
    $this->container->get('entity_type.manager')->getStorage('user')->load(1);
    $this->rebuildContainer();
    $this->assertEquals('bar', $this->container->get('state')->get('test'));
  }
```
Обновлять вручную контейнер сервисов `$this->container` неудобно, не правда ли? Во время написания тестов достаточно сложно понять что контейнеры сервисов в `\Drupal` и `$this->container` рассинхронизированы. 

**Поэтому в Functional тестах для избежания непонятных ситуаций для получения сервисов лучше использовать \Drupal::service().**

___
Это довольно странная ситуация, когда в Kernel тестах лучше использовать `$this->container->get()`, а в Functional тестах `\Drupal::service()`. На drupal.org eсть [задача](https://www.drupal.org/project/drupal/issues/2066993), где решается каким образом решить эту проблему. Надеюсь в Drupal 10 мы будем использовать единый подход.
