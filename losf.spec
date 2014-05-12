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
mkdir -p %{buildroot}/etc/profile.d
cp -a * %{buildroot}/%{prefix}

# Remove separate test dir to minimize dependencies

rm -rf %{buildroot}/%{prefix}/test

# shell login scripts

%{__cat} << EOF > %{buildroot}/etc/profile.d/losf.sh
#!/bin/sh

# Setup default path for LosF

LOSF_DIR=%{prefix}
TOP_DIR=\`dirname \${LOSF_DIR}\`

if [ -h \${TOP_DIR}/losf ];then
   export PATH=\${TOP_DIR}/losf:\${PATH}
elif [ -d \${LOSF_DIR} ];then
   export PATH=\${LOSF_DIR}/losf:\${PATH}
fi
	
EOF

# shell login scripts

%{__cat} << EOF > %{buildroot}/etc/profile.d/losf.csh
#!/bin/sh

# Setup default path for LosF

set LOSF_DIR=%{prefix}
set TOP_DIR=\`dirname \${LOSF_DIR}\`

if ( -l \${TOP_DIR}/losf ) then
   set path = (\${TOP_DIR}/losf\${PATH} \$path)
else if ( -d \${LOSF_DIR} ) then
   set path = (\${LOSF_DIR}/losf \$path)
endif
	
EOF

%clean
rm -rf $RPM_BUILD_ROOT


%post

# Update losf soft link to latest version and inherit config_dir from most
# recent install. Use -c option to clean up previous config_dir file for clean
# RPM upgrades.

%{prefix}/misc/config_latest_install -c -q

# Initialize env

if [ -s /etc/profile.d/losf.sh ];then
   . /etc/profile.d/losf.sh
fi	


%postun

# Following occurs when removing last version of the package. Clean up soft
# link and config_dir.

if [ "$1" = 0 ];then
    top_dir=$(dirname %{prefix})
    if [ -L $top_dir/losf ];then
	rm $top_dir/losf
    fi

    if [ -s %{prefix}/config/config_dir ];then
	rm %{prefix}/config/config_dir
    fi
fi


%files
%defattr(-,root,root,-)
%{prefix}
/etc/profile.d/losf.sh
/etc/profile.d/losf.csh


