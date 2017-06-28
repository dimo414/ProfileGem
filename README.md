# ProfileGem

*A shell configuration utility to compartmentalize and manage your terminal utilities and
environment*

ProfileGem provides a structured and modular way to configure your terminal, as a more robust
alternative to editing `.bashrc` or `.bash_profile` directly. At a basic level, it uses dedicated
files to define aliases, functions, environment variables, commands to execute at login, and cron
jobs. More powerfully, this behavior can be split into separate parts, called gems, to
compartmentalize and customize your environment based on the needs of the user/machine being used.

On its own ProfileGem doesn't change your environment in any way (excluding adding some ProfileGem
utility functions). Instead, you create or install one or more gems alongside it which are then
loaded by ProfileGem to customize your environment just the way you want it.

---

## Example Uses

* You have a series of personal aliases, functions, and configurations you like to use across multiple
  machines.
* Your team has a set of utilities everyone regularly uses and wants to keep in sync.
* You need to configure your shell differently depending on the current project you're working on,
  but want to easily switch between configurations when you change projects.
* You want to load up your personal, team, and project configurations together, giving you exactly
  the shell you need *right now*.

## Getting Started

1. Checkout ProfileGem to your machine (`~/ProfileGem` is suggested).

1. Drop any gems you'd like to use into the ProfileGem directory. A future update may allow for
   automatic checkouts, but presently you must create/checkout gems manually. Once in place,
   ProfileGem can update them all together for you.
1. To create a new gem, copy the `template` directory to a new `*.gem` directory:

        cp -R template myshell.gem

1. Copy `template.conf.sh` to `local.conf.sh` and edit it, adding `#GEM` lines (e.g. `#GEM myshell`
   for a `myshell.gem` directory) for each gem you've installed. This lets you control the order in
   which gems are loaded. You can also specify any local environment variables here to further
   configure your gems' behavior.

1. Run `~/ProfileGem/load.sh` and confirm no errors / unexpected output. You can also run it in
   debug mode with `_PGEM_DEBUG=true ~/ProfileGem/load.sh` to get more detailed output.

1. Add a call to `load.sh` in your `.bashrc`/`.bash_profile` file:

        source ~/ProfileGem/load.sh

   And you're good to go! When you open a new terminal window ProfileGem will run, executing
   all your installed gems. You can also run the above command in a running terminal to load
   ProfileGem manually; this is really helpful for loading "your" terminal temporarily on
   another machine.

## Using ProfileGem

Once configured, there should be little you need to do with ProfileGem directly, however
there are some features worth knowing about:

* `_PGEM_DEBUG=true`: Set this, either in `~/.bashrc` or inline (e.g.
  `_PGEM_DEBUG=true ~/ProfileGem/load.sh`) to output debug messages when ProfileGem is loading.
* `pgem_reload`: If you make a change to any of your gems or your config file, you can reload it by
  running `pgem_reload`.
* `pgem_update`: Updates ProfileGem and all checked out gems from their parent repositories and
  then reloads them.
* `pgem_info`: List installed gems. Run `pgem_info GEM_NAME` to display more detailed information
  about that gem, if available.
* `pgem_help`: Outputs ProfileGem's usage information.


### Customizing With `local.conf.sh`

In addition to specifying the gems to load (and their order), many gems can be further customized
by settings in `local.conf.sh`. Each gem defines a `base.conf.sh` file which contains defaults
that you can override in `local.conf.sh`. For instance, you might have a gem that customizes your
prompt but allows the user to specify the hostname's color. Rather than needing to manually update
the `PS1` on each machine, you just update a variable in your `local.conf.sh`, so it might look
like this:

    #GEM myshell
    HOST_COLOR=RED

The `myshell.gem` will configure the `$PS1` but use the overridden `$HOST_COLOR`. Now each machine
you use can have a custom prompt with no fuss.

## Public Gems

Some gems you can install right away:

* [prompt.gem](https://bitbucket.org/dimo414/prompt.gem): installs a clean and extensible prompt.
* [util.gem](https://bitbucket.org/dimo414/util.gem): several helpful and non-invasive utilities.

## Creating A Gem

A gem template is available in `ProfileGem/template`; to create your own, simply copy it to a
`.gem` directory, e.g. `cp -R template myshell.gem` - you can easily drop your desired behavior
into the appropriate files of your new gem and (after updating `local.conf.sh`) ProfileGem will
load it. For more details on how to create a gem, particularly regarding how to ensure your gem
interacts safely with other gems, see the [README](/template/README.md) in the `template`
directory, and the comments in the individual template files.

## Copyright and License

Copyright 2012-2017 Michael Diamond

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
