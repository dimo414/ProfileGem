#!/bin/bash
# 
# Default configuration file
# 
# A bash script to specify configuration settings
# to be used by the rest of the gem.  These can be overridden by additional
# configuration files, so avoid setting environment variables and the like
# here, instead define values which environment.sh will then use after all
# conf files have been loaded.
# 
# Looks for the following files, in order (later overrides earlier):
#   base.conf
#   ${HOSTNAME}.conf
#   ${USER}.conf
#   ${USER}.${HOSTNAME}.conf
#   local.conf
#
# This allows you to define username / hostname specific configuration settings
# which are tracked, or make temporary changes in local.conf, which should not be
# 