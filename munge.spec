#
# spec file for package munge
#
# Copyright (c) 2018 SUSE LINUX GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


#Compat macro for new _fillupdir macro introduced in Nov 2017
%if ! %{defined _fillupdir}
  %define _fillupdir /var/adm/fillup-templates
%endif

%if 0%{?suse_version} >= 1210
%define have_systemd 1
%endif
%define lversion 2

%if 0%{?have_systemd}
 %define munge_g %name
 %define munge_u %name
%else
 %define munge_g root
 %define munge_u daemon
%endif

Name:           munge
Version:        0.5.13
Release:        lp151.3.3
Summary:        An authentication service for creating and validating credentials
License:        GPL-3.0+ and LGPL-3.0+
Group:          Productivity/Security
Url:            http://dun.github.io/munge/
Source0:        https://github.com/dun/munge/archive/%{name}-%{version}.tar.gz
Source1:        baselibs.conf
Source2:        sysconfig.munge
Source3:        README.SUSE
Patch0:         Make-SUSE-specific-adjustments.patch
BuildRequires:  libbz2-devel
BuildRequires:  openssl-devel
BuildRequires:  pkgconfig
BuildRequires:  zlib-devel
%if 0%{?suse_version} <= 1140
Requires(pre):  pwdutils
%else
Requires(pre):  shadow
%endif
%if 0%{?have_systemd}
BuildRequires:  systemd
BuildRequires:  systemd-rpm-macros
%{?systemd_requires}
%endif
%if 0%{?suse_version} < 1310
%{!?_tmpfilesdir:%global _tmpfilesdir /usr/lib/tmpfiles.d}
%endif
BuildRoot:      %{_tmppath}/%{name}-%{version}-build

%description
MUNGE (MUNGE Uid 'N' Gid Emporium) is an authentication service for creating
and validating credentials.  It is designed to be highly scalable for use
in an HPC cluster environment.  It allows a process to authenticate the
UID and GID of another local or remote process within a group of hosts
having common users and groups.  These hosts form a security realm that is
defined by a shared cryptographic key.  Clients within this security realm
can create and validate credentials without the use of root privileges,
reserved ports, or platform-specific methods.

%package -n lib%{name}%{lversion}
Summary:        Libraries for applications using MUNGE
Group:          System/Libraries
Recommends:     munge

%description -n lib%{name}%{lversion}
A shared library for applications using the MUNGE authentication service.

%package devel
Requires:       lib%{name}%{lversion} = %{version}
Summary:        Headers and Libraries for building applications using %{name}
Group:          Development/Libraries/C and C++

%description devel
A header file and libraries for building applications using the %{name} 
authenication service.

%prep
%setup -n %{name}-%{name}-%{version}
%patch0 -p1
cp %{SOURCE3} .

%build
%configure
make %{?_smp_mflags}

