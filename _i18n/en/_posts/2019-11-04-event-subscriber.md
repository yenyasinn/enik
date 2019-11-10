---
layout: post
title:  "Analyze of event system in Drupal 8"
date:   2019-11-04 10:00:00 +0000
categories: Drupal API
canonical_url: https://www.enik.io/drupal/api/2019/11/04/event-subscriber.html
---
## How events are used

There are few ways to extend standard behaviour of scripts in Drupal 8:
* hooks;
* service redefinition through [ServiceProviderBase](https://www.drupal.org/docs/8/api/services-and-dependency-injection/altering-existing-services-providing-dynamic-services);
* redefinition of plugin classes using hooks;
* events and event subscribers.

Events came to Drupal 8 from Symfony's component [EventDispatcher](https://symfony.com/components/EventDispatcher), which implements pattern [Mediator](https://www.oodesign.com/mediator-pattern.html). The main idea of this pattern is that different classes aren’t linked directly and don’t know about each other but they use mediator for communication. Such approach allows make application flexible and simplify classes due to the fact that they don’t need support all connections.

As you can see Drupal 7 hooks are the implementation of this pattern using procedural programming paradigm. Drupal 8 uses hooks and events both but Drupal 9 will get rid of hooks in favor of events that use object-oriented programming paradigm. You can start to use events now instead of hooks using [Hook Event Dispatcher](https://www.drupal.org/project/hook_event_dispatcher) module that implements events for hooks from the core.

There are some hook analogs for events, for example `EntityTypeEvents::CREATE` and `hook_ENTITY_TYPE_create()` (`hook_node_type_create` or `hook_comment_type_create`), but I would say that it is an exception.

##  Event types

Number of events in the Drupal core increases permanently. You can find the list of events here:
* [Symfony Kernel Events](https://api.drupal.org/api/drupal/vendor%21symfony%21http-kernel%21KernelEvents.php/class/KernelEvents/8.8.x)
* [Drupal 8 Events](https://api.drupal.org/api/drupal/core%21core.api.php/group/events/8.8.x)

As you can see we have to use events:
* when we work with site requests (KernelEvents)
* when we return site response (KernelEvents)
* during processing of configurations (ConfigEvents)
* during work with event types (EntityTypeEvents)
* during creating, updating and removing fields storages (FieldStorageDefinitionEvents)
* during work with migrations (MigrateEvents)
* during routes processing (RoutingEvents)
* etc.


## Events system

Events system in Drupal 8 consist of 3 parts:

* **Event Dispatcher** - Event registry. It stores information about all events in the system sorted by priority. Is used to run events. Is invoked through `\Drupal::service('event_dispatcher')` (see implementation in [core/lib/Drupal/Component/EventDispatcher/ContainerAwareEventDispatcher.php](https://git.drupalcode.org/project/drupal/blob/8.8.x/core/lib/Drupal/Component/EventDispatcher/ContainerAwareEventDispatcher.php)).
* **Event Subscribers** – Each subscriber defines listeners which are run when event is triggered.
* **Events** - Event is a special class that extend `\Symfony\Component\EventDispatcher\Event` and is used as a storage of data for next processing in listeners.

## Event subscribers

Let’s see in the examples how event subscribers work.

First of all subscriber is defined in the *.services.yml file.
Example from core/modules/user/user.services.yml:
```yml
# Event subscriber name
user_maintenance_mode_subscriber:
 # Event subscriber class.
class: Drupal\user\EventSubscriber\MaintenanceModeSubscriber
# Services that are used in the subscriber.
arguments: ['@maintenance_mode', '@current_user']
# Service is marked as event subscriber by tag “event_subscriber”.
# It will be added to the registry in Event Dispatcher service.
tags:
  - { name: event_subscriber }
```

Implementation of event subscriber in [core/modules/user/src/EventSubscriber/MaintenanceModeSubscriber.php](https://git.drupalcode.org/project/drupal/blob/8.8.x/core/modules/user/src/EventSubscriber/MaintenanceModeSubscriber.php)
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
  // We use services that are defined in the services definition in user.services.yml
  $this->maintenanceMode = $maintenance_mode;
  $this->account = $account;
}

/**
 * Method getSubscribedEvents() is required and is used for describing listeners.
 */
public static function getSubscribedEvents() {
  // Subscribe to the event KernelEvents::REQUEST.
  // When this event occurs, method listener onKernelRequestMaintenance will be triggered.
  // 31 - priority of the listener.  
  $events[KernelEvents::REQUEST][] = ['onKernelRequestMaintenance', 31];
  return $events;
}

/**
 * Logout users if site is in maintenance mode.
 */
public function onKernelRequestMaintenance(GetResponseEvent $event) {
  // Listener implementation.
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

### Event interruption

Listeners are called one by one. Order is defined by priority. Listeners with higher priority are called earlier. You have to be careful and don’t mix up priority with term “weight” that works vice-versa.

Calling of listeners can be interrupted. Method `Symfony\Component\EventDispatcher\Event::stopPropagation()` can be used for it. If it is called by one of some listeners then next listeners won’t be called.

Example from [core/modules/system/src/SystemConfigSubscriber.php](https://git.drupalcode.org/project/drupal/blob/8.8.x/core/modules/system/src/SystemConfigSubscriber.php):
```php
/**
* Listeners initialisation.
*/
public static function getSubscribedEvents() {
$events[ConfigEvents::SAVE][] = ['onConfigSave', 0];
// Empty value check has high priority to stop further processing if configuration is empty.
$events[ConfigEvents::IMPORT_VALIDATE][] = ['onConfigImporterValidateNotEmpty', 512];
return $events;
}

/**
* No need to import configuration if it is empty. Otherwise import will remove active configuration.
* Stop process on this step.
*/
public function onConfigImporterValidateNotEmpty(ConfigImporterEvent $event) {
$importList = $event->getConfigImporter()->getStorageComparer()->getSourceStorage()->listAll();
if (empty($importList)) {
  $event->getConfigImporter()->logError($this->t('This import is empty and if applied would delete all of your configuration, so has been rejected.'));
  $event->stopPropagation();
}
}

```

###  Dynamic listeners definitions. 
Listeners can be defined “on the fly”. Let’s check the example from the [core/lib/Drupal/Core/Action/Plugin/Action/GotoAction.php](https://git.drupalcode.org/project/drupal/blob/8.8.x/core/lib/Drupal/Core/Action/Plugin/Action/GotoAction.php):

```php
$response = new RedirectResponse($url);
// Listener of the event that is defined dynamically.
$listener = function ($event) use ($response) {
  $event->setResponse($response);
};
// Listener is added to the event registry using “event_dispatcher” service.
$this->dispatcher->addListener(KernelEvents::RESPONSE, $listener);
```

When event  `KernelEvents::RESPONSE` occurs (site response had been created but has not been sent yet) response is changed by redirect to another page. As you see listener has been created dynamically and it will be executed during this request only.

## Events definition

We need to provide an interface to change data to another developers and notify other parts of the system about the actions taken. As was mentioned above hooks won’t be used in future. We will begin to use events. Let’s figure out how to do it using Route Events from the core as an example. 



There are events names in the [core/lib/Drupal/Core/Routing/RoutingEvents.php](https://git.drupalcode.org/project/drupal/blob/8.8.x/core/lib/Drupal/Core/Routing/RoutingEvents.php). Constants are used to define names usually. It’s possible to define events names in the event class but in this case names can be overridden in the class extension. Events names are defined in the final class that can’t be extended to protect your system from you.

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

Event is implemented in the  [core/lib/Drupal/Core/Routing/RouteBuildEvent.php](https://git.drupalcode.org/project/drupal/blob/8.8.x/core/lib/Drupal/Core/Routing/RouteBuildEvent.php). There is a constructor that set variable and function getRouteCollection() that return this variable. That’s all. Event class  doesn’t contain any data usually and is used as a data storage.

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

How can we trigger an event? For this we should use service `event_dispatcher` and method `dispatch`:
`\Drupal::service(“event_dispatcher”)->dispatch(Event::NAME, $event)`

Let's look at an example [core/lib/Drupal/Core/Routing/RouteBuilder.php](https://git.drupalcode.org/project/drupal/blob/8.8.x/core/lib/Drupal/Core/Routing/RouteBuilder.php)

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

**Links:**

* [Symfony Event Dispatcher](https://symfony.com/components/EventDispatcher)
* [Mediator pattern explanation](https://www.oodesign.com/mediator-pattern.html)
* [Hook Event Dispatcher module](https://www.drupal.org/project/hook_event_dispatcher)
* [Drupal 8: Hooks, Events, and Event Subscribers](https://www.daggerhart.com/drupal-8-hooks-events-event-subscribers)
* [Subscribe to and dispatch events](https://www.drupal.org/docs/8/creating-custom-modules/subscribe-to-and-dispatch-events)
* [EventSubscriber example](https://www.drupal.org/docs/8/modules/simple-fb-connect-8x/eventsubscriber-example)
