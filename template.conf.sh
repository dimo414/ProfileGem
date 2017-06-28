#!/bin/bash
# 
# Core config file used to specify which gems should be loaded, and
# apply any local config settings to those gems.
# Can either be placed in the ProfileGem root directory as 'local.conf.sh'
# or in a conf.d directory as either $USERNAME.sh or $HOSTNAME.sh (in
# the users or hosts directory, respectively).
# 
# Example structure is below, replace with references to the gems you wish to load
# The critical line is the line beginning with '#GEM' - this specifies a gem to be
# loaded by ProfileGem.  The remainder of the file is a simple bash script, you're
# suggested to organize the file into #GEM comments followed by settings related
# to that gem - generally overriding values in that gem's base.conf.sh.
# 

#GEM personal
LOCAL_SETTING=true

#GEM company
TEAM_NAME=ops
