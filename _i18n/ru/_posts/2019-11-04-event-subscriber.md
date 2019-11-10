---
layout: post
title:  "Разбираем систему событий в Drupal 8"
date:   2019-11-04 10:00:00 +0000
categories: ru Drupal API
canonical_url: https://www.enik.io/ru/drupal/certification/2019/10/16/acquia-certification.html
---
## Для чего нам Event Subscriber

В Drupal 8 расширить стандартное поведение скриптов можно разными способами:
* хуки;
* переопределение сервисов через [ServiceProviderBase](https://www.drupal.org/docs/8/api/services-and-dependency-injection/altering-existing-services-providing-dynamic-services);
* переопределение классов плагинов используя хуки;
* события и подписчики на события.

В Drupal 8 события пришли из компонента Symfony [EventDispatcher](https://symfony.com/components/EventDispatcher), который реализует архитектурный шаблон [Mediator](https://www.oodesign.com/mediator-pattern.html) (Посредник). Идея этого шаблона в том, что связать разные классы друг с другом не напрямую, а используя посредник. Классы в этом шаблоне не знают друг о друге, но в тоже время они могут взаимодействовать между собой. Данный подход позволяет делать приложение гибче, а реализацию классов проще, ведь не нужно описывать все возможные связи.
Как мы можем видеть, хуки в Drupal 7 это тоже реализация данного шаблона в парадигме процедурного программировании. В Drupal 8 хуки и события сосуществуют вместе, но в Drupal 9 от хуков будут отказываться в пользу событий, реализованных через объектно-ориентированный подход Уже сейчас можно использовать модуль [Hook Event Dispatcher](https://www.drupal.org/project/hook_event_dispatcher), который реализует события для хук из ядра.

Для некоторых событий есть аналоги в виде хуков, как например `EntityTypeEvents::CREATE` и `hook_ENTITY_TYPE_create()` (например `hook_node_type_create` или `hook_comment_type_create`), но это скорее исключение.

##  Виды событий

Количество событий в ядре неуклонно растет. Список событий вы можете найти здесь:
* [Symfony Kernel Events](https://api.drupal.org/api/drupal/vendor%21symfony%21http-kernel%21KernelEvents.php/class/KernelEvents/8.8.x)
* [Drupal 8 Events](https://api.drupal.org/api/drupal/core%21core.api.php/group/events/8.8.x)

Как вы видите мы должны использовать события:
* при работе с запросами к сайту (KernelEvents)
* при возвращении ответа от сайта (KernelEvents)
* при обработке конфигураций (ConfigEvents)
* при работе с типами сущностей (EntityTypeEvents)
* при создании, обновлении и удалении хранилищ для полей (FieldStorageDefinitionEvents)
* при работе с миграциями (MigrateEvents)
* при обрабатывании путей (RoutingEvents)
* и т.д.

## Система событий

Система событий в Drupal 8 состоят из 3 частей:

* **Event Dispatcher** - Реестр событий. Хранит информацию о всех событиях в системе, отсортированных по приоритетам. Используется для запуска событий. Вызывается через `\Drupal::service('event_dispatcher')` (смотрите реализацию в [core/lib/Drupal/Component/EventDispatcher/ContainerAwareEventDispatcher.php](https://git.drupalcode.org/project/drupal/blob/8.8.x/core/lib/Drupal/Component/EventDispatcher/ContainerAwareEventDispatcher.php)).
* **Event Subscribers** – Подписчики на события. В каждом подписчике определяются слушатели, которые будут запущены при возникновении события.
* **Event** - событие. Для каждого события определяется отдельный класс расширяющий `\Symfony\Component\EventDispatcher\Event`, в который помещаются данные для дальнейшей обработки.

## Подписчики на события

Давайте рассмотрим на примере, как работают подписчики на события.

В начале определяется подписчик на событие в *.services.yml файле.
Пример из core/modules/user/user.services.yml:
```yml
# Название подписчика
user_maintenance_mode_subscriber: 
  # Класс подписчика, где будет реализовываться логика.
 class: Drupal\user\EventSubscriber\MaintenanceModeSubscriber
 # Сервисы, которые будут использоваться в подписчике.
 arguments: ['@maintenance_mode', '@current_user']
 # Используя тег “event_subscriber” мы обозначаем этот сервис как подписчик. 
 # Он добавится в Event Dispatcher сервис.
 tags:
   - { name: event_subscriber }
```

Реализация подписчика на примере [core/modules/user/src/EventSubscriber/MaintenanceModeSubscriber.php](https://git.drupalcode.org/project/drupal/blob/8.8.x/core/modules/user/src/EventSubscriber/MaintenanceModeSubscriber.php)
```php
namespace Drupal\user\EventSubscriber;

use Drupal\Core\Routing\RouteMatch;
use Drupal\Core\Session\AccountInterface;
use Drupal\Core\Site\MaintenanceModeInterface;
use Drupal\Core\Url;
use Symfony\Component\EventDispatcher\EventSubscriberInterface;
use Symfony\Component\HttpFoundation\RedirectResponse;
use Symfony\Component\HttpKernel\Event\GetResponseEvent;
use Symfony\Component\HttpKernel\KernelEvents;

/**
* Maintenance mode subscriber to log out users.
*/
class MaintenanceModeSubscriber implements EventSubscriberInterface {

 /**
  * The maintenance mode.
  */
 protected $maintenanceMode;

 /**
  * The current account.
  */
 protected $account;

 /**
  * Constructs a new MaintenanceModeSubscriber.
  */
 public function __construct(MaintenanceModeInterface $maintenance_mode, AccountInterface $account) {
   // Подключаем сервисы, которые мы определили в описании сервиса в user.services.yml
   $this->maintenanceMode = $maintenance_mode;
   $this->account = $account;
 }

 /**
  * Метод getSubscribedEvents() является обязательным и служит
  * для описания слушателей.
  */
 public static function getSubscribedEvents() {
   // Подписываемся на событие KernelEvents::REQUEST. 
   // Когда событие произойдет, то запустится метод-слушатель onKernelRequestMaintenance в этом же классе. 
   // 31 - приоритет слушателя.   
   $events[KernelEvents::REQUEST][] = ['onKernelRequestMaintenance', 31];
   return $events;
 }

 /**
  * Logout users if site is in maintenance mode.
  */
 public function onKernelRequestMaintenance(GetResponseEvent $event) {
   // Непосредственно реализация слушателя.
   $request = $event->getRequest();
   $route_match = RouteMatch::createFromRequest($request);
   if ($this->maintenanceMode->applies($route_match)) {
     // If the site is offline, log out unprivileged users.
     if ($this->account->isAuthenticated() && !$this->maintenanceMode->exempt($this->account)) {
       user_logout();
       // Redirect to homepage.
       $event->setResponse(
         new RedirectResponse(Url::fromRoute('<front>')->toString())
       );
     }
   }
 }
}
```

### Прерывание работы события.

Слушатели вызываются один за одним. Порядок определяется их приоритетом. Чем больше приоритет, тем раньше этот слушатель вызовется. Тут нужно быть внимательным и не перепутать с понятием “вес”, который работает наоборот.

Можно сделать так, чтобы прекратить вызов слушателей. Для этого есть метод `Symfony\Component\EventDispatcher\Event::stopPropagation()`. Если этот метод был вызван в каком-либо из слушателей, то следующие слушатели не будут вызваны.

Пример из [core/modules/system/src/SystemConfigSubscriber.php](https://git.drupalcode.org/project/drupal/blob/8.8.x/core/modules/system/src/SystemConfigSubscriber.php):
```php
/**
* Инициализация слушателей.
*/
public static function getSubscribedEvents() {
 $events[ConfigEvents::SAVE][] = ['onConfigSave', 0];
 // Проверка на пустое значение имеет высокий приоритет, 
 // чтобы остановить дальнейшую обработку событий если конфигурация пустая.
 $events[ConfigEvents::IMPORT_VALIDATE][] = ['onConfigImporterValidateNotEmpty', 512];
 return $events;
}

/**
* Если конфигурация пуста, то не нужно её импортировать, т.к. это удалит имеющуюся конфигурацию. 
* Останавливаем процесс импорта на данном этапе.
*/
public function onConfigImporterValidateNotEmpty(ConfigImporterEvent $event) {
 $importList = $event->getConfigImporter()->getStorageComparer()->getSourceStorage()->listAll();
 if (empty($importList)) {
   $event->getConfigImporter()->logError($this->t('This import is empty and if applied would delete all of your configuration, so has been rejected.'));
   $event->stopPropagation();
 }
}

```

###  Определение слушателей динамически.
Слушатели могут быть определены и “на лету”. Давайте рассмотрим пример из [core/lib/Drupal/Core/Action/Plugin/Action/GotoAction.php](https://git.drupalcode.org/project/drupal/blob/8.8.x/core/lib/Drupal/Core/Action/Plugin/Action/GotoAction.php):

```php
$response = new RedirectResponse($url);
// Слушатель события определенный динамически.
$listener = function ($event) use ($response) {
  $event->setResponse($response);
};
// Добавляем слушатель события в реестр событий используя сервис “event_dispatcher”.
$this->dispatcher->addListener(KernelEvents::RESPONSE, $listener);
```

В данном примере при возникновении события `KernelEvents::RESPONSE` (ответ от сайта был сформирован, но еще не отправлен) происходит замена ответа на редирект на другую страницу. Как вы видите слушатель был создан "на лету" и он будет выполнен только во время данного запроса.

## Определение событий

В процессе разработки модулей нам нужно предоставлять интерфейс для изменения данных другим разработчикам и уведомлять другие части системы о произошедших действиях. Как было уже сказано, хуки постепенно отживают свое. Будем переходить на события. Давайте разберемся как это делать на примере Route Events в ядре Drupal.


В [core/lib/Drupal/Core/Routing/RoutingEvents.php](https://git.drupalcode.org/project/drupal/blob/8.8.x/core/lib/Drupal/Core/Routing/RoutingEvents.php) определяются названия событий. Обычно для этих целей используются константы. Да, можно было определить названия событий в классе события, но тогда константы можно было бы переопределить при расширении класса события. Чтобы защитить вашу систему от вас самих, названия событий определили в отдельном финальном классе, который вы не сможете расширить. 

```php
namespace Drupal\Core\Routing;

/**
* Contains all events thrown in the core routing component.
*/
final class RoutingEvents {

 /**
  * Name of the event fired during route collection to allow new routes.
  */
 const DYNAMIC = 'routing.route_dynamic';

 /**
  * Name of the event fired during route collection to allow changes to routes.
  */
 const ALTER = 'routing.route_alter';

 /**
  * Name of the event fired to indicate route building has ended.
  */
 const FINISHED = 'routing.route_finished';
}
```

Непосредственно класс события реализован в [core/lib/Drupal/Core/Routing/RouteBuildEvent.php](https://git.drupalcode.org/project/drupal/blob/8.8.x/core/lib/Drupal/Core/Routing/RouteBuildEvent.php). Как мы видим здесь реализован конструктор, который принимает переменную и функция getRouteCollection(), которая отдает эту переменную. Это все. Обычно класс события не содержит в себе логику, являясь лишь хранилищем для данных.

```php
namespace Drupal\Core\Routing;

use Symfony\Component\EventDispatcher\Event;
use Symfony\Component\Routing\RouteCollection;

/**
* Represents route building information as event.
*/
class RouteBuildEvent extends Event {

 /**
  * The route collection.
  */
 protected $routeCollection;

 /**
  * Constructs a RouteBuildEvent object.
  */
 public function __construct(RouteCollection $route_collection) {
   $this->routeCollection = $route_collection;
 }

 /**
  * Gets the route collection.
  */
 public function getRouteCollection() {
   return $this->routeCollection;
 }
}
```

Как это вызывается? Для того, чтобы вызвать событие нам нужен объект сервиса `event_dispatcher` и метод `dispatch`: `\Drupal::service(“event_dispatcher”)->dispatch(Event::NAME, $event)`

Рассмотрим пример [core/lib/Drupal/Core/Routing/RouteBuilder.php](https://git.drupalcode.org/project/drupal/blob/8.8.x/core/lib/Drupal/Core/Routing/RouteBuilder.php)

```php
namespace Drupal\Core\Routing;

/**
* Managing class for rebuilding the router table.
*/
class RouteBuilder implements RouteBuilderInterface, DestructableInterface {

/**
* The event dispatcher to notify of routes.
*
* @var \Symfony\Component\EventDispatcher\EventDispatcherInterface
*/
protected $dispatcher;

...

public function rebuild() {
  ...
  // DYNAMIC is supposed to be used to add new routes based upon all the
  // static defined ones.
  $this->dispatcher->dispatch(RoutingEvents::DYNAMIC, new RouteBuildEvent($collection));

  // ALTER is the final step to alter all the existing routes. We cannot stop
  // people from adding new routes here, but we define two separate steps to
  // make it clear.
  $this->dispatcher->dispatch(RoutingEvents::ALTER, new RouteBuildEvent($collection));
  $this->checkProvider->setChecks($collection);

  ...
}
}
```
  
**Ссылки:**

* [Symfony Event Dispatcher](https://symfony.com/components/EventDispatcher)
* [Описание шаблона Mediator](https://www.oodesign.com/mediator-pattern.html)
* [Модуль Hook Event Dispatcher](https://www.drupal.org/project/hook_event_dispatcher)
* [Drupal 8: Hooks, Events, and Event Subscribers](https://www.daggerhart.com/drupal-8-hooks-events-event-subscribers)
* [Subscribe to and dispatch events](https://www.drupal.org/docs/8/creating-custom-modules/subscribe-to-and-dispatch-events) 
* [EventSubscriber example](https://www.drupal.org/docs/8/modules/simple-fb-connect-8x/eventsubscriber-example)
