---
layout: post
title: "Features of using the service container in tests in Drupal 9"
date: 2022-10-02 10:00:00 +0000
categories: Drupal tests
canonical_url: https://www.enik.pro/drupal/tests/2022/10/02/service-containers.html
---
Have you noticed that services are called through `$this->container->get()` or `\Drupal::service()` in Kernel and Functional tests. On the first glance it doesn’t matter - we receive a service in any case and tests work, but there are nuances. Let’s figure it out.

## Kernel tests

The service container is available through the internal variable `$this->container` and class `\Drupal` in Kernel tests.

Class `\Drupal` (located in core/lib/Drupal.php) - is a static service container wrapper. It was created to get services in procedural code, for instance, in hooks. We can (and have to) use dependency injection in classes, but there is no other choice to get services in procedural code.

So we can use `$this->container->get()` and `\Drupal::service()` to load services both in Kernel tests. Usage of `\Drupal` in tests is considered as anti-pattern because it was created for procedural code, but not for object oriented programming. 

**Therefore, it is preferable to call services in Kernel tests via $this->container->get().**

## Functional tests

### Example 1

Let's look at examples of functional tests using `$this->container` and `\Drupal` service containers, in which we need to enable and use the `book` module inside the test:

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
The test `testContainerFail()`, which uses `$this->container`, fails  because after enabling the “book” module the container `$this->container` isn't updated. Test  `testDrupalPass()` passes - `\Drupal::service` includes all services from the just enabled module.

We need to initialise service container once again using  `$this->rebuildContainer();` or `$this->container = \Drupal::getContainer();` to make the test  `testContainerFail()` pass.

```php
public function testContainerPass() {
 $this->container->get('module_installer')->install(['book']);
 // Initialise the service container once again to pass the test.
 $this->rebuildContainer();
 $all_books = $this->container->get('book.manager')->getAllBooks();

 $this->assertEmpty($all_books);
}
```

### Example 2

Let’s consider another example where service container is used in the hook:

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

Pay attention that `drupal_flush_all_caches()` is used in the hook.

Also there are two Functional tests:

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
  * Test is passed since the state returns the correct value.
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
First test `testDrupalStatePass()`, where `\Drupal` is used, passes successfully, but second test `testContainerStateFail()` fails since in the `example_user_load()` cache has been cleaned and service container was initialised again. Currently there are two different instances of the service container in  `\Drupal` and `$this->container`. In order to pass test successfully, we need to update service container  `$this->container` using  `$this->rebuildContainer();` or `$this->container = \Drupal::getContainer();` as in the first example.

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

It’s inconvenient to update the service container `$this->container` manually, isn’t it? Can be hard to understand that service containers `\Drupal` and `$this->container` out of sync during writing tests. 

**So, use \Drupal::service() in Functional tests to avoid incomprehensible situations.**

___
It is quite strange that we should use `$this->container->get()` in Kernel tests and  `\Drupal::service()` in Functional tests. You can follow [ticket](https://www.drupal.org/project/drupal/issues/2066993) where this issue is being resolved. I hope we will use unified approach in Drupal 10.
