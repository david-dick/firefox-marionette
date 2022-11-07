#! /bin/sh

SUDO="sudo ";
OSNAME=`uname`;
case $OSNAME in
	Linux)
		if [ -e "/etc/redhat-release" ]
		then
			DNF="dnf"
			$DNF --help >/dev/null 2>/dev/null || DNF="yum"
			${SUDO}$DNF info epel-release >/dev/null 2>/dev/null && ${SUDO}$DNF install -y epel-release || true
			${SUDO}$DNF install -y \
						dbus-x11 \
						firefox \
						make \
						perl-Archive-Zip \
						perl-Config-INI \
						perl-Crypt-URandom \
						perl-Digest-SHA \
						perl-DirHandle \
						perl-ExtUtils-MakeMaker \
						perl-File-HomeDir \
						perl-HTTP-Daemon \
						perl-HTTP-Message \
						perl-IO-Socket-SSL \
						perl-JSON \
						perl-PDF-API2 \
						perl-PerlIO-utf8_strict \
						perl-Sub-Exporter \
						perl-Sub-Uplevel \
						perl-Text-CSV_XS \
						perl-TermReadKey \
						perl-Test-Simple \
						perl-XML-Parser \
						xorg-x11-server-Xvfb
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
						libarchive-zip-perl \
						libconfig-ini-perl \
						libcrypt-urandom-perl \
						libfile-homedir-perl \
						libhttp-daemon-perl \
						libhttp-message-perl \
						libio-socket-ssl-perl \
						libjson-perl \
						libpdf-api2-perl \
						libtext-csv-xs-perl \
						libterm-readkey-perl \
						liburi-perl \
						libxml-parser-perl \
						make \
						xvfb
		fi
		;;
	FreeBSD)
		${SUDO}pkg install \
					firefox \
					perl5 \
					p5-Archive-Zip \
					p5-JSON \
					p5-Config-INI \
					p5-Crypt-URandom \
					p5-File-HomeDir \
					p5-Digest-SHA \
					p5-HTTP-Daemon \
					p5-HTTP-Message \
					p5-IO-Socket-SSL \
					p5-PDF-API2 \
					p5-Text-CSV_XS \
					p5-Term-ReadKey \
					p5-Test-Simple \
					p5-XML-Parser \
					xauth \
					xorg-vfbserver
		${SUDO}mount -t fdescfs fdesc /dev/fd
		${SUDO}dbus-uuidgen --ensure=/etc/machine-id
		;;
	*)
		echo "Any help with patching '$OSNAME' support would be awesome???"
		;;
esac
