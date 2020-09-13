# Creating Your Own Gem

ProfileGem works by
[sourcing](http://www.tldp.org/HOWTO/Bash-Prompt-HOWTO/x237.html) several files
from each gem in a specified order. This directory can copied to seed a new gem.
All the files are optional and can be deleted if unused. To get started, simply
copy this directory to a directory ending in `.gem` like so:

```shell
$ cp -R template personal.gem
$ echo '#GEM personal' >> local.conf.sh # to enable the gem
$ cd personal.gem
$ hg init
```

It is recommended you track your gem in a version control system to enable easy
deployment and editing. ProfileGem is compatible with Mercurial and Git by
default, but any VCS can be used to keep gems up to date and in sync.

## Aspects of a Quality Gem

You can easily define self-contained behavior in a new gem and be up and running
in minutes, but ProfileGem's true power comes from being able to share
functionality between different gems. Suppose for example one gem dynamically
generates aliases based on a configurable array; other gems can add to that
array, thereby expanding the functionality of the first gem. In order to safely
interweave behavior like this well-behaved gems are expected to follow certain
rules:

*   **Gems should be idempotent**: ProfileGem can be reloaded in the same shell
    by running `pgem_update` or `pgem_reload`. To support this it is important
    that gems do not make changes they cannot undo or re-invoke. Defining
    functions or aliases, for example, is idempotent (as re-defining them simply
    overwrites the previous definition). On the other hand modifying the file
    system or updating environment variables is not. For example, if a gem adds
    a directory to the `PATH`, re-invoking that gem will re-add that directory.
    To be safe gems should attempt to make as few non-idempotent changes as
    possible, and store enough information (such as an environment variable's
    initial value) to restore the system to how it was before the gem was
    loaded.

    Running `pgem_reload` or `pgem_update` in a debug shell (`_PGEM_DEBUG=true`)
    will print changes to the shell environment, so you can call
    `_PGEM_DEBUG=true pgem_reload` repeatedly to look for idempotency issues.

*   **Gems should be extensible**: Design your gems such that they can be
    expanded on by other gems. For instance, rather than hard-coding custom
    behavior, declare variables in `base.conf.sh` that configure the behavior,
    thereby allowing users and other gems to modify your gem's functionality.

    Suppose in one gem you want to define the classpath the `java` command runs
    with. It would be simple enough to define it explicitly, e.g. `alias
    java='java -cp lib/*'`. However this is not extensible, other gems can only
    update `java`'s classpath by re-defining the alias, potentially overwriting
    the existing behavior. Instead, split the behavior up into parts; define an
    array in `base.conf.sh`, then use that array to dynamically construct the
    alias in `aliases.sh`. This way, all gems loaded before yours can update the
    array (if it exists) in their respective `environment.sh` files without
    needing to modify the actual definition of the alias.

*   **Gems should be self-contained**: Gems should be able to expand upon
    behavior defined in other gems, but they should also not fail if loaded on
    their own. In the above example a gem might modify an array defined in
    another gem, but if the second gem is not actually loaded the first gem
    should still function as normal and need not report to the user that it
    couldn't configure the other gem.

*   **Gems should be fail-soft**: Going along with the above if a gem depends
    upon certain behavior in another gem which isn't loaded, or a certain
    program being on the `PATH`, it should degrade gracefully. For example if a
    set of aliases depend on `colordiff`, those aliases should not be declared
    unless `colordiff` is on the path:

    ```bash
    command -v colordiff >/dev/null && alias colordiff='colordiff -u'
    ```

    Depending on the specific use-case the gem should either silently leave the
    dependant behavior undefined define stub implementations that print a
    helpful message when the user attempts to execute these commands. In general
    gems should avoid reporting errors at load-time; gems should work (even if
    just partially) out of the box. There should not be any "mandatory"
    configuration.

    Note that this is a guideline, not a requirement. It's reasonable for a gem
    to report an error at load-time if the gem simply cannot function in the
    current environment (e.g. a theoretical ubuntu.gem shouldn't ever be
    installed on a Fedora system).

## Anatomy of a Gem Directory

The following files make up a standard gem, and are loaded in order into the
shell:

*   `base.conf.sh`: This file should contain all necessary settings to
    initialize a barebones version of the gem. Users will often look at the
    contents of this file to identify settings they can update in their
    `local.conf.sh` to enable further behavior. It's often a good idea to use
    array variables here so users (and other gems) can append to them, rather
    than primitive variables which can only be overwritten.
*   `environment.sh`: This file is loaded up after the user's config file has
    been sourced, meaning we're now ready to start configuring the shell. Use
    this file to manage or configure the shell's environment based on the user's
    settings.
*   `aliases.sh`: This file contains aliases, you might chose to define these
    dynamically based on values declared in `base.conf.sh`.
*   `functions.sh`: similar to `aliases.sh`, this file contains Bash functions.
    Often gems provide most of their functionality via this file.
*   `commands.sh`: Unlike the preceding files which are always loaded into the
    shell, this file is only executed if the shell is interactive, i.e. a human
    using a terminal.
*   `scripts/`: This directory, if it exists, is added to the shell `$PATH` and
    can be used to store larger scripts that don't belong in a function (or are
    written in another language).
