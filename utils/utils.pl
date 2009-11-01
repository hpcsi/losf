#!/usr/bin/perl
#
# $Id$
#
#-------------------------------------------------------------------
#
# Utility Functions
#
# $Id$
#-------------------------------------------------------------------

#package utils;
use OSF_paths;
use base 'Exporter';
use lib "$osf_log4perl_dir";

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

sub MYERROR {

    ERROR("\n");
    foreach (@_) {
	ERROR("[ERROR]: $_\n");
    }
    ERROR("\n");
    exit(1);
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

1;

