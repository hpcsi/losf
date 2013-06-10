# -*-sh-*-
#!/bin/bash
#----------------------------------------------------------------------
# LosF Software Updates
# 
# Utility to update individual cluster node types to latest production
# revision (or verify that a node is already in sync).
#
# $Id$
#----------------------------------------------------------------------
#
#
# Node type definitions are controlled via the LosF input files
# located in the top-level config/ directory.  To customize your
# cluster, you will want to create an update.<your-cluster-name> file
# to define desired RPM packages for each of your node definitions.  A
# template file is provided in update.template.
#
# Questions/Problems?: karl@tacc.utexas.edu
# Texas Advanced Computing Center 
#----------------------------------------------------------------------
#----------------------------------------------------------------------

# Command-line Inputs

# Inputs -------------------

export VERBOSE=0
export UPDATE_RPMS=1

# End Inputs -------------------

export TOP_DIR=`echo $( (cd -P $(dirname $0) && pwd) )`
export PERL5LIB=$TOP_DIR/utils
export MYHOST=`hostname -s`

usage()
{
  cat <<EOF

 LosF update utility: used to bring local node to latest 
 configuration status (via the installation/removal of desired
 packages and synchronization of configuration files and services).

 usage: update [OPTIONS]

 OPTIONS:
    -h          Show help message.
    -q          Quiet logging mode; shows detected system changes only.
    -p [path]   Override configured RPM source directory to prefer provided path instead.


EOF
}

RPM_OVERRIDE=

while getopts "hqp:" OPTION
do
    case $OPTION in
	h)
	    usage
	    exit 1
	    ;;
	p)
	    RPM_OVERRIDE=$OPTARG
	    ;;
	q)
	    export LOSF_LOG_MODE=ERROR
	    ;;
	?)
	    usage
	    exit
	    ;;
	esac
done

#----------------------------------------------------------------
# Perform LosF updates
#----------------------------------------------------------------

$TOP_DIR/utils/update.pl $RPM_OVERRIDE

#	q)
#	    export TACC_LOG_MODE=ERROR
#	    ;;

