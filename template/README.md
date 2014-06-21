# Creating Your Own Gem

This directory contains all the basic necessities to define your own gems.  To get started, simply copy this directory to a directory ending in `.gem`, e.g.:

    cp -R template myscripts.gem
    cd myscripts.gem
    hg init

It is recommended you track your gem in a VCS to enable easy deployment and editing.  ProfileGem is hooked into Mercurial and Git by default, but any VCS can be used to keep gems in sync.

## Aspects of a Quality Gem

You can easily define self-contined behavior in a new gem and be up and running in minutes, but ProfileGem's true power comes from being able to share functionality between different gems.  Suppose for example one gem defines convienent shortcuts for SSHing, other gems can then simply update a list of known machines, and now the first gem can create shortcuts for machines specified by these other gems.  In order to interweve behavior like this, well-behaved gems are expected to follow certain rules:

* **Gems should be idempotent**: ProfileGem can be updated repeadedly in the same shell by running `pgem_update` or `pgem_reload`.  To facilitate this, it is important that gems do not rely on the external state of the shell.  For example, if a gem updated `$PATH` by calling `PATH=$PATH:/extra/path/dir` repeated calls to `pgem_reload` would populate the `$PATH` with duplicate references to `/extra/path/dir`.  To avoid this, gems should set default values in `base.conf.sh` and avoid relying on data in exteral variables.  Where a gem does need to modify an existing environment variable, the initial value should be preserved and restored in subsequent calls to the gem.

    Running `pgem_reload` or `pgem_update` in a debug shell (`_PGEM_DEBUG=true`) will output changes to the shell environment, repeated calls should report no changes.

* **Gems should be extensible**: Design the behavior of your gems such that they can be expanded on by other gems.  For instance, rather than explicitly defining aliases or functions, have them depend on variables which can be updated by other gems.

    Suppose in one gem you want to define the classpath the `java` command runs with.  One option would be to define it explicitly, e.g. `alias java='java -cp lib/*'`.  However this is not extensible, other gems can only update `java`'s classpath by re-defining the alias, potentially overwriting the existing behavior.  Instead, split the behavior up into parts; define an array in `base.conf.sh`, then use that array to dynamically construct the alias in `aliases.sh`.  This way, all loaded gems can easily update the array in their respective `environment.sh` files without needing to modify the actual definition of the alias.

* **Gems should be self-contained**: Gems should be able to expand upon behavior defined in other gems, but they should simultanously not fail if loaded up on their own.  In the above example, a gem modifies an array defined in another gem - if the latter gem is not actually loaded the first gem should still function as normal; minus any functioanlity defined in the latter gem, of course.  So in the above example `java` will not be aliased, but other behavior defined in the gem should still function without issue.

* **Gems should be fail-soft**: Going along with the above, if a gem depends upon certain behavior in another gem which isn't loaded or machine state which could be misconfigured, it should degrade gracefully.  If a gem defines a series of functions which depend upon external behavior, those functions should be wrapped in a conditional, and only defined once the necessary behavior has been verified to exist.

    For example, suppose a set of functions and aliases depend upon a large dataset existing in `/var/mygem_data`.  If the dataset does not exist, the gem should still load cleany.  Depending on the specific use-case, the gem could either not define the dependant behavior, or output logical error messages when the user attempts to execute these commands.  In general, gems should avoid reporting errors or missconfigurations at load-time; a user should be able to check out a gem and immediately have access to the basic functionality of the gem.

## Anatomy of a Gem Directory

The following files make up a standard gem, and are loaded in order into the shell:

* `base.conf.sh`: This file should contain all necessary settings to initialize a barebones version of the gem.  Users will often look at the contents of this file to identify settings they can update in their `local.conf.sh` to enable further behavior.  Often consider using bash arrays here, so users (and other gems) can append to them.
* `environment.sh`: This file is loaded up after the user's config file has been parsed, meaning we're now ready to start configuring the shell.  Use this file to manage or configure the shell state based on the user's settings.
* `aliases.sh`: This file contains alises, either hard-coded or defined dynamically, such as by an array configured in the preceeding files.
* `functions.sh`: Like `aliases.sh`, this file contains useful functions.  It is genreally recommended that gem behavior be implemented in functions rather than standalone scripts.
* `scripts/`: This directory, if it exists, is added to the shell `$PATH`.
* `commands.sh`: Unlike the preceeding files, which are always loaded into the shell, this file is only executed if the shell is interactive, i.e. a human using a terminal.
* `jobs.txt`: File used to configure ProfileGem's deployable jobs, see the comments in the template file for the appropriate syntax.


