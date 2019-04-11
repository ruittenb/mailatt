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
	typeset progname="$1"
	typeset section="$2"
	if [ "`uname`" = HP-UX -o "`uname`" = SunOS ] && [ "$section" = 8 ]; then
		section=1m
	fi
	askprefix
	findmangroup
	echo "Making appropriate directories under $PREFIX ..."
	test -d $PREFIX/bin             || mkdir -p -m 775 $PREFIX/bin
	test -d $PREFIX/man/man$section || mkdir -p -m 775 $PREFIX/man/man$section
	echo "Installing main script..."
	install -m 775 -o root -g bin "$progname" $PREFIX/bin
	echo "Installing user manpage..."
	install -m 664 -o root -g "$mangroup" $progname.$section $PREFIX/man/man$section
	echo "Done."
}

main "$@"

