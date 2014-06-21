# ProfileGem

*A shell configuration utility to compartmentalize and deploy terminal utilities and state*

ProfileGem provides a structured way to configure your terminal, as a more robust alternative to editing `.bashrc` or `.bash_profile`.  At a basic level, it provides structured files to define aliases, functions, environment variables, commands to execute at login, and cron jobs.  More powefully, this behavior can be split into separate directories, called gems, to compartmentalize and customize shells based on the needs of the user/machine being used.

On its own, ProfileGem does (next to) nothing to your terminal.  Instead, you point it to one or more gems which contain the configuration settings you need.  These gems are executed in a defined order as your shell starts up, allowing you to create a custom shell experienced based on exactly the functionality you need.

---

## Example Uses

* You have a series of personal aliases, functions, and configurations you like to use on all your machines.
* Your team has a set of utilities everyone regularly uses and wants to keep in sync.
* You need to configure your shell differently depending on the current project you're working on, but want to easily switch between configurations when you change projects.
* You have a common set of cronjobs which rely on your shell configuration, or which you want to easily enable or disable on different machines.
* You want to load up your personal, team, and project configurations together, giving you exactly the shell you need *right now*.

## Getting Started

1. Checkout ProfileGem to your machine (`~/ProfileGem` is suggested).

1. Drop any gems you'd like to use into the ProfileGem directory.  A future update may allow for automatic checkouts, but presently you must create/checkout gems manually.  Once in place, they can be updated automatically by ProfileGem.  To create a new gem, copy the `template` directory to a new gem directory:

        cp -R template myshell.gem

1. Copy `template.conf.sh` to `local.conf.sh` and edit it, adding `#GEM` lines for any gems you have checked out, e.g. `#GEM myshell`.  Add any local environment variables to configure your gems here.

1. Run `~/ProfileGem/load.sh` and confirm no errors / unexpected output.  You can alternatively run `_PGEM_DEBUG=true ~/ProfileGem/load.sh` to get more detailed output, including listing all files which are loaded.

1. Source a call to `load.sh` in your `.bashrc`/`.bash_profile` file:

        . ~/ProfileGem/load.sh

    And you're good to go!  Your next shell instance will load ProfileGem at start.  You can also execute the above command in a running shell to load ProfileGem manually, for instance to temporarily deploy your shell on another machine.

## Using ProfileGem

Once configured, there should be little you need to do with ProfileGem directly, however there are some utilities worth knowing about:

* `_PGEM_DEBUG=true`: Set this, either in `~/.bashr` or inline (e.g. `_PGEM_DEBUG=true ~/ProfileGem/load.sh`) to output debug messages related to ProfileGem.
* `pgem_reload`: If you make a change to any of your gems or your config file, you can reload it by running `pgem_reload`.
* `pgem_update`: Updates ProfileGem and all checked out gems from their parent repositories and reloads them.
* `pgem_info`: Print basic usage information about each gem, this needs more functionality

### Customizing With `local.conf.sh`

In addition to specifying the gems to load (and their order), `local.conf.sh` lets you customize the behavior of gems.  Each gem defines a `base.conf.sh` file which contains default values you can update in your `local.conf.sh`.  For instance, a gem might configure your terminal prompt, but allow the user to specify the hostname's color; rather than needing to manually modify `$PS1` on each machine, your `local.conf.sh` might look like this:

    #GEM myshell
    HOST_COLOR=RED

Now `myshell.gem` will actually configure the `$PS1`, but use the locally specified `$HOST_COLOR`.

### Crontabs

ProfileGem includes an extensible cron deployment utility, allowing you to define useful jobs per-gem, then configure which jobs should be run per machine, and generate crontabs dynamically.

* `PGEM_JOBS=...`: Set this to a space-separated list of jobs ProfileGem is aware of to include these jobs in ProfileGem's generated crontab.
* `pgem_cron_info`: Outputs information about ProfileGem's cronjobs, particularly the PATH variable it will use, and the list of availible jobs to enable.
* `pgem_cron_out`: Prints the crontab to stdout for easy review.
* `pgem_cron_user`: Writes the ProfileGem cron jobs to the user's crontab, essentially `pgem_cron_out | crontab`.
* `pgem_cron_etc`: Writes the ProfileGem cron jobs to `/etc/cron.d/`, preserving the users crontab.

By default, all jobs are disabled, however any jobs specified in `$PGEM_JOBS` will be enabled for the current machine.  This allows gems to define complex or conflicting jobs internally, and let individual machines/users easily enable the jobs they need.

## Creating A Gem

A gem template is availible in `ProfileGem/template`, to create your own, simply copy it to a `.gem` directory, e.g. `cp -R template myscripts.gem` - you can easily drop your desired behavior into the appropriate files of your new gem and (after updating `local.conf.sh`) ProfileGem will load it.  For more details on how to create a gem, particularly regarding how to ensure your gem interacts safely with other gems, see the [README](/profilegem/src/tip/template/README.md) in the `template` directory, and the comments in the individual template files.