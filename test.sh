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
BODY_ASC='Message body'
BODY_ASC_QP='Message body'
BODY_RUS_QP='^=F3=CC=C1=D7=D8=D3=D1'
BODY_RUS_MM=A2iDOxdLV28
BODY_PNG_MM=^iVBORw0KGgo
BODY_PNG_QP=^=89PNG=0D=0A=1A=0A=
CHARSET_ISO=ISO-8859-15
CHARSET_RUS=KOI8-R

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
		'^To: =\?'"$CHARSET_ISO"'\?Q\?Recipient\?= ' \
		< <($PROG -d -C $CHARSET_ISO -q -r "$TO")
	run_test "content-transfer-encoding: base64 can be set for a header line" \
		'^To: =\?'"$CHARSET_ISO"'\?B\?UmVjaXBpZW50\?= ' \
		< <($PROG -d -C $CHARSET_ISO -m -r "$TO")
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

	run_test "short $CHARSET_ISO subject, ascii charset, quoted-printable encoding" \
		'^Subject: =\?utf-8\?Q\?' \
		< <($PROG -d -q -s "$SUBJECT_ISO")
	run_test "short $CHARSET_ISO subject, ascii charset, base64 encoding" \
		'^Subject: =\?utf-8\?B\?' \
		< <($PROG -d -m -s "$SUBJECT_ISO")

	run_test "short $CHARSET_ISO subject, default encoding" \
		'^Subject: =\?'"${CHARSET_ISO}"'\?Q\?' \
		< <($PROG -d -C $CHARSET_ISO -s "$SUBJECT_ISO")
	run_test "short $CHARSET_ISO subject, quoted-printable encoding" \
		'^Subject: =\?'"${CHARSET_ISO}"'\?Q\?' \
		< <($PROG -d -q -C $CHARSET_ISO -s "$SUBJECT_ISO")
	run_test "short $CHARSET_ISO subject, base64 encoding" \
		'^Subject: =\?'"${CHARSET_ISO}"'\?B\?' \
		< <($PROG -d -m -C $CHARSET_ISO -s "$SUBJECT_ISO")
	run_test "short $CHARSET_ISO subject, 8bit encoding" \
		'^Subject: =\?'"${CHARSET_ISO}"'\?B\?' \
		< <($PROG -d -8 -C $CHARSET_ISO -s "$SUBJECT_ISO")
	run_test "short $CHARSET_ISO subject, uuencoding" \
		'^Subject: =\?'"${CHARSET_ISO}"'\?B\?' \
		< <($PROG -d -u -C $CHARSET_ISO -s "$SUBJECT_ISO")

	run_test "long $CHARSET_ISO subject, default encoding" \
		"^\t.*=?${CHARSET_ISO}?Q?" \
		< <($PROG -d -C $CHARSET_ISO -s "$SUBJECT2_ISO")
	run_test "long $CHARSET_ISO subject, quoted-printable encoding" \
		"^\t.*=?${CHARSET_ISO}?Q?" \
		< <($PROG -d -q -C $CHARSET_ISO -s "$SUBJECT2_ISO")
	run_test "long $CHARSET_ISO subject, base64 encoding" \
		"^\t.*=?${CHARSET_ISO}?B?" \
		< <($PROG -d -m -C $CHARSET_ISO -s "$SUBJECT2_ISO")
	run_test "long $CHARSET_ISO subject, 8bit encoding" \
		"^\t.*=?${CHARSET_ISO}?B?" \
		< <($PROG -d -8 -C $CHARSET_ISO -s "$SUBJECT2_ISO")
	run_test "long $CHARSET_ISO subject, uuencoding" \
		"^\t.*=?${CHARSET_ISO}?B?" \
		< <($PROG -d -u -C $CHARSET_ISO -s "$SUBJECT2_ISO")
}

