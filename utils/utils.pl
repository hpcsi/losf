#!/usr/bin/env perl
#-----------------------------------------------------------------------bl-
#--------------------------------------------------------------------------
# 
# LosF - a Linux operating system Framework for HPC clusters
#
# Copyright (C) 2007-2015 Karl W. Schulz <losf@koomie.com>
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
# Various support utility functions
#--------------------------------------------------------------------------

use LosF_paths;
use base 'Exporter';
use Sys::Syslog;  
use Fcntl qw(:flock);
use File::Find;
use Sys::Hostname;

# Global vars to count any detected changes

use vars qw($losf_const_updated     $losf_const_total);
use vars qw($losf_softlinks_updated $losf_softlinks_total);
use vars qw($losf_services_updated  $losf_services_total);

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

    # Check environment variable which allows for user to assume yes.

    if( $ENV{'LOSF_ALWAYS_ASSUME_YES'} ) {
	INFO("Assuming yes for user interaction\n");
	return 1;
    }

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

sub ask_user_for_integer_input {

    my $prompt      = shift;
    my $min_allowed = shift;
    my $max_allowed = shift;

    print "\n[LosF] $prompt";
    chomp(my $line = <STDIN>);

    my $response = verify_integer_response($line,$min_allowed,$max_allowed);

    if( $response > -10 ) {
	return $response;
    }

    # Ask again if dodgy response

    print "\n[LosF] Unknown response->  $prompt";

    chomp(my $line = <STDIN>);
    my $response = verify_integer_response($line,$min_allowed,$max_allowed);

    if( $response > -10 ) {
	return $response;
    }

    # dude, get it right. 3rd time is a charm....?

    print "\n[LosF] Unknown response-> $prompt";

    chomp(my $line = <STDIN>);
    my $response = verify_integer_response($line,$min_allowed,$max_allowed);

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

sub verify_integer_response {
    my $response = shift;
    my $min      = shift;   
    my $max      = shift;   

    if ( $response ge $min && $response le $max ) {
	return 1;
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

sub MYERROR_NE {
    foreach (@_) {
	ERROR("[ERROR]: $_\n");
    }
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

sub expand_text_macros {
    begin_routine();

    my $file_in  = shift;
    my $file_out = shift;
    my $cluster  = shift;

    # @losf_synced_file_notice@ 

    my $template = "$losf_custom_config_dir/const_files/$cluster/notify_header";

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

sub notify_local_log() {

    # per request from mclay - create a notification file that is also
    # world readable with appliance name in it.

    my $save_dir_external = "/tmp";
    my $save_dir          = "/tmp/losf";
    my $host              = `hostname`;
    my $date              = `date`;
    my $epoch             = `date +%s`;

    chomp($host);
    chomp($date);
    chomp($epoch);

    if( ! -d $save_dir_external ) {
	ERROR("Unable to save external update notification - $save_dir_external must exist\n");
    } else {
	open(LOGFILE,">$save_dir_external/losf_last_update")  || 
	    die "Cannot create $save_dir_external/losf_last_update";

	print LOGFILE "nodeType   = $node_type\n";
	print LOGFILE "hostName   = $host\n";
	print LOGFILE "lastUpdate = $date\n";
	print LOGFILE "timeEpoch  = $epoch\n";

	close(LOGFILE);

	# file is world readable - let user decide on top-level path

	chmod (0644,"$save_dir_external/losf_last_update");


    }

    if ( ! -d $save_dir ) {
	INFO("Creating $save_dir directory to store local_log output\n");
	mkdir($save_dir,0700)
    }

    open(LOGFILE,">$save_dir/last_update")  || die "Cannot create $save_dir/last_update";

    print LOGFILE "$host updated on $date\n";
    print LOGFILE "-------------------------------------------------------------------------\n";

    if($losf_const_updated)      { print LOGFILE "$losf_const_updated const file(s) changed\n"; }
    if($losf_softlinks_updated)  { print LOGFILE "$losf_softlinks_updated soft link(s) changed\n"; }
    if($losf_os_packages_updated){ print LOGFILE "$losf_os_packages_updated OS package(s) changed\n"; }
    if($losf_custom_packages_updated){ print LOGFILE "$losf_custom_packages_updated Custom package(s) changed\n"; }
    if($losf_services_updated){ print LOGFILE "$losf_services_updated runtime service(s) changed\n"; }
    if($losf_permissions_updated){ print LOGFILE "$losf_permissions_updated file permission(s) changed\n"; }

    print LOGFILE "-------------------------------------------------------------------------\n";

    close(LOGFILE);
}

sub losf_get_lock() {
    begin_routine();

    my $lockFile = "/tmp/.losf_lock__";

    # If a parent process already has a lock, we return. Otherwise,
    # grab a lock. This allows losf commands to call themselves
    # recursively.

    if ( $ENV{'LOSF_LOCK'}  eq "TRUE" ) { 
	our $LOSF_LOCK++;
	return;
    }

    open($LOSF_FH_lock, ">$lockFile") || MYERROR("Unable to open $lockFile\n");

    if (! flock($LOSF_FH_lock,LOCK_EX|LOCK_NB))  {
	ERROR("\n[ERROR]: Unable to obtain local lock for LosF...\n\n");
	ERROR("Please verify no other instance is running locally and try again.\n");
	exit(23);
    }

    $ENV{'LOSF_LOCK'} = 'TRUE';
    our $LOSF_LOCK=0;
    DEBUG("flock obtained\n");
    end_routine();
}

sub losf_release_lock() {

    if($LOSF_LOCK > 0 ) {
	$LOSF_LOCK--;
	return;
    }

    close($LOSF_FH_lock);
}

# check_distro() - map Linux release to underlying package manager

sub check_distro() {
    my $release_dir       = "/etc";
    my %supported_distros = (
	'SuSE-release'   => 'zypper',
	'centos-release' => 'yum',
	'fedora-release' => 'yum',
	'redhat-release' => 'yum',
	);

    foreach (keys %supported_distros) {
	if ( -e "$release_dir/$_" ) {
	    return($supported_distros{$_});
	}
    }

    if($found > 1) {
	MYERROR("Unable to determine unique Linux distro at __LINE__");
    }
}

# --------------------------------------------------------------------
# check_for_package_manager() - verifies underlying package manager is
# available
# --------------------------------------------------------------------

sub check_for_package_manager {

    my $pkg_manager = check_distro();
    my $check_pkg   = $pkg_manager;
    my $losf_option = shift;

    INFO("   --> Underlying package manager = $pkg_manager\n");

    my @igot = is_rpm_installed($check_pkg);

    if ( @igot  eq 0 ) {
	MYERROR("The $check_pkg rpm must be installed locally in order to use \"losf $losf_option\" functionality");
    }

    # Check for old/new versions of yum (newer versions have downloadonly built in - older versions require a plugin)
    if($pkg_manager eq "yum") {
	my @version = split('\.',$igot[1]);
	if($version[0] >= 3 && $version[1] >= 4) {
	    DEBUG("   --> yum version is >= 3.4\n");
	    $pkg_manager = "yum";
	} else {
	    DEBUG("   --> yum version is < 3.4\n");
	    $check_pkg = "yum-plugin-downloadonly";
	    my @igot = is_rpm_installed($check_pkg);

	    if ( @igot  eq 0 ) {
		MYERROR("The $check_pkg rpm must be installed locally in order to use \"losf $losf_option\" functionality");
	    }
	}
    }

    return($pkg_manager);
}

# ----------------------------------------------------------------
# check_chroot_option() - returns package manager chroot option if
# chroot is enabled
# ----------------------------------------------------------------

sub check_chroot_option {

    my $chroot      = shift;
    my $pkg_manager = shift;

    if($chroot eq "") { 
	return($chroot); 
    } else {
	if($pkg_manager eq "yum") {
	    return("--installroot=$chroot");
	} elsif($pkg_manager eq "zypper") {
	    return("--root=$chroot");
	} else {
	    MYERROR("Unknown package manager at ".__FILE__ . __LINE__ ."\n");
	}	
    }
}

# ----------------------------------------------------------------
# download_os_package() - downloads OS package (and dependencies)
# using underlying package manager.
# ----------------------------------------------------------------

sub download_os_package {

    my $chroot_option = shift;
    my $pkg_manager   = shift;
    my $package_name  = shift;
    my $tmpdir        = shift;
    my $mode          = shift;

    my $cmd="";

    if($pkg_manager eq "yum") {
	$cmd="yum -y $chroot_option -q --downloadonly --downloaddir=$tmpdir $mode $package_name >& /dev/null";
	DEBUG("   --> Running yum command \"$cmd\"\n");
    }
    elsif($pkg_manager eq "zypper") {

	if($mode eq "upgrade") {
	    $mode = "update";
	}

	$cmd="zypper -n $chroot_option --pkg-cache-dir $tmpdir $mode --download-only $package_name";
	DEBUG("   --> Running zypper command \"$cmd\"\n");
    } else {
	MYERROR("Unknown package manager at ".__FILE__ . __LINE__ ."\n");
    }

   `$cmd`;

    # Check to see if we downloaded anything

    my @rpms_downloaded = ();

    if($pkg_manager eq "yum") {
	@rpms_downloaded = <$tmpdir/*>;
    } elsif($pkg_manager eq "zypper") {
	find ( sub {
	    return unless -f;        # Must be a file
	    return unless /\.rpm$/;  # Must end with .rpm suffix
	    push @rpms_downloaded, $File::Find::name;
	       }, $tmpdir );
    } else {
	MYERROR("Unknown package manager at ".__FILE__ . __LINE__ ."\n");
    }

    return(@rpms_downloaded);
}

# -------------------------------------------------------------
# download_os_group() - downloads OS group (and dependencies)
# using underlying package manager.
# -------------------------------------------------------------

sub download_os_group {

    my $chroot_option = shift;
    my $pkg_manager   = shift;
    my $group_name    = shift;
    my $tmpdir        = shift;

    my $cmd="";

    if($pkg_manager eq "yum") {
	$cmd="yum -y $chroot_option -q --downloadonly --downloaddir=$tmpdir groupinstall $group_name >& /dev/null";
	DEBUG("   --> Running yum command \"$cmd\"\n");
    }
    elsif($pkg_manager eq "zypper") {
	$cmd="zypper -n $chroot_option --pkg-cache-dir $tmpdir install --download-only -t pattern $group_name";
	DEBUG("   --> Running zypper command \"$cmd\"\n");
    } else {
	MYERROR("Unknown package manager at ".__FILE__ . __LINE__ ."\n");
    }

   `$cmd`;

    # Check to see if we downloaded anything

    my @rpms_downloaded = ();

    if($pkg_manager eq "yum") {
	@rpms_downloaded = <$tmpdir/*>;
    } elsif($pkg_manager eq "zypper") {
	find ( sub {
	    return unless -f;        # Must be a file
	    return unless /\.rpm$/;  # Must end with .rpm suffix
	    push @rpms_downloaded, $File::Find::name;
	       }, $tmpdir );
    } else {
	MYERROR("Unknown package manager at ".__FILE__ . __LINE__ ."\n");
    }

    return(@rpms_downloaded);
}

# -------------------------------------------------------------
# requires_chroot_environment() - tests if the running host and
# and $node_type requires running in an chroot environment
# -------------------------------------------------------------

sub requires_chroot_environment {

    if($LosF_provision::losf_provisioner eq "Warewulf") {
	if($node_type eq "master") {
	    return 0;		# no chroot for master host
	} elsif($exec_node_type eq "master") {
	    return 1;		# chroot if execution host is master
	} else {
	    return 0;		# no chroot needed if not executing on master host
	}
    } else {
	return 0;
    }

}

# -------------------------------------------------------------
# print_version() - echo versioning info to stdout
# -------------------------------------------------------------

sub print_version {

    my $width = 24;
    my $ver   = "";

    if ( ! -e "$losf_top_dir/VERSION" ) {
	die("Unable to obtain version...please verify local LosF install");
    } else {
	open ($IN,"<$losf_top_dir/VERSION") || die("Unable to open VERSION file");
	$ver = <$IN>;
	chomp($ver);
	close($IN);
    }

    print "\n";
    print "-"x $width . "\n";
    print "LosF: Version $ver\n";
    print "-"x $width . "\n";
    print "\n";

} # end sub print_version()

# -------------------------------------------------------------
# query local hostname/domainname
# -------------------------------------------------------------

sub query_local_network_name {

    my @hostTmp     = split(/\./,hostname);
    my $hostname    = shift(@hostTmp);
    my $domain_name = join("\.", @hostTmp);

    # revert to backup approach using dnsdomainname if domain_name
    # fails to resolve from above

    if($domain_name eq "") {
        chomp($domain_name=`dnsdomainname 2> /dev/null`);
    }

    if($hostname eq "" || $domain_name eq "" ) {
        ERROR("\n");
        ERROR("ERROR: Unable to determine local host name.\n\n");
        ERROR("LosF uses a hostname and fully qualified domainname (FQDN) to differentiate \n");
        ERROR("between node types. Please update you local network configuration to provide a FQDN.\n\n");
        exit 1;
    }

    return($hostname,$domain_name);

} # end sub query_local_network_name()

1;

