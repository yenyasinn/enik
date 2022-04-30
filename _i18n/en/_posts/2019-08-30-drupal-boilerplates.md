---
layout: post
title:  "Choosing Drupal 8 boilerplate"
date:   2019-08-30 10:00:00 +0000
categories: en Drupal boilerplate
canonical_url: https://www.enik.pro/drupal/boilerplate/2019/08/30/drupal-boilerplates.html
---
When a new project is started we always think what should we take as a base. If we are talking about Drupal development then many people can advise to take just Drupal. I would agree with this proposal if it is a small project where only one person is involved. If there are lots of developers on the project or size of the project is middle or big then we have to think about:
* it has to be convenient for people to work with it;
* it should contain tools that will be used during the whole project life cycle or we could add such tools.
* increasing our efficiency on the project. 

Computer programmers, who develop web applications consistently, usually have some boilerplates that they use for new projects. I would like to review a few such templates and will try to sort out when these boilerplates can be used.

## Decoupled Drupal with GraphQL and React by AmazeeLab.

As mentioned in the name, this boilerplate can be used for creation decoupled Drupal application using React on front side and GraphQL on the back-end.

**Project includes:**
* Docker image;
* Drupal 8;
* Drush 8;
* Modules for [GraphQL](https://graphql.org).
* [React](https://reactjs.org/)
* React framework [Next.js](https://nextjs.org)

Project provides you two URLs after installation for front-end and back-end parts. 

This project is supported by Amazee Lab, who actively develop decoupled web applications.

So I would recommend this boilerplate as a starter-kit if you want to use GraphQL and React in your project.

**Link to the project** - [https://github.com/drupal-graphql/drupal-decoupled-app](https://github.com/drupal-graphql/drupal-decoupled-app)

## Decoupled Drupal with React by SystemSeed

**There are:**
* Docker image
* Drupal 8
* [Contenta CMS](http://www.contentacms.org)
* React framework [Next.js](https://nextjs.org)
* Prepared scripts for deploying to [platform.sh](https://platform.sh/)
* Three types of tests.

There are also two URLs after installation: for front-end and back-end. JSON API is used to transfer data.

This boilerplate provides [commands for automatization frequent actions](https://drupal-reactjs-boilerplate.readthedocs.io/commands/), that can be used for site installation, configuration of Continuous Integration or in local development.

If you develop decoupled web application and use platform.sh, then this boilerplate is well suited for your needs.

**Link to the project** - [https://github.com/systemseed/drupal_reactjs_boilerplate](https://github.com/systemseed/drupal_reactjs_boilerplate)

## BLT by Acqua.

**BLT (Build and Launch Tool)** provides tools for development, testing and deploying Drupal 8 applications.

There is [DrupalVM](https://www.drupalvm.com/), that can be installed by one command with working configuration for typical project. Therefore your teammates won’t spend time on the setting up of the local environment. Everything that you need for the development (Apache, Nginx, SOLR, PHP, Xdebug, Memcache) will be configured during DrupalVM installation. Thus we can guarantee that all developers have the same environment on local computers.

BLT supplies lots of commands for simplification your work with the project. It adds an additional layer of abstraction and hides usual drush and shell commands.

For example, BLT has built-in commands for code validation. So, by running command `blt validate:all`, we can:
* execute phpcs for coding standard validation;
* check composer.json and composer.lock;
* ensure that the syntax of yml files is correct;
* check syntax of twig files.


Certainly, you can run these tests separately. It is very convenient when we can start to work right after project installation, and don’t need to waste time on setting up tools. Also BLT can be used in Continuous Integration, that also makes developer’s life easier.

It’s simple to run PHPUnit and Behat tests, integrate your own tests, check security updates using BLT.

Separately I would like to note deployment tools for Acquia Cloud. If you have already used this hosting platform you know how inconvenient deployment process is there. BLT hides deployment process behind one command.

BLT provides Drupal 8 with [Lightning](https://www.drupal.org/project/lightning) profile and installs huge amount of modules, about what you might not even heard. I think it is a negative point in this boilerplate because you need to spend some time on disabling and removing needless modules from the project.

**I would recommend to use Acquia BLT if:**
* you work with Acquia Cloud or Acquia Cloud Site Factory;
* you have a project of Enterprise level;
* there is a big team of developers.

As you see this product isn’t for newbies. But it can simplify the process of development and project support for experts.

**Links**
* [Project documentation](https://docs.acquia.com/blt/)
* [Code on GitHub](https://github.com/acquia/blt)



