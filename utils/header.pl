#!/usr/bin/perl
#
#-------------------------------------------------------------------
#
# Versioning header.
#
# $Id: node_types.sh 151 2009-10-20 02:44:48Z karl $
#-------------------------------------------------------------------

my $VERSION="0.30.0";
my $PKGNAME="Linux OSF";

#print_header();

sub print_header {

    my $width = 50;
    my $logr  = get_logger();

    INFO("\n");
    INFO("-"x $width . "\n");
    INFO("TACC $PKGNAME: Version = $VERSION\n");

#    print "-"x $width . "\n";
}

1;
