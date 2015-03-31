Summary: An rpm used for testing
Name: foo
Version: 1.0
Release: 2
License: LGPL
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

%description

This is an rpm used to test the losf addrpm functionality.

%prep

%build

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT/opt/atest
echo "This is also a test" > $RPM_BUILD_ROOT/opt/atest/foo

%clean
rm -rf $RPM_BUILD_ROOT


%files
%defattr(-,root,root,-)
/opt/atest/foo



