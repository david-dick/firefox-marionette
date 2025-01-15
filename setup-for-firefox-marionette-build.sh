#! /bin/sh

SUDO="sudo ";
SUDO_WITH_ENVIRONMENT="$SUDO -E ";
OSNAME=`uname`;
if [ ! $EUID ]
then
	EUID=`id -u`;
fi
if [ $EUID -eq 0 ]
then
	SUDO="";
	SUDO_WITH_ENVIRONMENT="";
fi
case $OSNAME in
	Linux)
		if [ -e "/etc/redhat-release" ]
		then
			DNF="dnf"
			$DNF --help >/dev/null 2>/dev/null || DNF="yum"
			if [ ! -e "/etc/fedora-release" ]
			then
				rpm -q --quiet epel-release 2>/dev/null && ${SUDO}$DNF install -y epel-release || true
			fi
			PACKAGES="dbus-x11 \
						firefox \
						git \
						make \
						mesa-dri-drivers \
						nginx \
						openssl \
						perl-Archive-Zip \
						perl-Crypt-PasswdMD5 \
						perl-Crypt-URandom \
						perl-Digest-SHA \
						perl-ExtUtils-MakeMaker \
						perl-File-HomeDir \
						perl-Font-TTF \
						perl-HTTP-Daemon \
						perl-HTTP-Message \
						perl-IO-Socket-SSL \
						perl-JSON \
						perl-PerlIO-utf8_strict \
						perl-Sub-Exporter \
						perl-Sub-Uplevel \
						perl-Text-CSV_XS \
						perl-TermReadKey \
						perl-Test-Exception \
						perl-Test-Memory-Cycle \
						perl-Test-Simple \
						perl-XML-Parser \
						squid \
						xorg-x11-server-Xvfb \
						yarnpkg"
			rpm -q --quiet $PACKAGES || ${SUDO}$DNF install -y $PACKAGES
			SOMETIMES_MISSING_PACKAGES="perl-Config-INI \
						perl-DirHandle \
						perl-PDF-API2"
			for PACKAGE in $SOMETIMES_MISSING_PACKAGES
			do
				rpm -q --quiet $PACKAGE || ${SUDO}$DNF install -y $PACKAGE
			done
			for PACKAGE in Config::INI PDF::API2
			do
				perl -M$PACKAGE -e 'exit 0'
				if [ $? != 0 ]
				then
					${SUDO}dnf install -y cpan
					PERL_MM_USE_DEFAULT=1 ${SUDO_WITH_ENVIRONMENT}cpan $PACKAGE
				fi
			done
		fi
		if [ -e "/etc/SUSE-brand" ]
		then
			PACKAGES="dbus-1-x11 \
						MozillaFirefox \
						git \
						make \
						Mesa-dri-nouveau \
						nginx \
						openssl \
						perl-Archive-Zip \
						perl-Config-INI \
						perl-Crypt-PasswdMD5 \
						perl-Crypt-URandom \
						perl-ExtUtils-MakeMaker \
						perl-File-HomeDir \
						perl-Font-TTF \
						perl-HTTP-Daemon \
						perl-HTTP-Message \
						perl-IO-Socket-SSL \
						perl-JSON \
						perl-PDF-API2 \
						perl-PerlIO-utf8_strict \
						perl-Sub-Exporter \
						perl-Sub-Uplevel \
						perl-Text-CSV_XS \
						perl-Term-ReadKey \
						perl-Test-Exception \
						perl-Test-Memory-Cycle \
						perl-Test-Simple \
						perl-XML-Parser \
						squid \
						xorg-x11-server-Xvfb \
						yarn"
			rpm -q --quiet $PACKAGES || ${SUDO}zypper install -y $PACKAGES
		fi
		if [ -e "/etc/debian_version" ]
		then
			${SUDO}apt-get update
			DEBIAN_FIREFOX_PACKAGE_NAME="firefox"
			if [ ! -e /etc/apt/preferences.d/mozillateamppa ]
			then
				NUMBER_OF_FIREFOX_PACKAGES=`apt-cache search '^firefox$' | wc -l`
				if [ $NUMBER_OF_FIREFOX_PACKAGES -eq 0 ]
				then
					# debian only has a firefox-esr package
					DEBIAN_FIREFOX_PACKAGE_NAME="firefox-esr"
				fi
			fi
			${SUDO}apt-get install -y $DEBIAN_FIREFOX_PACKAGE_NAME
			SNAP_FOUND=1
			SNAP_FIREFOX_FOUND=0
			snap list $DEBIAN_FIREFOX_PACKAGE_NAME 2>/dev/null && SNAP_FIREFOX_FOUND=1 || SNAP=0
			if [ $SNAP_FOUND -eq 1 ] && [ $SNAP_FIREFOX_FOUND -eq 1 ]
			then
				${SUDO}snap remove $DEBIAN_FIREFOX_PACKAGE_NAME
				${SUDO}apt-get remove -y $DEBIAN_FIREFOX_PACKAGE_NAME
				${SUDO}add-apt-repository -y ppa:mozillateam/ppa
				${SUDO}apt-get update
				${SUDO}apt-get install -y -t 'o=LP-PPA-mozillateam' firefox
				TMP_MOZILLA_REPO_DIR=`mktemp -d`
				/usr/bin/echo -e "Package: firefox*\nPin: release o=LP-PPA-mozillateam\nPin-Priority: 501" >$TMP_MOZILLA_REPO_DIR/mozillateamppa
				${SUDO}mv $TMP_MOZILLA_REPO_DIR/mozillateamppa /etc/apt/preferences.d/mozillateamppa
				rmdir $TMP_MOZILLA_REPO_DIR
			fi
			${SUDO}apt-get install -y \
						dbus-x11 \
						git \
						libarchive-zip-perl \
						libconfig-ini-perl \
						libcrypt-urandom-perl \
						libcrypt-passwdmd5-perl \
						libfile-homedir-perl \
						libhttp-daemon-perl \
						libhttp-message-perl \
						libio-socket-ssl-perl \
						libjson-perl \
						libpdf-api2-perl \
						libpod-parser-perl \
						libtest-checkmanifest-perl \
						libtest-pod-coverage-perl \
						libtext-csv-xs-perl \
						libterm-readkey-perl \
						liburi-perl \
						libxml-parser-perl \
						make \
						nginx \
						openssh-server \
						squid \
						xvfb \
						yarnpkg
		fi
		if [ -e "/etc/alpine-release" ]
		then
			PACKAGES="dbus-x11 \
				firefox \
				git \
				mesa-dri-nouveau \
				nginx \
				openssl \
				perl \
				perl-archive-zip \
				perl-config-ini \
				perl-crypt-passwdmd5 \
				perl-crypt-urandom \
				perl-file-homedir \
				perl-http-daemon \
				perl-http-message \
				perl-io-socket-ssl \
				perl-json \
				perl-pdf-api2 \
				perl-term-readkey \
				perl-test-pod \
				perl-test-pod-coverage \
				perl-test-simple \
				perl-text-csv_xs \
				perl-uri \
				perl-xml-parser \
				make \
				squid \
				xauth \
				xvfb \
				yarn"
			${SUDO}apk update
			${SUDO}apk upgrade
			INSTALL_PACKAGES=0
			for PACKAGE_NAME in $PACKAGES
			do
				grep $PACKAGE_NAME /etc/apk/world >/dev/null || INSTALL_PACKAGES=1
			done
			if [ $INSTALL_PACKAGES -eq 1 ]
			then
				${SUDO}apk add $PACKAGES
				if [ $? != 0 ]
				then
					cat <<"_APK_REPO_";

