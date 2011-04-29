#!/usr/bin/perl
#
#-------------------------------------------------------------------
#
# Versioning header.
#
# $Id$
#-------------------------------------------------------------------

my $VERSION="0.32.0";
my $PKGNAME="Linux OSF";

sub print_header {

    my $width = 50;
    my $logr  = get_logger();

    INFO("\n");
    INFO("-"x $width . "\n");
    INFO("TACC $PKGNAME: Version = $VERSION\n");
    INFO("-"x $width . "\n");
    INFO("\n");
}

1;
