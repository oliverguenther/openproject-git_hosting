# OpenProject Revisions/Git Plugin
[![Code Climate](https://codeclimate.com/github/oliverguenther/openproject-revisions_git/badges/gpa.svg)](https://codeclimate.com/github/oliverguenther/openproject-revisions_git)
[![Dependency Status](https://gemnasium.com/oliverguenther/openproject-revisions_git.svg)](https://gemnasium.com/oliverguenther/openproject-revisions_git)
[![Gitter](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/oliverguenther/openproject-revisions_git?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

This plugin aims to provide extensive features for managing Git repositories within [OpenProject](http://www.openproject.org).
Forked from [jbox-web's version](https://jbox-web.github.io/redmine_git_hosting/) of the long-lived, often-forked redmine-git_hosting plugin (formerly redmine-gitosis).

As OpenProject has diverted quite a bit in terms of project management (e.g., redmine allows multiple repositories per project), some features have been removed in the fork.

**Disclaimer**: This fork is still in progress. While some things work, it is by no means stable - Features may change anytime.

## Overview

* Depends on **Gitolite (v2/v3)**
* Acts as a **wrapper to the gitolite-admin** to feed gitolite with SSH keys, repository information
* Employs **libgit2/rugged** through [gitolite-rugged](https://github.com/oliverguenther/gitolite-rugged).

## Features

**SSH Public-Key Management (Gitolite)**

✓ Multiple keys per user

**Gitolite Repository Management**

✓ Managing repositories with Gitolite upon creation, update/deletion. (Async w/ delayed_jobs)

✓ Members/Roles access written to Gitolite.

✓ SSH-based access (through Gitolite).

**Planned / Forked, but non-functional / non-tested features**
(*Ordered by my own subjective importance.*)

* Git Smart-HTTP (Access through https in OpenProject)
* Post-Receive Hooks
* Repository Mirrors
* Deployment Keys
* Initialize Repositories with Readme

**Stripped/Changed features from jbox-web's version**

* Sidekiq (OpenProject uses delayed_jobs instead)
* SELinux (unfamiliar, can't provide a good fork)
* GitHub features (Issues), should be separate plugin
* Git access cache ( belongs in the core )
* Repository Recycle bin after deletion (Just use your filesystem backups)
* Notifications / Mailing lists

## Installation

#### 0. (preliminary) [Setup Gitolite v2/v3](http://gitolite.com/gitolite/install.html)

I'm assuming you have some basic knowledge of Gitolite and:

* **have built libgit2/rugged WITH SSH Transport support** (see https://github.com/libgit2/rugged/issues/299). This requires ``libssh2-dev`` to be installed on your system.
* are in possession of a SSH key pair set up for use with gitolite.
* have successfully cloned the gitolite-admin.git repository from the user running OpenProject as follows:
```
git clone git@localhost:gitolite-admin /home/openproject/gitolite-admin.git
```


You must now add two manual changes to the gitolite setup for this plugin to work. **These changes are crucial**:

**0.a. Add include 'openproject.conf'** to gitolite
OpenProject uses a separate gitolite config file to declare repositories. This allows you to define your own stuff in <gitolite-admin.git>/conf/gitolite.conf and allows OpenProject to override its own configuration at all times.

Thus, you need to add the following line to 'conf/gitolite.conf' under the gitolite-admin.git repository:

    include 'openproject.conf'
    
The ``openproject.conf`` is created and updated from this plugin and contains all projects with Git repositories later defined within OpenProject. Thus, the ``<gitolite-admin.git>/conf/`` folder will contain two files:

* ``gitolite.conf``: If you want to manually add projects outside the scope of OpenProject to gitolite, define them here.
* ``openproject.conf``: Contains all projects defined from OpenProject, is generated automatically. (*Non-existant until this plugin creates it*)

**0.b. Change Gitolite.rc configuration**

We need to adjust a few things in the ``<git home>/.gitolite.rc``configuration file.

OpenProject identifies project identifiers in gitolite through git config keys, thus you need to alter the .gitolite.rc (In the git user's $HOME) to allow that:

  a. As the git user, open $HOME/.gitolite.rc
  
  b. Change the configuration ``$GIT_CONFIG_KEYS`` to ``'.*',``

  c. Change the configuration for ``$REPO_UMASK`` to ``0770`` to set group rxw permissions

  d. Save the changes


#### 1. Gemfile.plugins

Add a Gemfile.plugins to your OpenProject root with the following contents:

	gem "openproject-revisions", :git => "https://github.com/oliverguenther/openproject-revisions.git", :branch => "dev"
	gem "openproject-revisions_git", :git => "https://github.com/oliverguenther/openproject-revisions_git.git", :branch => "dev"

#### 2. Gitolite access rights

Ensure the user running OpenProject can read and write to the gitolite repostories directory.
This is required for two reasons:

 1. Read the git tree for browsing the repository
 2. Remove deleted repositories (Gitolite doesn't remove them)


We have already changed the configuration file ``gitolite.rc`` to set future permissions on repositories to 0770.
To set the permissions of the existing repositories folder.

    chmod -R 770 <git home>/repositories

Next, add OpenProject to the ``git`` group (assuming your gitolite user is ``git`` and your OpenProject user is ``openproject``) to allow OpenProject to access the repositories.

    addgroup openproject git

Make sure you can access the repositories from openproject:

    su - openproject 
    ls -l <git home>/repositories

#### 3. Gitolite access

Make sure you can ssh into gitolite from the openproject user. If you run the following command, the output below (or similar for gitolite2) should appear. **If it does not, this is a gitolite configuration error.**

	openproject$ ssh -i <gitolite-admin SSH key> git@localhost info
	hello openproject, this is git@dev running gitolite3 v3.x-x on git x.x.x
	    R W  gitolite-admin
	    R W  testing


#### 4. Configuration in OpenProject

Run OpenProject, go to **Admin > Plugins > OpenProject Revisions/Git** (click on configure)

Alter you configuration for Gitolite (Gitolite path, gitolite-admin.git path, etc.) accordingly and click save.

#### 5. Using delayed_job

This plugin optionally allows to use delayed_jobs to run interactions with ``gitolite-admin.git`` asynchronously.
If you activate that feature in the setting (c.f., 'Use delayed_job'): Start the worker using this command (change ``RAILS_ENV``, if necessary) :

```
RAILS_ENV=production script/delayed_job start
```

[See the documentation of delayed_job for further options](https://github.com/collectiveidea/delayed_job#running-jobs).

#### 6. Config Test

Check that the output on the tab 'Config Test' looks good.
Note that many of the settings are not yet functional, and some values on config test are thus irrelevant (Hooks, for example).

## Basic Usage

#### Managing SSH keys

1. Log in, go to My Account (top right).
2. Select 'Public Keys' in the menu on the left.
3. Add/Manage your public key using the form.

#### Managing repositories

1. Create project.
2. Go to repositories settings and select Git + click create. This should automatically create the corresponding entry in the gitolite configuration.
3. Use members to add a member to the repository. If that user has a public key on record, the corresponding access rights will be written to Gitolite.


## Copyrights & License
OpenProject Revisions/Git is completely free and open source and released under the [MIT License](https://github.com/oliverguenther/openproject_revisions_git/blob/devel/LICENSE).

Copyright (c) 2014 Oliver Günther (mail@oliverguenther.de)

This plugin bases on the [Redmine Git Hosting plugin by Nicolas Rodriguez](https://github.com/jbox-web/redmine_git_hosting)

Copyright (c) 2013-2014 Nicolas Rodriguez (nrodriguez@jbox-web.com), JBox Web (http://www.jbox-web.com)

Copyright (c) 2011-2013 John Kubiatowicz (kubitron@cs.berkeley.edu)

Copyright (c) 2010-2011 Eric Bishop (ericpaulbishop@gmail.com)

Copyright (c) 2009-2010 Jan Schulz-Hofen, Rocket Rentals GmbH (http://www.rocket-rentals.de)