Check the /etc/apk/repositories file as it needs to have the community and main repos uncommented and
probably the edge repositories as well, like so;

#/media/cdrom/apks
http://dl-cdn.alpinelinux.org/alpine/v3.16/main
http://dl-cdn.alpinelinux.org/alpine/v3.16/community
http://dl-cdn.alpinelinux.org/alpine/edge/main
http://dl-cdn.alpinelinux.org/alpine/edge/community
http://dl-cdn.alpinelinux.org/alpine/edge/testing

_APK_REPO_
				fi
			fi
		fi
		;;
	DragonFly)
		PACKAGES="firefox \
					git \
					mesa-dri-gallium \
					nginx \
					openssl \
					perl5 \
					p5-Archive-Zip \
					p5-JSON \
					p5-Config-INI \
					p5-Crypt-PasswdMD5 \
					p5-Crypt-URandom \
					p5-File-HomeDir \
					p5-Digest-SHA \
					p5-HTTP-Daemon \
					p5-HTTP-Message \
					p5-IO-Socket-SSL \
					p5-PDF-API2 \
					p5-Text-CSV_XS \
					p5-Term-ReadKey \
					p5-Test-CheckManifest \
					p5-Test-Pod \
					p5-Test-Pod-Coverage \
					p5-Test-Simple \
					p5-XML-Parser \
					squid \
					xauth \
					xorg-vfbserver \
					yarn"
		${SUDO}pkg upgrade -y
		pkg info $PACKAGES >/dev/null || ${SUDO}pkg install -y $PACKAGES
		if [ ! -e /etc/machine-id ]
		then
			${SUDO}dbus-uuidgen --ensure=/etc/machine-id
		fi
		;;
	FreeBSD)
		PACKAGES="firefox-esr \
					git \
					nginx \
					openssl \
					perl5 \
					p5-Archive-Zip \
					p5-JSON \
					p5-Config-INI \
					p5-Crypt-PasswdMD5 \
					p5-Crypt-URandom \
					p5-File-HomeDir \
					p5-Digest-SHA \
					p5-HTTP-Daemon \
					p5-HTTP-Message \
					p5-IO-Socket-SSL \
					p5-PDF-API2 \
					p5-Text-CSV_XS \
					p5-Term-ReadKey \
					p5-Test-CheckManifest \
					p5-Test-Pod \
					p5-Test-Pod-Coverage \
					p5-Test-Simple \
					p5-XML-Parser \
					squid \
					xauth \
					xorg-vfbserver \
					yarn"
		${SUDO}pkg upgrade -y
		pkg info $PACKAGES >/dev/null || ${SUDO}pkg install -y $PACKAGES
		mount | grep fdescfs >/dev/null || ${SUDO}mount -t fdescfs fdesc /dev/fd
		if [ ! -e /etc/machine-id ]
		then
			${SUDO}dbus-uuidgen --ensure=/etc/machine-id
		fi
		;;
	MidnightBSD)
		PACKAGES="firefox \
					git \
					nginx \
					openssl \
					perl5 \
					p5-Archive-Zip \
					p5-JSON \
					p5-Config-INI \
					p5-Crypt-PasswdMD5 \
					p5-Crypt-URandom \
					p5-File-HomeDir \
					p5-Digest-SHA \
					p5-HTTP-Daemon \
					p5-HTTP-Message \
					p5-IO-Socket-SSL \
					p5-PDF-API2 \
					p5-Text-CSV_XS \
					p5-Term-ReadKey \
					p5-Test-CheckManifest \
					p5-Test-Pod \
					p5-Test-Pod-Coverage \
					p5-Test-Simple \
					p5-XML-Parser \
					squid \
					xauth \
					xorg-vfbserver \
					yarn"
		for NAME in $PACKAGES
		do
			mport info $NAME >/dev/null || ${SUDO}mport install $NAME
		done
		mount | grep fdescfs >/dev/null || ${SUDO}mount -t fdescfs fdesc /dev/fd
		if [ ! -e /etc/machine-id ]
		then
			${SUDO}dbus-uuidgen --ensure=/etc/machine-id
		fi
		;;
	OpenBSD)
		PACKAGES="firefox \
					git \
					nginx \
					p5-Archive-Zip \
					p5-JSON \
					p5-Config-INI \
					p5-Crypt-PasswdMD5 \
					p5-Crypt-URandom \
					p5-File-HomeDir \
					p5-HTTP-Daemon \
					p5-HTTP-Message \
					p5-IO-Socket-SSL \
					p5-Params-Util \
					p5-PerlIO-utf8_strict \
					p5-PDF-API2 \
					p5-Sub-Exporter \
					p5-Sub-Uplevel \
					p5-Sub-Install \
					p5-Test-CheckManifest \
					p5-Test-Pod-Coverage \
					p5-Text-CSV_XS \
					p5-XML-Parser \
					squid \
					yarn"
		${SUDO}pkg_add -u
		pkg_info $PACKAGES >/dev/null || ${SUDO}pkg_add -I $PACKAGES
		perl -MConfig::INI -e 'exit 0' || PERL_MM_USE_DEFAULT=1 ${SUDO_WITH_ENVIRONMENT} cpan Config::INI
		perl -MCrypt::URandom -e 'exit 0' || PERL_MM_USE_DEFAULT=1 ${SUDO_WITH_ENVIRONMENT} cpan Crypt::URandom
		;;
	NetBSD)
		PKG_PATH="http://cdn.NetBSD.org/pub/pkgsrc/packages/NetBSD/$(uname -p)/$(uname -r|cut -f '1 2' -d.)/All/"
		export PKG_PATH
		${SUDO}pkg_add pkgin
		PACKAGES="firefox \
					git \
					mozilla-rootcerts-openssl \
					nginx \
					openssl \
					p5-Archive-Zip \
					p5-JSON \
					p5-Config-INI \
					p5-Crypt-PasswdMD5 \
					p5-Crypt-URandom \
					p5-File-HomeDir \
					p5-HTTP-Daemon \
					p5-HTTP-Message \
					p5-IO-Socket-SSL \
					p5-Params-Util \
					p5-PerlIO-utf8_strict \
					p5-PDF-API2 \
					p5-Sub-Exporter \
					p5-Sub-Uplevel \
					p5-Sub-Install \
					p5-Text-CSV_XS \
					p5-Term-ReadKey \
					p5-Test-CheckManifest \
					p5-Test-Pod \
					p5-Test-Pod-Coverage \
					p5-XML-Parser \
					squid \
					yarn"
		INSTALL_PACKAGES=""
		${SUDO}pkgin upgrade
		for NAME in $PACKAGES
		do
			pkgin list | grep $NAME >/dev/null 2>/dev/null || INSTALL_PACKAGES="$INSTALL_PACKAGES $NAME"
		done
		if [ "$INSTALL_PACKAGES" != "" ]
		then
			${SUDO}pkg_add ${PKG_PATH}/pkgin
			${SUDO}pkgin -y install $INSTALL_PACKAGES
			if [ $? != 0 ]
			then
				cat <<_PKG_PATH_