%install
%makeinstall
%{__rm} -f %{buildroot}%{_libdir}/*.la
%{__rm} -f %{buildroot}%{_libdir}/*.a
%{__install} -m 0755 -d %{buildroot}%{_fillupdir}
%{__cp} -p %{S:2} %{buildroot}%{_fillupdir}/sysconfig.munge
%{__rm} -f %{buildroot}%{_sysconfdir}/sysconfig/munge

# We don't want systemd file on SLE 11
%if 0%{!?have_systemd:1}
   test -d %{buildroot}%{_prefix}/lib/systemd && \
      rm -rf %{buildroot}%{_prefix}/lib/systemd
   test -f %{buildroot}/lib/systemd/system/munge.service && \
      rm -f %{buildroot}/lib/systemd/system/munge.service
   rm -f %{buildroot}/%{_tmpfilesdir}/munge.conf
   sed -i 's/USER="munge"/USER="%munge_u"/g' %{buildroot}/%{_initrddir}/%{name}
   %{__ln_s} -f %{_initrddir}/%{name} %{buildroot}%{_sbindir}/rc%{name}
%else
  sed -i 's/User=munge/User=%munge_u/g' %{buildroot}%{_unitdir}/munge.service
  sed -i 's/Group=munge/Group=%munge_g/g' %{buildroot}%{_unitdir}/munge.service
  sed -i 's/munge \+munge/%munge_u %munge_g/g' %{buildroot}%{_tmpfilesdir}/munge.conf
  rm -f %{buildroot}%{_initddir}/munge
  rmdir %{buildroot}%{_localstatedir}/run/munge
  ln -s %{_sbindir}/service %{buildroot}%{_sbindir}/rc%{name}
%endif

%post -n lib%{name}%{lversion} -p /sbin/ldconfig

%postun -n lib%{name}%{lversion} -p /sbin/ldconfig

%pre
%if 0%{?have_systemd}
%service_add_pre munge.service
%endif
%define munge_home "%_localstatedir%_rundir/munge"
%define munge_descr "MUNGE authentication service"
getent group %munge_g >/dev/null || groupadd -r %munge_g
getent passwd %munge_u >/dev/null || useradd -r -g %munge_g -d %munge_home -s /bin/false -c %munge_descr %munge_u
exit 0

%preun
%if 0%{?have_systemd}
%service_del_preun munge.service
%else
%stop_on_removal munge
%endif

%define fixperm() [ -e %1 ] && /bin/chown %munge_u:%munge_g %1
%postun
if [ $1 -eq 1 ]
then
    %{fixperm %{_localstatedir}/log/munge}
    %{fixperm %{_localstatedir}/log/munge/munged.log}
    %{fixperm %{_localstatedir}/run/munge}
fi
%if 0%{?have_systemd}
%service_del_postun munge.service
%else
%restart_on_update munge
%insserv_cleanup
%endif

%post
if [ $1 -eq 1 ]
then
    %{fixperm %{_localstatedir}/log/munge}
    %{fixperm %{_localstatedir}/log/munge/munged.log}
    %{fixperm %{_localstatedir}/run/munge}
fi
if [ ! -e %{_sysconfdir}/munge/munge.key -a -c /dev/urandom ]; then
  /bin/dd if=/dev/urandom bs=1 count=1024 \
    >%{_sysconfdir}/munge/munge.key 2>/dev/null
fi
/bin/chown %munge_u:%munge_g %{_sysconfdir}/munge/munge.key
/bin/chmod 0400 %{_sysconfdir}/munge/munge.key
%if 0%{?have_systemd}
%service_add_post munge.service
systemd-tmpfiles --create %{_tmpfilesdir}/munge.conf
%else
%{fillup_and_insserv -i munge}
%endif

%files
%defattr(-,root,root,0755)
%doc AUTHORS
%doc COPYING
%doc DISCLAIMER*
%doc HISTORY
%doc JARGON
%doc NEWS
%doc PLATFORMS
%doc QUICKSTART
%doc README
%doc TODO
%doc README.SUSE
%doc doc/*
%dir %attr(0700,%munge_u,%munge_g) %config %{_sysconfdir}/munge
%dir %attr(0711,%munge_u,%munge_g) %config %{_localstatedir}/lib/munge
%dir %attr(0700,%munge_u,%munge_g) %config %{_localstatedir}/log/munge
%{_bindir}/*
%{_sbindir}/*
%{_mandir}/*[^3]/*
%{_fillupdir}/sysconfig.munge
%if 0%{?have_systemd}
%{_unitdir}/munge.service
%{_tmpfilesdir}/munge.conf
%else
%attr(0755,%munge_u,%munge_g) %dir %{_localstatedir}/run/%{name}
%{_initddir}/munge
%endif

%files devel
%defattr(-,root,root,0755)
%{_includedir}/*
%{_mandir}/*3/*
%{_libdir}/*.so
%{_libdir}/pkgconfig/*.pc

%files -n lib%{name}%{lversion}
%defattr(-,root,root,0755)
%{_libdir}/*.so.*

%changelog
* Fri Mar 16 2018 cgoll@suse.com
- added README.SUSE file  (bsc#1085665)
* Wed Dec  6 2017 eich@suse.com
- Update to 0.5.13:
  * Added support for OpenSSL 1.1.0.
  * Added support for UID/GID values >= 2^31.
  * Added support for getentropy() and getrandom().
  * Added --trusted-group cmdline opt to munged.
  * Added --log-file and --seed-file cmdline opts to munged.
  * Changed default MAC algorithm to SHA-256.
  * Fixed autoconf installation directory variable substitution.
  * Fixed all gcc, clang, and valgrind warnings.
  * Improved resilience and unpredictability of PRNG.
  * Improved hash table performance.
  * Removed libmissing dependency from libmunge.
* Thu Nov 23 2017 rbrown@suse.com
- Replace references to /var/adm/fillup-templates with new
  %%_fillupdir macro (boo#1069468)
* Tue Feb  7 2017 eich@suse.com
- Fix BuildRequires for zlib-devel.
* Wed Feb  1 2017 eich@suse.com
- Replace group/user add macros with function calls.
- Make sure we update the user/group of files/directories correctly
  when updating - in case they have changed.
* Tue Jan  3 2017 eich@suse.com
- Use user 'munge', group 'munge' for systemd and user 'daemon', group 'root'
  for non-systemd by setting the appropriate macros '%%munge_u' and '%%munge_g'.
- Create user/group munge if they don't exist.
- Add 'BuildRequires: libbz2-devel'
- Fix typo.
* Tue Jan  3 2017 eich@suse.com
- Add 'Recommends: munge' to libmunge:
  This library requires the munge service to run on the
  local system to be useful.
* Mon Dec 12 2016 vetter@physik.uni-wuerzburg.de
- Fix typo in init script (SLE11) introduced by last change
- Fix rpm preun/postun-scripts (SLE11)
- Fix empty /etc/sysconfig/munge after update (SLE11)
* Thu Dec  8 2016 vetter@physik.uni-wuerzburg.de
- change USER from munge to daemon for non-systemd OSes
* Mon Oct 17 2016 eich@suse.com
- Setting 'download_files' service to mode='localonly'
  and adding source tarball. (Required for Factory).
* Mon Oct 17 2016 eich@suse.com
- Add baselib.conf as Source to spec file.
- Remove tar ball of version 0.5.11.
* Sat Oct 15 2016 eich@suse.com
- version 0.5.12
  * Changed project homepage to <https://dun.github.io/munge/>.
  * Changed RPM specfile from sysvinit to systemd. (#33)
  * Added --max-ttl cmdline opt to munged. (#28)
  * Added --pid-file cmdline opt to munged. (#41)
* Fri Oct 14 2016 eich@suse.com
- Add source service to download sources.
- Remove static libraries: If they are needed, they should be packaged
  separately.
- Add a %%define have_systemd to clearer identify systemd relevant parts.
- Add define of lversion insead of hard conding this.
- remove README.MULTILIB: Package is built already.
- Add BuildRequires: for bzip2-devel, systemd-rpm-macros.
- Spell out files under %%{_sysconfdir}/
- Fix symlink to %%{_sbindir}/rcmunge for initV and systemd.
* Thu Oct  9 2014 bugs@vdm-design.de
- Create /run/munge when package is installed
  before a restart was needed for the directory to be created
* Thu Sep 18 2014 bugs@vdm-design.de
- We are using daemon:root as user and group for munge.
  Therefor start it with this user instead of munge:munge
* Sat Jul 26 2014 scorot@free.fr
- version 0.5.11
  * Added --mlockall cmdline opt to munged.
  * Added --syslog cmdline opt to munged.
  * Added --uid and --gid cmdline opts to munge.
  * Added numeric timezone to unmunge timestamp output.
  * Added timer to munged for periodically stirring PRNG entropy
    pool.
  * Added support for pkg-config.
  * Added support for systemd.
  * Changed timer thread to better accommodate misbehaving system
    clocks.
  * Changed behavior of munge --string cmdline opt to not append
    newline.
  * Changed init script chkconfig priority levels to start after
    ntpd/ntpdate.
  * Changed init script so munged runs as munge user by default.
  * Fixed HMAC validation timing attack vulnerability.
  * Fixed bug with munged being unable to restart if daemon not
    cleanly shutdown.
  * Fixed bug with large groups triggering "numerical result out
    of range" error.
  * Fixed bug causing high CPU utilization on FreeBSD when
    processing group info.
  * Fixed bug causing IPv6-only hosts to exit due to failed
    hostname resolution.
  * Fixed autoconf check that was not portable across shells.
  * Fixed init script LSB Header on openSUSE.
  * Replaced perl build-time dependency with awk.
- add systemd support openSUSE >= 12.1
* Fri Nov 16 2012 scorot@free.fr
- first package based on spec file from hornos project
