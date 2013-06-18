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
use Fcntl qw(:DEFAULT :flock);
use Data::Dumper;
use strict;
use warnings;

my %node_history        = ();
my $DATA_VERSION        = "1.0";
my $HOST_ENTRY_SIZE_1_0 = 5;
my $DATA_FILE="/admin/build/admin/hpc_stack/.losf_log_data";

use constant {
    CLOSE_ERROR   => 1,
    CLOSE_NOERROR => 2,
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
    
    if($flag != CLOSE_ERROR && $flag != CLOSE_NOERROR) {
	print "ERROR: unknown host close flag provided\n";
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

    lock_nstore [$DATA_VERSION,%node_history ], $DATA_FILE;
}

sub log_read_state_1_0
{
    # use locking retrieve to read latest state 

    ($DATA_VERSION,%node_history) = @{lock_retrieve ($DATA_FILE)};
}

sub log_dump_state_1_0
{

    print "-" x 94;
    print "--- DATA VERSION = $DATA_VERSION ---";
    print "\n";
    print "Hostname        Timestamp      E Action  Comment";
    print " " x 68;
    print "User\n";
    for my $key (keys %node_history) {
	my $num_entries = @{$node_history{$key}};
	
	my @value = @{$node_history{$key}};
	my $count =0;
	for($count=0;$count<$num_entries;$count+=$HOST_ENTRY_SIZE_1_0) {
	    printf("%-10s ", $key);
	    my $flag="";
	    if($value[$count+4] eq CLOSE_ERROR) {
		$flag="X";
	    }

	    printf("%-19s ",($value[$count+0]));    # timestamp
	    printf("%1s ",$flag);                   # error flag
	    printf("%6s ",($value[$count+1]));      # state
	    printf(" %-70s ",($value[$count+2]));   # comment
	    printf("%8s",  ($value[$count+3]));     # user
	    printf("\n");
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


# my %node_status  = ("c401-101" => 0, "c401-102" => 1, "c401-103" => 0);

# log_add_node_event("c401-101","open","just a test",1,"2013-01-07 08:30");
# log_add_node_event("c401-101","close","uh oh",2);
# log_add_node_event("c401-102","open","just a test2",1);

# log_save_state_1_0();
# log_clear_state();
# #####print Dumper(%node_history);
# log_read_state_1_0();
# log_dump_state_1_0();