pkg_add failed. PKG_PATH was set to $PKG_PATH

_PKG_PATH_
			fi
		fi
		;;
	CYGWIN_NT*)
		PACKAGE_LIST="perl-Archive-Zip"
		for PACKAGE in perl-JSON \
					perl-Config-INI \
					perl-Crypt-PasswdMD5 \
					perl-Crypt-URandom \
					perl-File-HomeDir \
					perl-Digest-SHA \
					perl-HTTP-Daemon \
					perl-HTTP-Message \
					perl-IO-Socket-SSL \
					perl-PDF-API2 \
					perl-PerlIO-utf8_strict \
					perl-Sub-Exporter \
					perl-Sub-Uplevel \
					perl-Text-CSV_XS \
					perl-Term-ReadKey \
					perl-Test-Simple \
					perl-XML-Parser
		do
			PACKAGE_LIST="$PACKAGE_LIST,$PACKAGE"
		done
		GUESS_EXE=`cygpath -u $USERPROFILE`/Downloads/setup-x86_64.exe
		grep -ail 'Cygwin installation tool' $GUESS_EXE
		if [ $? == 0 ]
		then
			SETUP_EXE=$GUESS_EXE
		else
			SETUP_EXE=`find /cygdrive -name 'setup-x86_64.exe' -exec grep -ail 'Cygwin installation tool' {} \;`
		fi
		$SETUP_EXE -q -P $PACKAGE_LIST
		perl -MConfig::INI -e 'exit 0' || PERL_MM_USE_DEFAULT=1 cpan Config::INI
		perl -MPDF::API2 -e 'exit 0' || PERL_MM_USE_DEFAULT=1 cpan PDF::API2
		perl -MCrypt::URandom -e 'exit 0' || PERL_MM_USE_DEFAULT=1 cpan Crypt::URandom
		perl -MCrypt::PasswdMD5 -e 'exit 0' || PERL_MM_USE_DEFAULT=1 cpan Crypt::PasswdMD5
		;;
	Darwin)
		for PACKAGE in Archive::Zip \
					JSON \
					Config::INI \
					Crypt::PasswdMD5 \
					Crypt::URandom \
					File::HomeDir \
					Digest::SHA \
					HTTP::Daemon \
					HTTP::Message \
					IO::Socket::SSL \
					PDF::API2 \
					PerlIO::utf8_strict \
					Sub::Exporter \
					Sub::Uplevel \
					Text::CSV_XS \
					Term::ReadKey \
					Test::CheckManifest \
					Test::Pod \
					Test::Pod::Coverage \
					Test::Simple \
					XML::Parser
		do
			perl -M$PACKAGE -e 'exit 0' 2>>/dev/null || PERL_MM_USE_DEFAULT=1 ${SUDO_WITH_ENVIRONMENT}cpan $PACKAGE
		done
		;;
	*)
		echo "Any help with patching '$OSNAME' support would be awesome???"
		;;
esac
