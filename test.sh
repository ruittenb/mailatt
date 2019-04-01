#!/usr/bin/env bash

############################################################################
# variables

PROG=./mailatt
NULL=/dev/null

FROM=quelquun@nimporte.ou
TO1='Recipient <recipient@example.com>'
CC=copied-person@example.com
SUBJECT='The files you requested'
HEADER='X-Testing: testing'
BODY='Message body'
CHARSET=ISO-8859-15

let num=0

############################################################################
# functions

# If we're on a terminal, then prepare for output in color
#
init_color() {
	if tty -s; then
		red=$(printf '\033[31m')
		green=$(printf '\033[32m')
		reset=$(tput sgr0)
	fi
}

# Invert a command's exit status
# @param {string, ...} commandline to execute
#
not() {
	if "$@"; then
		return 1
	else
		return 0
	fi
}

# Test whether the command output matches a particular regexp
#
# @param {string} user-friendly short description of test
# @param {regex} pattern to match. The pattern may be prepended with
#                an exclamation point (!) to specify that it must NOT match.
#
run_test() {
	description=$1
	pat=$2
	not=
	if [[ $pat = !* ]]; then
		not=not
		pat=${pat#!}
	fi
	if $not grep "$pat" > $NULL; then
		result=${green}success${reset}
	else
		result=${red}failure${reset}
	fi
	printf "Test %2d $result ($description)\n" $((++num))
}

# Run all tests
#
main() {
	init_color

	# usage

	run_test usage \
		"^Usage:" \
		< <($PROG -h)

	# message options

	run_test 'content-type: multipart/mixed' \
		'^Content-Type: multipart/mixed' \
		< <($PROG -d)
	run_test 'content-type: multipart/alternative' \
		'^Content-Type: multipart/alternative' \
		< <($PROG -d -a)
	run_test 'content-disposition: inline' \
		'^Content-Disposition: inline' \
		< <(echo | $PROG -d -i -)
	run_test 'content-disposition: attachment' \
		'^Content-Disposition: attachment' \
		< <(echo | $PROG -d -)
	run_test "content-transfer-encoding: header: quoted-printable" \
		'^To: =?ISO-8859-15?Q?Recipient?= ' \
		< <($PROG -d -C $CHARSET -q -r "$TO1")
	run_test "content-transfer-encoding: header: base64" \
		'^To: =?ISO-8859-15?B?UmVjaXBpZW50?= ' \
		< <($PROG -d -C $CHARSET -m -r "$TO1")

	# header options

	run_test recipient \
		"^To: $TO1" \
		< <($PROG -d -r "$TO1")
	#run_test 'two recipients' \
	#	"^To: $TO2" \
	#	< <($PROG -d -r "$TO2")
	run_test cc \
		"^Cc: <$CC>" \
		< <($PROG -d -c "$CC")
	run_test from \
		"^From: <$FROM>" \
		< <($PROG -d -f "$FROM")
	run_test subject \
		"^Subject: $SUBJECT" \
		< <($PROG -d -s "$SUBJECT")
	run_test header \
		"^$HEADER" \
		< <($PROG -d -H "$HEADER")

	# attachment headers

	run_test 'content-md5: present' \
		'^Content-MD5: ' \
		< <($PROG -d -i test/msdos.html test/tick.png)
	run_test 'content-md5: absent' \
		'!^Content-MD5: ' \
		< <($PROG -d -D -i test/long-lines.txt | grep -v 'Content-MD5: ')

	run_test "content-transfer-encoding: body: quoted-printable" \
		'Transfer-Encoding: quoted-printable' \
		< <($PROG -d -r "$TO1" -q mailatt)
	run_test "content-transfer-encoding: body: base64" \
		'Transfer-Encoding: base64' \
		< <($PROG -d -r "$TO1" -m mailatt)
	run_test "content-transfer-encoding: body: uuencode" \
		'Transfer-Encoding: uuencode' \
		< <($PROG -d -r "$TO1" -u mailatt)
	run_test 'uuencode mode line' \
		'^begin 755 mailatt' \
		< <($PROG -d -r "$TO1" -u mailatt)

	run_test 'mime type: text/html' \
		'^Content-Type: text/html' \
		< <(echo | $PROG -d -i -M text/html -)
	run_test 'mime type: application/pdf' \
		'^Content-Type: application/x-pdf' \
		< <(echo | $PROG -d -i -M application/x-pdf -)

	# body

	run_test 'body' \
		"^$BODY" \
		< <(echo "$BODY" | $PROG -d -i -)
}

############################################################################
# main

main

