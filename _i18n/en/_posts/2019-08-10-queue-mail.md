---
layout: post
title:  "When you should send mails through a queue in Drupal."
date:   2019-08-10 15:00:00 +0000
categories: en Drupal architecture
canonical_url: https://www.enik.io/drupal/architecture/2019/08/10/queue-mail.html
---
Let’s understand how site sends mails in the beginning.

There are two main ways to send mails:
1. Using PHP function mail(). This function puts your mail to sendmail that sends mails to the recipients.
2. Using remote SMTP server.

Usually, after the user clicks on the submit button, the PHP script connects to the mail server. If connection is established successfully, mail is sent to the server. Thus mail is sent. In case when mail server is inaccessible (there were different reasons: issue with servers, with connection) mail won’t be sent. All this time, while PHP script is trying to connect to mail server, user sees loading page. He is needed to wait while connection won’t be interrupted by timeout. If connection isn’t established he will see error message. He will be obligated to send the form once again. Otherwise his message will be lost.

Alternative option - send mails asynchronously. We can put mails to the queue and send them later instead of sending right now.

There is a module in Drupal that can help you with it - [Queue Mail](https://www.drupal.org/project/queue_mail). Mails, that are created on the site, are put to the queue. They will be sent during the next launch of cron. 

Queue mail provides you ability to set:
* categories of mails that have to be sent through queue;
* how many attempts should be done before removal of the mail from the queue;
* time between mail send. It can be used to set the frequency of mail sending if you want not to be added to spam list.

**Therefore you should use queue for sending mails if:**
* you need to improve performance of the site. User’s won’t wait until mail is sent during form submission. For instance, the difference between sending mail using mail() and using queue is 2 times (11.76 milliseconds versus 5.57 milliseconds in my testing) .
* you have to improve user experience of the site - if there are any troubles with mail sending users don’t need to submit a form again.
* you want to do site more reliable - mails will be sent once it is possible.
* you need more options for configuration mail sending. 
