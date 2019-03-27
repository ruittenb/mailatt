#!/bin/ksh

askprefix() {
	printf "Directory prefix for install [/usr/local]? "
	read PREFIX
	: ${PREFIX:=/usr/local}
}

fetch() {
	if [ $# -lt 2 ]; then
		echo "Option $1 requires an argument" 1>&2
	else
		echo "$2"
	fi
}

findmangroup() {
	for mangroup in man wheel root sys bin system; do
		if grep "^$mangroup:" /etc/group >/dev/null; then
			return
		fi
	done
	mangroup=0
}

install() {
	symln=
	mode=
	owner=
	group=
	while [ $# -gt 0 -a "${1#-}" != "$1" ]; do
		case "$1" in
			-m)	mode=` fetch $*`; shift 2;;
			-o)	owner=`fetch $*`; shift 2;;
			-g)	group=`fetch $*`; shift 2;;
			-l)	symln=1; shift;;
		esac
	done

	if [ $# -lt 1 ]; then
		echo "Nothing to install" 1>&2
		exit 1
	elif [ $# -lt 2 ]; then
		echo "Nowhere to install to" 1>&2
		exit 1
	fi

	if [ -z "$symln" ]; then
		if [ -f "$2/$1" -o -L "$2/$1" ]; then
			mv -f $2/$1 $2/$1~
		fi
		cp -i $1 $2
		test "$mode"  && chmod $mode  $2/$1
		test "$owner" && chown $owner $2/$1
		test "$group" && chgrp $group $2/$1
	else
		if [ -L $2 ]; then
			mv -f $2 $2~
		fi
		ln -sf $1 $2
	fi
}

main() {
	progname="${1%%-*}"
	askprefix
	findmangroup
	echo "making appropriate directories under $PREFIX .."
	test -d $PREFIX/bin      || mkdir -p -m 775 $PREFIX/bin
	test -d $PREFIX/man/man1 || mkdir -p -m 775 $PREFIX/man/man1
	echo "installing main script.."
	install -m 775 -o root -g bin "$1" $PREFIX/bin
	install -m 775 -o root -g bin "$2" $PREFIX/bin
	install -l "$1" $PREFIX/bin/$progname
	echo "installing user manpage.."
	install -m 664 -o root -g "$mangroup" $progname.1 $PREFIX/man/man1
	if [ -f "$progname.1m" -o -f "$progname.8" ]; then
		echo "installing sysadmin manpage.."
		if [ "`uname`" = HP-UX -o "`uname`" = SunOS ]; then
			test -d $PREFIX/man/man1m || mkdir -p -m 775 $PREFIX/man/man1m
			install -m 664 -o root -g "$mangroup" $progname.1m $PREFIX/man/man1m/
		else # Linux
			test -d $PREFIX/man/man8  || mkdir -p -m 775 $PREFIX/man/man8
			install -m 664 -o root -g "$mangroup" $progname.8 $PREFIX/man/man8/
		fi
	fi
}

main $(basename $(pwd)) mime-identify

