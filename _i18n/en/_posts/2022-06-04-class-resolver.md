---
layout: post
title: "Using of class resolver for dependency injection in Drupal 9"
date: 2022-06-04 10:00:00 +0000
categories: Drupal API
canonical_url: https://www.enik.pro/drupal/api/2022/06/04/class-resolver.html
---
Let’s consider the case: there is a little class that is used in the module locally (for example in a hook) that uses service.

```php
class DemoClass {

 protected $languageManager;

 public function __construct(LanguageManagerInterface $languageManager) {
   $this->languageManager = $languageManager;
 }

 public function foo() {}
}
```

How can we use this class since we need to instantiate services inside the class somehow?  The first thing that comes to mind is a definition of a service and injection of dependencies through the service container.

```yml
services:
 demo_service:
   class: Drupal\Example\DemoClass
   arguments: ['@language_manager']
```

We can use our class calling a special service `\Drupal::service('demo_service')->foo()`.

On the first glance all good - it works. But let’s analyse what services are.

Service is an object that is situated in a special object - service container. Thus we have the single way to create service objects, we can group services using tags and replace the original service on a custom implementation.

Service container is well designed, very fast and reliable but adding new services will make its work slower because it needs to find and [load all services](https://www.drupal.org/docs/drupal-apis/services-and-dependency-injection/altering-existing-services-providing-dynamic#s-how-drupal-compiles-its-container). It has no sense to have this class as a service if the class is used inside the module only and no need to override its implementation.

Much more effective is to use the special service `class_resolver` for dependency injection. We need to implement ContainerInjectionInterface in our class to achieve it.

```php
namespace Drupal\Example;

use Drupal\Core\DependencyInjection\ContainerInjectionInterface;

class DemoClass implements ContainerInjectionInterface {

 protected $languageManager;

 public function __construct(LanguageManagerInterface $languageManager) {
   $this->languageManager = $languageManager;
 }

 public function create() {
   return new static($container->get('language_manager'));
 }

 public function foo() {}
}
```

Then we can create an instance of the class and call the method:

```php
use Drupal\Example\DemoClass;

$demo = \Drupal::service('class_resolver')
->getInstanceFromDefinition(DemoClass::class);
$demo->foo();
```

Generally speaking class_resolver is used in Drupal for dependency injection more often than services. For instance, all forms implement `ContainerInjectionInterface` (see Drupal\Core\Form\FormBase
) and are created in Drupal\Core\Form\FormBuilder through class_resolver. Also lots of objects that extend `ConstraintValidator` implement `ContainerInjectionInterface` and `Drupal\Core\Validation\ConstraintValidatorFactory` create their instances using class_resolver. Also all instances of controllers are created using class_resolver.

Don’t create a service every time when you need to inject dependencies. In the case of using a class inside the module service class_resolver is a better approach.
