#!/usr/bin/env bash

############################################################################
# variables

PROG=./mailatt
NULL=/dev/null

FROM=quelquun@nimporte.ou
FROM2=poubelle@nimporte.ou
TO='Recipient <recipient@example.com>'
TO2='Irgendeiner <irgendeiner@example.com>'
TO_LOCAL=root
CC=copied-person@example.com
SUBJECT='The sendmail manual you requested'
SUBJECT2='with the strong recommendation of the board'
SUBJECT3='and the best wishes for your birthday'
SUBJECT_ISO='Réseau Besançon € 12'
SUBJECT2_ISO="Ce breuvage sucré est rafraîchissant et plein de goût. Parfait à déguster lors de chaudes journées d'été."
HEADER='X-Testing: testing'
BODY='Message body'
BODY2='=F3=CC=C1=D7=D8=D3=D1'
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
	if $not grep -E "$pat" > $NULL; then
		result=${green}success${reset}
	else
		result=${red}failure${reset}
	fi
	printf "Test %2d $result: $description\n" $((++num))
}

run_test_debug() {
	#tee /dev/tty | run_test "$@"
	run_test "$@" < <(tee /dev/tty)
}

# Run all usage tests
#
run_usage_tests() {
	run_test 'prints usage info' \
		'^Usage:' \
		< <($PROG -h)
	run_test 'prints version info' \
		"^${PROG#*/}"' [0-9]\.[0-9][0-9](\.[0-9])?' \
		< <($PROG -v)
}


# Run all message options tests
#
run_message_tests() {
	run_test 'content-type: multipart/mixed is the default' \
		'^Content-Type: multipart/mixed' \
		< <($PROG -d)
	run_test 'content-type: multipart/mixed has multiple attachment parts' \
		'^2$' \
		< <($PROG -d test/ascii.txt test/msdos.html | grep -c 'Content-Disposition: attachment')
	run_test 'content-type: multipart/mixed has nothing but attachment parts' \
		'!^Content-Disposition: inline' \
		< <($PROG -d test/ascii.txt test/msdos.html)
	run_test 'content-type: multipart/alternative can be selected' \
		'^Content-Type: multipart/alternative' \
		< <($PROG -d -a)
	run_test 'content-type: multipart/alternative has multiple inline parts' \
		'^2$' \
		< <($PROG -d -a test/ascii.txt test/msdos.html | grep -c 'Content-Disposition: inline')
	run_test 'content-type: multipart/alternative has nothing but inline parts' \
		'!^Content-Disposition: attachment' \
		< <($PROG -d -a test/ascii.txt test/msdos.html)
	run_test 'content-disposition: attachment is the default' \
		'^Content-Disposition: attachment' \
		< <(echo | $PROG -d -)
	run_test 'content-disposition: attachment has no inline attachments' \
		'!^Content-Disposition: inline' \
		< <(echo | $PROG -d -)
	run_test 'content-disposition: inline can be set for the first attachment' \
		'^Content-Disposition: inline' \
		< <(echo | $PROG -d -i -)
	run_test 'content-disposition: inline can be set for no more than one attachment' \
		'^1$' \
		< <(echo | $PROG -d -i - test/ascii.txt | grep -c '^Content-Disposition: inline')
	run_test "content-transfer-encoding: quoted-printable can be set to for a header line" \
		'^To: =\?'"$CHARSET"'\?Q\?Recipient\?= ' \
		< <($PROG -d -C $CHARSET -q -r "$TO")
	run_test "content-transfer-encoding: base64 can be set for a header line" \
		'^To: =\?'"$CHARSET"'\?B\?UmVjaXBpZW50\?= ' \
		< <($PROG -d -C $CHARSET -m -r "$TO")
}

