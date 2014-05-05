Summary: A Linux operating system framework for managing HPC clusters
Name: losf
Version: 0.46.0
Release: 1
License: GPLv2
Group: System Environment/Base
BuildArch: noarch
URL: https://github.com/hpcsi/losf 
Source0: %{name}-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

%{!?prefix: %define prefix /opt/losf-%{version}}

provides: perl(LosF_node_types)
provides: perl(LosF_rpm_topdir)
provides: perl(LosF_rpm_utils)
provides: perl(LosF_utils)
provides: perl(LosF_history_utils)

requires: yum-plugin-downloadonly

%define __spec_install_post %{nil}
%define debug_package %{nil}
%define __os_install_post %{_dbpath}/brp-compress

%description

LosF is designed to provide a lightweight configuration management system
designed for use with high-performance computing (HPC) clusters. Target users
for this package are HPC system administrators and system architects who desire
flexible command-line utilities for synchronizing various host types across a
cluster.

%prep
%setup -q 

%build
# Binary pass-through - empty build section

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p %{buildroot}/%{prefix}
cp -a * %{buildroot}/%{prefix}

%clean
rm -rf $RPM_BUILD_ROOT


%post

# Update losf soft link to latest version and inherit config_dir from most
# recent install. Use -c option to clean up previous config_dir file for clean
# RPM upgrades.

$RPM_INSTALL_PREFIX/misc/config_latest_install -c -q

%postun

# Following occurs when removing last version of the package. Clean up soft
# link and config_dir.

if [ "$1" = 0 ];then
    top_dir=$(dirname $RPM_INSTALL_PREFIX)
    if [ -L $top_dir/losf ];then
	rm $top_dir/losf
    fi

    if [ -s $RPM_INSTALL_PREFIX/config/config_dir ];then
	rm $RPM_INSTALL_PREFIX/config/config_dir
    fi
fi


%files
%defattr(-,root,root,-)
%{prefix}


%changelog
* Sat May  3 2014  <karl@maclinux1.localdomain> - 
- Initial build.

