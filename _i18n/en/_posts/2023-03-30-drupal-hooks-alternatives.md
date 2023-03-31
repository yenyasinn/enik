---
layout: post
title: "Alternatives of hook system in Drupal 10"
date: 2023-03-30 10:00:00 +0000
categories: Drupal API
canonical_url: https://www.enik.pro/drupal/api/2023/03/30/drupal-hooks-alternatives.html
---
A system of hooks was implemented in Drupal to change the behavior of the code. It implements the [“Mediator”](/drupal/architecture/2021/01/10/patterns.html) design pattern in procedural programming and provides a single interface for communication of different parts of the system.

Time does not stand still and the procedural approach in Drupal versions up to 8 has been replaced by an object-oriented approach. Drupal 8 is built on top of the Symfony framework which already has an implementation of the Mediator pattern in the symfony/event-dispatcher library. Thus, in the Drupal core, there are two parallel systems that provide the ability for components to communicate with each other - hooks and [events](/drupal/api/2019/11/04/event-subscriber.html).

Why are there currently two, in fact, duplicate systems, and what are the alternatives?

## Hooks

As already mentioned, Drupal 10 inherited hooks from older versions. They were a distinctive feature of Drupal, and when there was a migration to Symfony, they were not completely cut out and left as part of the Drupal identity, which was familiar and understandable to programmers. In order to use such a powerful Symfony tool as services and dependency injection in procedural code, we had to create the \Drupal class - a wrapper for a static service container. In fact, we only need the \Drupal class for hooks and template preprocesses, because in classes, instead of \Drupal, we use dependency injection to get services. Thus, while supporting hooks, we need to support additional functionality to be able to use services in hooks, which complicates the Drupal core.

At this time, many modules use core's hooks and define hooks themselves. Therefore, since they were left in Drupal 8, so far it is quite difficult to get rid of them. They are still the main way to extend and change the functionality of Drupal. But there are many questions about the use of hooks. It is clear that they are a rudiment in OOP.

## Events and "Hook Event Dispatcher"

There is a strange situation in Drupal at the moment where we need to use hooks to extend certain functionality (for example `hook_form_alter()` to change a form behaviour) and for others we need to use events (for example changing of existing route). What is based on Symfony components is changed through events, and what is implemented in Drupal is changed through hooks. Pretty inconvenient, isn't it?

An attempt to get rid of hooks was made in Drupal 8, then it was postponed until Drupal 9, but they are still present in Drupal 10. Drupal core does not provide events that we can use to replace hooks. But fortunately there is a module [Hook Event Dispatcher](https://www.drupal.org/project/hook_event_dispatcher) that provides events similar to hooks.

Для изменения формы поиска через хуки нам достаточно кода:

We only need the code to change the search form through hooks:

```php
/**
 * Implements hook_form_FORM_ID_alter().
 */
function example_form_search_block_form_alter(&$form, \Drupal\Core\Form\FormStateInterface $form_state, $form_id) {
 $form['keys']['#attributes']['placeholder'] = t('Search');
}

```

We need to define a listener first to use an event from the “Hook Event Dispatcher” module:

```yaml
services:
 example.form_subscribers:
   class: Drupal\example\ExampleFormEventSubscribers
   tags:
     - { name: event_subscriber }
```

And then implement it:

```php
class ExampleFormEventSubscribers implements EventSubscriberInterface {

 /**
  * Alter search form.
  *
  * @param \Drupal\core_event_dispatcher\Event\Form\FormIdAlterEvent $event
  *   The event.
  */
 public function alterSearchForm(FormIdAlterEvent $event): void {
   $form = &$event->getForm();
   // Add placeholder.
   $form['keys']['#attributes']['placeholder'] = $this->t('Search');
 }

 /**
  * {@inheritdoc}
  */
 public static function getSubscribedEvents(): array {
   return [
     'hook_event_dispatcher.form_search_block_form.alter' => 'alterSearchForm',
   ];
 }
}
```

Also “Hook Event Dispatcher” can be used for template theming - it provides preprocess events for core templates.

If you use some module in your project that defines its own hooks or templates, then you have to implement events for these hooks in your project yourself, which, of course, does not make your life easier. Code above clearly shows how much less code is needed for a hook than for an event.

**But events have advantages over hooks:**
* Easier to determine the sequence of events.
* Events can prevent the execution of subsequent events.
* Ability to define listeners dynamically.

## Hux

[Hux](https://www.drupal.org/project/hux) is a module that provides the ability to combine dependency injection and OOP with ease of use.

The example above with the search form change in Hux would look like this:

```php
namespace Drupal\example\Hooks;

final class ExampleHooks {

 #[Alter('form_system_site_information_settings')]
 public function formSystemSiteInformationSettingsAlter(&$form, \Drupal\Core\Form\FormStateInterface $form_state, $form_id) {
   $form['keys']['#attributes']['placeholder'] = t('Search');
 }
}
```

As you can see, everything looks quite simple - the file will be found automatically if placed in the example/src/Hooks folder. A PHP annotation is used to define a hook. If a class implements ContainerInjectionInterface, then any services can be connected via dependency injection.

Hux can not work with templates. So the preprocess functions have to be defined as usual. But you can use any core's and module's hooks. There is also support for weights to change the order of execution of hooks and the ability to replace the implementation of hooks in modules with your own implementation.

## What is the conclusion?

The main problem with "Hook Event Dispatcher" and "Hux" is that **they decorate the standard module_handler service. The Drupal core calls hooks as usual, and these modules have to maintain the standard hook implementation and their own**, adding complexity and not making the whole system faster. You can call events from the “Hook Event Dispatcher” using the Event Dispatcher, but for Hux you still have to call hooks. If hooks are dropped tomorrow, then Hux will be useless. Although, at the moment it is more convenient to use them than events.

For myself, I decided to **implement events** in developing of new modules, when the possibility of expanding the functionality is needed. In any case, we will not go anywhere from events, and in the long run it will be easier to support them than to switch from hooks to events. But for existing hooks in Drupal 10, I would recommend **use the standard functionality**, without installing a “Hook Event Dispatcher” or “Hux” with their overhead and added complexity. Essentially, these modules are an attempt to fix the Drupal architecture. But in order to solve the problem of hooks effectively, it has to be done in the Drupal core.

**Links:**

* [Use Symfony EventDispatcher for hook system](https://www.drupal.org/project/drupal/issues/1509164).
* [Add events for matching entity hooks](https://www.drupal.org/node/2551893).
