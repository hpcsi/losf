#!/usr/bin/perl
#-----------------------------------------------------------------------bl-
#--------------------------------------------------------------------------
# 
# LosF - a Linux operating system Framework for HPC clusters
#
# Copyright (C) 2007-2013 Karl W. Schulz
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

use Storable qw(store retrieve nstore nstore_fd lock_retrieve lock_nstore);
use Fcntl    qw(:DEFAULT :flock);
use Data::Dumper;
use File::Temp qw/tempfile/;
use strict;
use warnings;

my %node_history       = ();
my $DATA_VERSION        = "";
my $HOST_ENTRY_SIZE_1_0 = 5;
my $DATA_FILE="/admin/build/admin/hpc_stack/.losf_log_data";

use constant {
    OPEN_PROD       => 0,
    CLOSE_ERROR     => 1,
    CLOSE_NOERROR   => 2,
    DATA_VERSION1_0 => "1.0",
};

sub log_add_node_event
{
    my $host       = shift;
    my $action     = shift;
    my $comment    = shift;
    my $flag       = shift;

    my $timestamp;

    my $remain_args = @_;
    if ( $remain_args == 1) {
	$timestamp = shift;

	# validate timestamp (e.g. 2013-06-18 15:50)

	if ($timestamp !~ m/\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d/) {
	    print "ERROR: malformed user-provided timestamp: expect 24 hour date of the form -> 2013-06-18 15:50:42\n";
	    exit 1;
	}
    } else {
	$timestamp=`date +"%F %T"`;
    }

    chomp($timestamp);

    # determine running user

    my $local_user = getlogin();

    # validate action

    die("Unsupported action") if ( $action ne "close"   &&
				   $action ne "open"    && 
				   $action ne "comment");
    # validate flag
    
    if($flag != OPEN_PROD && $flag != CLOSE_ERROR && $flag != CLOSE_NOERROR) {
	print "ERROR: unknown host close flag provided ($flag)\n";
	exit 1;
    }

    # we have a good record, load->update

    if ( -s $DATA_FILE ) {
	log_read_state_1_0();
    }
    push @{$node_history{$host} },($timestamp,$action,$comment,$local_user,$flag);
    log_save_state_1_0();
}

sub log_save_state_1_0
{
    # use locking store to save state
    my $DATA_VERSION = DATA_VERSION1_0;

    lock_nstore [$DATA_VERSION,%node_history ], $DATA_FILE;
}

sub log_read_state_1_0
{
    # use locking retrieve to read latest state 

    ($DATA_VERSION,%node_history) = @{lock_retrieve ($DATA_FILE)};
}

sub log_check_for_closed_hosts()
{
    INFO("Checking for newly closed hosts ...\n");
    INFO("--> assuming SLURM batch system\n");

    log_read_state_1_0();

    (my $fh,my $tmpfile) = tempfile();

    DEBUG("--> tmpfile = $tmpfile\n");

    my $cmd="sinfo -h -R --format=\"%n %H %u \\\"%E\\\"\"> $tmpfile";

    DEBUG("--> query command = $cmd\n");
    system($cmd);

    open(INFILE,"<$tmpfile") || die ("Cannot open $tmpfile: $!");

    while (my $line = <INFILE> ) {

	# example line:
        # c445-003 2013-06-25T00:35:41 root "TACC: rebooting MIC"

	if ($line =~ m/(\S+) (\d\d\d\d-\d\d-\d\d)T(\S+) (\S+) \"(.+)\"/) {

	    my $dupl_entry = 0;
	    my $count      = 0;
	    my $host       = $1;
	    my $comment    = $5;
	    my $timestamp  = "$2 $3";

	    # check to see if we have logged this previously

	    DEBUG("  --> checking on log for $host\n");
	    
	    if( exists $node_history{$host}  ) {
		my @entries     = @{$node_history{$host}};
		my $num_entries = @entries;

		for($count=0;$count<$num_entries;$count+=$HOST_ENTRY_SIZE_1_0) {
		    if( $entries[$count+0] eq $timestamp) {
			DEBUG("      --> Skipping duplicate timestamp....\n");
			$dupl_entry = 1;
			last;
		    }
		}

		if($dupl_entry == 1) {
		    next;
		} else {
		    INFO("Adding unmatched log entry for $host\n");
		    log_add_node_event($host,"close","$comment",CLOSE_ERROR,"$2 $3");
		}
		exit 1;
	    } else {
		DEBUG("      --> no log entries present\n");
	        # TACC: rebooting MIC 

		# we skip MIC reboots for now...
		
		if($comment eq "TACC: rebooting MIC") {
		    DEBUG("      --> Skipping MIC reboot....\n");
		    next;
		}
		
		INFO("Adding unmatched log entry for $host\n");
		log_add_node_event($host,"close","$comment",CLOSE_ERROR,"$2 $3");
	    }
	}

    }

    close(INFILE);
    unlink($tmpfile);

}

sub log_dump_entry_1_0 
{
    my $host        = shift;
    my @entries     = @_;
    my $num_entries = @entries;

    my $count =0;
    for($count=0;$count<$num_entries;$count+=$HOST_ENTRY_SIZE_1_0) {

	printf("%-10s ", $host);
	my $flag="";

	if($entries[$count+4] eq CLOSE_ERROR) {
	    $flag="X";
	}
	
	printf("%-19s ", ($entries[$count+0]));    # timestamp
	printf("%1s ",   $flag);                   # error flag
	printf("%6s ",   ($entries[$count+1]));    # state
###	printf(" %-70s ",($entries[$count+2]));    # comment
	my $padded = pack("A70",$entries[$count+2]);
	printf(" %-70s ",$padded);                 # comment
	printf("%8s",    ($entries[$count+3]));    # user
	printf("\n");
    }
    
}

sub log_dump_state_1_0
{

    log_read_state_1_0();

    # check if specific host requested?

    my $desired_host="";

    my $remain_args = @_;
    if ( $remain_args == 1) {
	$desired_host = shift;
    }

    # header

    print "-" x 94;
    print "--- DATA VERSION = $DATA_VERSION ---";
    print "\n";
    print "Hostname        Timestamp      E Action  Comment";
    print " " x 68;
    print "User\n";

    # raw log results

    if($desired_host ne "" ) {
	log_dump_entry_1_0($desired_host,@{$node_history{$desired_host}} );
    } else  {
	for my $key (keys %node_history) {
	    log_dump_entry_1_0($key,@{$node_history{$key}} );
	}
    }

    print "-" x 120;
    print "\n";
}

sub log_clear_state 
{
    $DATA_VERSION = "";
    %node_history = ();
}

###sub log_ingest_raw_data
###{
###    # for internal use to load log from raw file 
###
###    my $datafile = "/admin/build/data/slurm_logs/losf_data_ingest.production2";
###
###    log_clear_state();
###
###    open(INFILE,"<$datafile") || die ("Cannot open $datafile: $!");
###
###    while (my $line = <INFILE> ) {
###	# CLOSE 2012-07-01 15:18:16 batch1 slurm "not responding"
###
###	if ($line =~ m/(OPEN|CLOSE) (\S+) (\S+) (\S+) (\S+) (.+)$/) {
###	    if ($1 eq "CLOSE" ) {
###		push @{$node_history{$4} },("$2 $3",$1,$6,$5,CLOSE_ERROR);
###	    } else {
###		push @{$node_history{$4} },("$2 $3",$1,$6,$5,0);
###	    }
###	}    
###    }
###
###    log_save_state_1_0();
###}
###
###log_ingest_raw_data();
###