# Run all header options tests
#
run_header_tests() {
	run_test 'can specify one network recipient' \
		"^To: $TO" \
		< <($PROG -d -r "$TO")
	run_test 'can specify one local recipient' \
		"^To: .*<$TO_LOCAL>" \
		< <($PROG -d -r "$TO_LOCAL")
	run_test 'can specify two recipients' \
		"^\t$TO2" \
		< <($PROG -d -r "$TO,$TO2")
	run_test 'can specify carbon copy recipient' \
		"^Cc: <$CC>" \
		< <($PROG -d -c "$CC")
	run_test 'can specify "from" address' \
		"^From: <$FROM>" \
		< <($PROG -d -f "$FROM")
	run_test 'can specify reply-to address' \
		"^Reply-To: <$FROM2>" \
		< <($PROG -d -f "$FROM" -R "$FROM2")
	run_test 'can specify custom header line' \
		"^$HEADER" \
		< <($PROG -d -H "$HEADER")

	run_test 'short ASCII subject, default encoding' \
		"^Subject: $SUBJECT" \
		< <($PROG -d -s "$SUBJECT")
	run_test 'short ASCII subject, quoted-printable encoding' \
		"^Subject: $SUBJECT" \
		< <($PROG -d -q -s "$SUBJECT")
	run_test 'short ASCII subject, base64 encoding' \
		"^Subject: $SUBJECT" \
		< <($PROG -d -m -s "$SUBJECT")
	run_test 'short ASCII subject, 8bit encoding' \
		"^Subject: $SUBJECT" \
		< <($PROG -d -8 -s "$SUBJECT")
	run_test 'short ASCII subject, uuencoding' \
		"^Subject: $SUBJECT" \
		< <($PROG -d -u -s "$SUBJECT")

	run_test 'long ASCII subject, default encoding' \
		"^\t.*$SUBJECT3" \
		< <($PROG -d -s "$SUBJECT $SUBJECT2 $SUBJECT3")
	run_test 'long ASCII subject, quoted-printable encoding' \
		"^\t.*$SUBJECT3" \
		< <($PROG -d -q -s "$SUBJECT $SUBJECT2 $SUBJECT3")
	run_test 'long ASCII subject, base64 encoding' \
		"^\t.*$SUBJECT3" \
		< <($PROG -d -m -s "$SUBJECT $SUBJECT2 $SUBJECT3")
	run_test 'long ASCII subject, 8bit encoding' \
		"^\t.*$SUBJECT3" \
		< <($PROG -d -8 -s "$SUBJECT $SUBJECT2 $SUBJECT3")
	run_test 'long ASCII subject, uuencoding' \
		"^\t.*$SUBJECT3" \
		< <($PROG -d -u -s "$SUBJECT $SUBJECT2 $SUBJECT3")

	run_test "short $CHARSET subject, default encoding" \
		'^Subject: =\?'"${CHARSET}"'\?Q\?' \
		< <($PROG -d -C $CHARSET -s "$SUBJECT_ISO")
	run_test "short $CHARSET subject, quoted-printable encoding" \
		'^Subject: =\?'"${CHARSET}"'\?Q\?' \
		< <($PROG -d -q -C $CHARSET -s "$SUBJECT_ISO")
	run_test "short $CHARSET subject, base64 encoding" \
		'^Subject: =\?'"${CHARSET}"'\?B\?' \
		< <($PROG -d -m -C $CHARSET -s "$SUBJECT_ISO")
	run_test "short $CHARSET subject, 8bit encoding" \
		'^Subject: =\?'"${CHARSET}"'\?B\?' \
		< <($PROG -d -8 -C $CHARSET -s "$SUBJECT_ISO")
	run_test "short $CHARSET subject, uuencoding" \
		'^Subject: =\?'"${CHARSET}"'\?B\?' \
		< <($PROG -d -u -C $CHARSET -s "$SUBJECT_ISO")

	run_test "long $CHARSET subject, default encoding" \
		"^\t.*=?${CHARSET}?Q?" \
		< <($PROG -d -C $CHARSET -s "$SUBJECT2_ISO")
	run_test "long $CHARSET subject, quoted-printable encoding" \
		"^\t.*=?${CHARSET}?Q?" \
		< <($PROG -d -q -C $CHARSET -s "$SUBJECT2_ISO")
	run_test "long $CHARSET subject, base64 encoding" \
		"^\t.*=?${CHARSET}?B?" \
		< <($PROG -d -m -C $CHARSET -s "$SUBJECT2_ISO")
	run_test "long $CHARSET subject, 8bit encoding" \
		"^\t.*=?${CHARSET}?B?" \
		< <($PROG -d -8 -C $CHARSET -s "$SUBJECT2_ISO")
	run_test "long $CHARSET subject, uuencoding" \
		"^\t.*=?${CHARSET}?B?" \
		< <($PROG -d -u -C $CHARSET -s "$SUBJECT2_ISO")
}