# Run all attachment header tests
#
run_attachment_tests() {
	run_test 'content-md5: is present by default' \
		'^Content-MD5: ' \
		< <($PROG -d test/tick.png)
	run_test 'content-md5: is absent if requested' \
		'!^Content-MD5: ' \
		< <($PROG -d -D -i test/long-lines.txt)

	run_test 'text formatting is fixed by default' \
		'!; format="flowed"' \
		< <($PROG -d test/ascii.txt)
	run_test 'text formatting can be set to flowed' \
		'; format="flowed"' \
		< <($PROG -d -F test/ascii.txt)

	run_test 'content-transfer-encoding: default for fixed text/plain is quoted-printable' \
		'Transfer-Encoding: quoted-printable' \
		< <($PROG -d -r "$TO" test/ascii.txt)
	run_test 'content-transfer-encoding: default for flowed text/plain is 7bit' \
		'Transfer-Encoding: 7bit' \
		< <($PROG -d -r "$TO" -F test/ascii.txt)
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

	run_test 'content-type: text/plain is the default for stdin attachment in 1st place' \
		'^Content-Type: text/plain' \
		< <($PROG -d -i - < test/hydrazine.pdb)
	run_test 'content-type: text/plain is the default for stdin attachment in 2nd place' \
		'^Content-Type: text/plain' \
		< <($PROG -d -i test/msdos.html - < test/hydrazine.pdb)
	run_test 'content-type: text/html can be set on stdin attachment' \
		'^Content-Type: text/html' \
		< <($PROG -d -i -M text/html - < test/msdos.html)
	run_test 'content-type: application/pdf can be set on stdin attachment' \
		'^Content-Type: application/x-pdf' \
		< <(echo | $PROG -d -i -M application/x-pdf -)
	run_test 'content-type: image/png is inferred from filename correctly' \
		'^Content-Type: image/png' \
		< <($PROG -d test/tick.png)
	run_test 'content-type: application/octet-stream is used for unknown types' \
		'^Content-Type: application/octet-stream' \
		< <($PROG -d test/program)

	run_test 'filename is reported correctly for stdin attachment' \
		'^Content-Type: text/plain;.* name="stdin"' \
		< <($PROG -d - < test/ascii.txt)
	run_test 'filename is reported correctly for file attachment in ascii charset' \
		'^Content-Type: text/plain;.* name="ascii.txt"' \
		< <($PROG -d test/ascii.txt)
	run_test 'filename is reported correctly for file attachment in iso charset' \
		'^Content-Type: text/plain;.* name="ascii.txt"' \
		< <($PROG -d -C $CHARSET_ISO test/ascii.txt)

	run_test 'charset is reported correctly for file attachment in ascii charset' \
		'^Content-Type: text/plain; charset="us-ascii"' \
		< <(echo "$BODY_ASC" | $PROG -d -i -)
	run_test 'charset is reported correctly for file attachment in iso charset' \
		'^Content-Type: text/plain; charset="'$CHARSET_ISO'"' \
		< <($PROG -d -C $CHARSET_ISO test/ascii.txt)
	run_test 'charset is reported correctly for file attachment in russian charset' \
		'^Content-Type: text/plain; charset="'$CHARSET_RUS'"' \
		< <($PROG -d -C $CHARSET_RUS test/ascii.txt)
}

# Run all body tests
#
run_body_tests() {
	run_test 'can attach a text part in the ascii characterset, quoted-printable' \
		"^$BODY_ASC_QP" \
		< <(echo "$BODY_ASC" | $PROG -d -i -)
	run_test 'can attach a text part in the russian characterset, quoted-printable' \
		"$BODY_RUS_QP" \
		< <($PROG -d -i -q -C $CHARSET_RUS test/koi8-r.txt)
	run_test 'can attach a text part in the russian characterset, base64' \
		"$BODY_RUS_MM" \
		< <($PROG -d -i -m -C $CHARSET_RUS test/koi8-r.txt)
	run_test 'can attach a binary part, base64' \
		"$BODY_PNG_MM" \
		< <($PROG -d -m test/tick.png)
	run_test 'preserves line endings in binary parts, quoted-printable' \
		"$BODY_PNG_QP" \
		< <($PROG -d -q test/tick.png)
	run_test 'preserves line endings in format=fixed text parts, quoted-printable' \
		"$BODY_ASC_QP=0A=\r$" \
		< <(echo "$BODY_ASC" | $PROG -d -i -)
	run_test 'converts line endings in format=flowed text parts, quoted-printable' \
		"$BODY_ASC_QP\r$" \
		< <(echo "$BODY_ASC" | $PROG -d -i -F -)
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

