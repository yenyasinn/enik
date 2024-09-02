---
layout: post
title: "Используем Acquia CLI вместо BLT для деплоя на Acquia Cloud"
date: 2024-08-19 10:00:00 +0000
categories: ru Drupal tools
canonical_url: https://www.enik.pro/ru/drupal/tools/2024/08/19/remove-blt.html
---
Если вы работали с Acquia Cloud, то вы знаете, что Acquia предлагало [BLT](https://github.com/acquia/blt) в качестве основного инструмента для деплоя сайтов. Время идет и Acquia объявило, что не будет больше поддерживать этот инструмент. Поэтому встал вопрос - как деплоить на Acquia Cloud без использования BLT?

Для решения этой задачи нам нужно:
- Убрать BLT из проекта;
- Отправить код в Acquia Cloud;
- Выполнить автоматизированные задачи после разворачивания проекта в Acquia Cloud.

## Убираем BLT из проекта
BLT приносит с собой большое количество файлов *.settings.php (находятся в `vendor/acquia/blt/settings`), которые вы, скорее всего, подключаете в `settings.php` вашего проекта через включение `blt.settings.php`.

Вы можете посмотреть какие настройки вам нужны в `vendor/acquia/blt/settings` и собрать из них свой `settings.php`. Для работы с окружениями в Acquia Cloud вам может понадобиться пакет https://github.com/acquia/drupal-environment-detector. Данный способ подойдет продвинутым программистам, которые четко знают, что и как они хотят настроить.

Другой подход - установить пакет с рекомендованными настройками https://github.com/acquia/drupal-recommended-settings.

После установки пакета 
```
composer require acquia/drupal-recommended-settings
```
В вашем `sites/default/settings.php` появится код для подключения рекомендованных настроек:

```
require DRUPAL_ROOT . "/../vendor/acquia/drupal-recommended-settings/settings/acquia-recommended.settings.php";
```

Перенесите его в то место где находится `require DRUPAL_ROOT . "/../vendor/acquia/blt/settings/blt.settings.php";` и подключение `blt.settings.php` можно убирать.

В `*.settings.php` файлах проекта замените

```
use Acquia\Blt\Robo\Common\EnvironmentDetector;
```
на
```
use Acquia\Drupal\RecommendedSettings\Helpers\EnvironmentDetector;
```

Теперь можно удалить BLT из проекта:
```
composer remove acquia/blt
```

Если вы использовали пакет `mikemadison13/blt-gitlab-pipelines`, то можно удалить его 

```
composer remove mikemadison13/blt-gitlab-pipelines
```

Удаляем папку `blt` в корне проекта.

Удаляем `blt.yml` файлы в папках `sites/*/`.

Заменяем файлы `sites/*/settings/default.includes.settings.php`, `docroot/sites/*/settings/default.local.settings.php` на соответсвующие из `vendor/acquia/drupal-recommended-settings/settings/site`.

## Настраиваем автоматическое выполнение задач после разворачивания кода на Acquia Cloud

После того, как код отправится в Acquia Cloud, нам нужно будет выполнить задачи по сбросу кеша, запуска обновлений, импортирования конфигурации.

### Cloud Actions

Если вы используете **Acquia Cloud Next**, то оптимальный способ это использование **Cloud Actions**. Вы их можете настроить в админке в разделе Configuration / Cloud Actions в настройке окружения https://cloud.acquia.com/a/environments/[uuid]/config/cloud-actions. Настройка Cloud Actions описана в https://docs.acquia.com/acquia-cloud-platform/manage-apps/cloud-actions. 

Если вы используете Cloud Actions, то **удалите папку `hooks`** в корне проекта.

### Cloud Hooks

Если возможности Cloud Actions будут для вас недостаточны, то можно воспользоваться [Cloud Hooks](https://docs.acquia.com/acquia-cloud-platform/develop-apps/api/cloud-hooks).

В общем случае, поместите код `drush deploy` вместо `blt artifact:...` в файлы в `hooks/common/*`.

Пример файла `hooks/common/post-code-deploy/post-code-deploy.sh`:

```
#!/bin/sh

set -ev

site="$1"
target_env="$2"
db_name="$3"
source_env="$4"

repo_root="/var/www/html/$site.$target_env"
export PATH=$repo_root/vendor/bin:$PATH
cd $repo_root

drush deploy

set +v
```

## Отправляем код в Acquia Cloud

Для того, чтобы отправить код в Acquia Cloud будем использовать [Acquia CLI](https://docs.acquia.com/acquia-cloud-platform/add-ons/acquia-cli/acquia-cli)

В начале нам нужно установить [Acquia CLI](https://docs.acquia.com/acquia-cloud-platform/add-ons/acquia-cli/install):

```shell
curl -OL https://github.com/acquia/cli/releases/latest/download/acli.phar
chmod +x acli.phar
mv acli.phar /usr/local/bin/acl
```

Затем мы должны авторизовать Acquia CLI выполнив команду: 
```shell
acli auth:login
```

Acquia CLI cпросит **API Key** и **API Secret**, которые можно создать в [настройках вашего аккаунта Acquia Cloud](https://cloud.acquia.com/a/profile/tokens).

Далее Acquia CLI спросит к какому приложению в Acqua Cloud будем подключаться и создаст файл `.acquia-cli.yml`. Добавьте его в репозиторий, чтобы не авторизовываться каждый раз.

([Подробнее об авторизации Acquia CLI](https://docs.acquia.com/acquia-cloud-platform/add-ons/acquia-cli/start))

Если вы используете **Gitlab CI**, то нужно установить переменные окружения
**ACLI_KEY** и **ACLI_SECRET** в настройках CI/CD https://gitlab.com/[name]/[repo_name]/-/settings/ci_cd, которые были созданы
на странице [API Tokens](https://cloud.acquia.com/a/profile/tokens).

Следующим шагом создадим папку, в котором Acquia CLI будет строить проект:

```
mkdir /tmp/acli-push-artifact
```

Если вам нужно выполнить какие-то дополнительные операции, например сборка темы, очистка сборки от ненужных файлов, то добавьте в composer.json в секцию `scripts/post-install-cmd` необходимые команды:

```
"scripts": {
    "post-install-cmd": [
        "./scripts/frontend-setup.sh",
        "./scripts/frontend-build.sh"
    ]
}
```

Теперь нужно сохранить все изменения в репозитории `git commit` и можно собрать проект в тестовом режиме, в котором он не будет отправлен в Acquia Cloud:

```
acli push:artifact --no-clone
```

Эта команда cкопирует код в папку `/tmp/acli-push-artifact` и запустит `composer install`.

Откройте `/tmp/acli-push-artifact` и проверьте, что проект был собран как нужно.

У себя в проекте я нашел множество файлов, которые я бы не хотел видеть на production сервере. Раньше они удалялись BLT, но сейчас нужно позаботиться о них самим.

К сожалению в команде `push:artifact` нет возможности указать как нужно проводить очистку. Поэтому я написал скрипт `clean-up.sh`, который удаляет ненужные файлы (не забывайте делать *.sh файлы выполняемыми `chmod 755 clean-up.sh`):

```
#!/usr/bin/env bash

set -ev

# Clean the project if only it is built by ACLI.
if [ `pwd` != "/tmp/acli-push-artifact" ] ; then
  exit;
fi

find . -name tests -prune -exec rm -rf {} \;
find . -name .github -prune -exec rm -rf {} \;
find . -name node_modules -prune -exec rm -rf {} \;

find . -name LICENSE.txt -prune -exec rm {} \;
find . -name README.md -prune -exec rm {} \;

find docroot/modules/contrib/ -name .gitignore -prune -exec rm {} \;
find . -name package.json -prune -exec rm {} \;
find . -name package-lock.json -prune -exec rm {} \;
find . -name *.css.map -prune -exec rm {} \;

set +v
```

И добавил его в composer.json, чтобы очистка происходила после запуска `composer install`:

```
"scripts": {
    "post-install-cmd": [
        "./scripts/frontend-setup.sh",
        "./scripts/frontend-build.sh",
        "./scripts/clean-up.sh"
    ]
}
```

Чтобы очистка происходила только при построении проекта через ACLI, в начало добавлено условие, которое проверяет, что мы находимся в папке "/tmp/acli-push-artifact". Таким образом скрипт очистки не будет вызван при установке проекта локально.

Можно запустить сборку проекта в тестовом режиме еще раз. Если все хорошо, то отправляем проект в Acquia Cloud по названию приложения:

```
acli push:artifact [application name]
```

или отправляем в определенную ветку:

```
acli push:artifact --destination-git-branch=[branch]
```

(Посмотрите `acli push:artifact –help` для расширенных настроек).

Проект будет собран и отправлен в соответсвующее окружение/ветку.

После того, как код попадет в Acuia Cloud, Cloud Actions и Cloud Hooks будут выполнены.
