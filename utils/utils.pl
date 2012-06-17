#!/usr/bin/perl
#-----------------------------------------------------------------------bl-
#--------------------------------------------------------------------------
# 
# LosF - a Linux operating system Framework for HPC clusters
#
# Copyright (C) 2007,2008,2009,2010 Karl W. Schulz
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the Version 2 GNU General
# Public License as published by the Free Software Foundation.
#
# These programs are distributed in the hope that they will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc. 51 Franklin Street, Fifth Floor, 
# Boston, MA  02110-1301  USA
#
#-----------------------------------------------------------------------el-
#
# Utility Functions
#
# $Id$
#--------------------------------------------------------------------------

#package utils;
use OSF_paths;
use base 'Exporter';
use lib "$osf_log4perl_dir";
use Sys::Syslog;  
use Switch;

#@EXPORT = qw(verify_sw_dependencies
#	     get_logger);

sub verify_sw_dependencies {
    verify_log4perl_availability();
}

sub verify_log4perl_availability {

    eval { require Log::Log4perl; };
  
    if($@) {
	print "\n[Error] The Log4perl module is not available in your local installation.\n";
	print   "[Error] Please verify that it was built and installed correctly during the\n";
	print   "[Error] configuration process.\n\n";
	exit(1);
    } else {

	if(! Log::Log4perl->initialized()) {
	    no warnings;
	    use Log::Log4perl qw(:easy);
	    Log::Log4perl->easy_init({level  => $INFO,
				      layout => "%m",
				      file   =>  'STDOUT'});
	    my $logr = get_logger();
	    DEBUG("Log4perl is available\n");
	}
    }
}

sub verify_file_exists {
    my $filename = shift;

    if ( ! -e $filename ) {
	MYERROR("The following file is not accessible: $filename",
		"Please verify availability.\n");
    }
}

sub ask_user_for_yes_no {

    my $prompt   = shift;
    my $flag     = shift;

    # Flag = 1 -> only look for yes/no responses
    # Flag = 2 -> lood for yes/no, and -1 responses

    print "\n[LosF] $prompt";
    chomp(my $line = <STDIN>);

    my $response = verify_yes_no_response($line,$flag);

    if( $response > -10 ) {
	return $response;
    }

    # Ask again if dodgy response

    print "\n[LosF] Unknown response->  $prompt";

    chomp(my $line = <STDIN>);
    my $response = verify_yes_no_response($line,$flag);

    if( $response > -10 ) {
	return $response;
    }

    # dude, get it right. 3rd time is a charm....?

    print "\n[LosF] Unknown response-> $prompt";

    chomp(my $line = <STDIN>);
    my $response = verify_yes_no_response($line,$flag);

    if( $response > -10 ) {
	return $response;
    } else  {
	MYERROR("Unable to validate user response; terminating...");
    }
}

sub verify_yes_no_response {
    my $response = shift;
    my $flag     = shift;   

    # Flag = 1 -> only look for yes/no responses
    # Flag = 2 -> lood for yes/no, and -1 responses

    if ( $response eq "Yes" ) {
	return 1;
    } elsif( $response eq "YES" ) {
	return 1;
    } elsif( $response eq "yes" ) {
	return 1;
    } elsif( $response eq "y" ) {
	return 1;
    } elsif( $response eq "Y" ) {
	return 1;
    } elsif( $response eq  "no" ) { 
	return 0;
    } elsif( $response eq  "NO" ) { 
	return 0;
    } elsif( $response eq  "No" ) { 
	return 0;
    } elsif( $response eq  "n" ) { 
	return 0;
    } elsif( $response eq  "N" ) { 
	return 0;
    } elsif( $flag == 2 && $response eq  "-1" ) { 
	return -1;
    } else {
	return -10; 
    }
}

sub MYERROR {

    ERROR("\n");
    foreach (@_) {
	ERROR("[ERROR]: $_\n");
    }
    ERROR("\n");
    exit(1);
}

sub SYSLOG {
    openlog(losf,'',LOG_LOCAL0);
    syslog(LOG_INFO,$_[0]);
    closelog;
}				

sub begin_routine {

    my $logr     = get_logger();
    my $routine  = (caller(1))[3];
    my $filename = (caller(1))[1];

    DEBUG("\n");
    DEBUG("--------------------- Routine START ---------------------\n");
    DEBUG("$routine ($filename)\n");
    DEBUG("\n");
}


sub end_routine {

    my $logr     = get_logger();
    my $routine  = (caller(1))[3];
    my $filename = (caller(1))[1];

    DEBUG("\n");
    DEBUG("$routine ($filename)\n");
    DEBUG("---------------------- Routine END ----------------------\n");
    DEBUG("\n");
}

sub print_var_stdout {
    begin_routine();
    
    my $var = shift;
    my $val = shift;

    print "<TACC-LOSF>$var=$val\n";

    end_routine();
}

sub expand_text_macros {
    begin_routine();

    my $file_in  = shift;
    my $file_out = shift;
    my $cluster  = shift;

    # @losf_synced_file_notice@ 

    my $template = "$osf_top_dir/config/const_files/$cluster/notify_header";

    if ( -s "$template" ) {
	DEBUG( "   --> notify_header file available\n");
	expand_individual_macro($file_in,$file_out,$template,"\@losf_synced_file_notice\@");
    } else {
	copy($file_in,$file_out) || die "Copy failed: $!";
    }


    end_routine();
}

sub expand_individual_macro {
    begin_routine();

    my $file_in  = shift;
    my $file_out = shift;
    my $template = shift;
    my $keyword  = shift;

    open($TEMPLATE,"<$template") || die "Cannot open $template\n";
    open($IN,      "<$file_in")  || die "Cannot open $file_in\n";
    open($OUT,     ">$file_out") || die "Cannot create $file_out\n";

    @expand_text = <$TEMPLATE>;

    # update text with any other supported macro's

    foreach(@expand_text) {
	s/\@losf_synced_file_location\@/$file_in/
    }

    while( $line = <$IN>) {
	if( $line =~ m/$keyword/ ) {
	    DEBUG(   "--> found a text macro...\n");
	    print $OUT @expand_text;

	} else {
	    print $OUT $line;
	}
    }

    close($TEMPLATE);
    close($IN);
    close($OUT);
    end_routine();
}

1;

