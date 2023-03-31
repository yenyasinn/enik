---
layout: post
title: "Использование class resolver для внедрения зависимостей в Drupal 9"
date: 2022-06-04 10:00:00 +0000
categories: ru Drupal API
canonical_url: https://www.enik.pro/ru/drupal/api/2022/06/04/class-resolver.html
---
Давайте разберем такой случай: у нас есть небольшой класс, который используется локально в модуле (например в хуке) в котором мы бы хотели использовать сервисы.

```php
class DemoClass {

  protected $languageManager;

  public function __construct(LanguageManagerInterface $languageManager) {
    $this->languageManager = $languageManager;
  }

  public function foo() {}
}
```

Как мы можем использовать этот класс ведь нам нужно каким-то образом инициировать сервисы внутри этого класса? Первое что приходит на ум - это создание сервиса и внедрение зависимостей через контейнер сервисов:

```yml
services:
  demo_service:
    class: Drupal\Example\DemoClass
    arguments: ['@language_manager']
```

Теперь мы можем использовать наш класс вызывая его так `\Drupal::service('demo_service')->foo()`.

Вроде бы все хорошо - это работает. Но давайте разберемся, что такое сервисы.

Сервис - это объект, который находится в специальном объекте service container. Таким образом у нас появляется единый способ конструирования объектов сервисов, мы можем объединять сервисы в группы используя теги, заменять сервисы на свою реализацию.

Как бы хорошо и быстро контейнер сервисов не работал, но добавление новых сервисов будет замедлять его работу. Ведь контейнеру сервисов нужно будет найти и [загрузить все сервисы](https://www.drupal.org/docs/drupal-apis/services-and-dependency-injection/altering-existing-services-providing-dynamic#s-how-drupal-compiles-its-container). Если у нас небольшой класс для локальной работы в модуле, который нет смысла потом переопределять или который не будет потом использоваться в других модулях, то и смысла использовать сервис для этого класса нет.

Эффективнее будет использовать специальный сервис `class_resolver` дня внедрения зависимостей. Для этого реализуем ContainerInjectionInterface в нашем классе.

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

Теперь мы можем создать экземпляр класса и вызвать метод.

```php
use Drupal\Example\DemoClass;

$demo = \Drupal::service('class_resolver')
->getInstanceFromDefinition(DemoClass::class);
$demo->foo();
```

На самом деле class_resolver используется в Drupal для внедрения зависимостей чаще, чем сервисы. Например, все формы реализуют `ContainerInjectionInterface` (посмотрите Drupal\Core\Form\FormBase) и создаются в Drupal\Core\Form\FormBuilder через class_resolver. Также многие объекты расширяющие `ConstraintValidator` реализуют `ContainerInjectionInterface`, а `Drupal\Core\Validation\ConstraintValidatorFactory` создает их экземпляры используя class_resolver. Также все экземпляры классов контроллеров создаются через class_resolver.

Не следует создавать сервис каждый раз, когда вам нужно использовать внедрение зависимостей. Для использования класса внутри модуля сервис class_resolver будет куда более подходящим решением.