# Run all attachment header tests
#
run_attachment_tests() {
	run_test 'content-md5: is present by default' \
		'^Content-MD5: ' \
		< <($PROG -d -i test/msdos.html test/tick.png)
	run_test 'content-md5: is absent if requested' \
		'!^Content-MD5: ' \
		< <($PROG -d -D -i test/long-lines.txt)

	run_test 'content-transfer-encoding: default for text/plain is quoted-printable' \
		'Transfer-Encoding: quoted-printable' \
		< <($PROG -d -r "$TO" test/ascii.txt)
	run_test 'content-transfer-encoding: default for image/png is base64' \
		'Transfer-Encoding: base64' \
		< <($PROG -d -r "$TO" test/tick.png)

	run_test 'content-transfer-encoding: can specify quoted-printable' \
		'Transfer-Encoding: quoted-printable' \
		< <($PROG -d -r "$TO" -q test/ascii.txt)
	run_test 'content-transfer-encoding: can specify base64' \
		'Transfer-Encoding: base64' \
		< <($PROG -d -r "$TO" -m test/ascii.txt)
	run_test 'content-transfer-encoding: can specify 8-bit' \
		'Transfer-Encoding: 8bit' \
		< <($PROG -d -r "$TO" -8 test/ascii.txt)
	run_test 'content-transfer-encoding: can specify uuencode' \
		'Transfer-Encoding: uuencode' \
		< <($PROG -d -r "$TO" -u test/ascii.txt)
	run_test 'specifies the correct uuencode mode line for executable files' \
		'^begin 755 program' \
		< <($PROG -d -r "$TO" -u test/program)
	run_test 'specifies the correct uuencode mode line for non-executable files' \
		'^begin 644 ascii.txt' \
		< <($PROG -d -r "$TO" -u test/ascii.txt)

	run_test 'MIME type text/plain is the default for stdin attachment in 1st place' \
		'^Content-Type: text/plain' \
		< <($PROG -d -i - < test/hydrazine.pdb)
	run_test 'MIME type text/plain is the default for stdin attachment in 2nd place' \
		'^Content-Type: text/plain' \
		< <($PROG -d -i test/msdos.html - < test/hydrazine.pdb)
	run_test 'MIME type text/html can be set on stdin attachment' \
		'^Content-Type: text/html' \
		< <($PROG -d -i -M text/html - < test/msdos.html)
	run_test 'MIME type application/pdf can be set on stdin attachment' \
		'^Content-Type: application/x-pdf' \
		< <(echo | $PROG -d -i -M application/x-pdf -)
	run_test 'MIME type image/png is inferred from filename correctly' \
		'^Content-Type: image/png' \
		< <($PROG -d test/tick.png)
	run_test 'MIME type application/octet-stream is used for unknown types' \
		'^Content-Type: application/octet-stream' \
		< <($PROG -d test/program)

	run_test "filename is reported correctly for stdin attachment" \
		'^Content-Type: text/plain; charset="us-ascii"; name="stdin"' \
		< <($PROG -d - < test/ascii.txt)
	run_test "filename is reported correctly for file attachment" \
		'^Content-Type: text/plain; charset="us-ascii"; name="ascii.txt"' \
		< <($PROG -d test/ascii.txt)
	run_test "filename is reported correctly for file attachment in non-ascii charset" \
		'^Content-Type: text/plain; charset="'$CHARSET'"; name="ascii.txt"' \
		< <($PROG -d -C $CHARSET test/ascii.txt)

}

# Run all body tests
#
run_body_tests() {
	run_test 'can attach a file body in the ascii characterset' \
		"^$BODY" \
		< <(echo "$BODY" | $PROG -d -i -)
	run_test 'can attach a file body in the russian characterset' \
		"^$BODY2" \
		< <($PROG -d -i -C KOI8-R test/koi8-r.txt)
}

# Run all tests
#
run_all_tests() {
	run_usage_tests
	run_message_tests
	run_header_tests
	run_attachment_tests
	run_body_tests
}

# main
#
main() {
	init_color
	run_all_tests
}

############################################################################
# main

main

