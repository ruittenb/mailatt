NULL    = /dev/null
SHEBANG = $(shell if which bash 1>$(NULL) 2>&1; then echo bash; elif which ksh 1>$(NULL) 2>&1; then echo ksh; else echo false; exit 1; fi)
PROG    = mailatt
SECTION = 1
PODOPTS = --release=' ' --center=' ' --date=`date +%Y-%m-%d` \
	  --section=$(SECTION) --name=$(PROG)
FROM    = quelquun@nimporte.ou
TO      = 'Recipient <recipient@example.com>'
CC      = copied-person@example.com
SUBJECT = 'The files you requested'
HEADER  = 'X-Testing: testing'
BODY    = 'Message body'
CHARSET = ISO-8859-15

.DEFAULT_GOAL:=help

# Automatic self-documentation
.PHONY: help
help: ## Display this help
	@awk 'BEGIN { FS = ":.*## "; tab = 16; color = "\033[36m"; indent = "  "; printf "\nUsage:\n  make " color "<target>\033[0m\n\nRecognized targets:\n" } /^[a-zA-Z0-9%_-]+:.*?## / { pad = sprintf("\n%" tab "s" indent, "", $$2); gsub(/\\n/, pad); printf indent color "%-" tab "s\033[0m%s\n", $$1, $$2 } /^##@ / { gsub(/\\n/, "\n"); printf "\n%s\n", substr($$0, 5) } END { print "" }' $(MAKEFILE_LIST) # v1.43

.PHONY: all
all: shebang mandoc ## Fix shebang line in script file; generate manpage (all formats)

.PHONY: shebang
shebang: $(PROG) ## Fix shebang line in script file
	sed -i.bak 's,^#!.*,#!/usr/bin/env $(SHEBANG),' $(PROG)

.PHONY: man
man: $(PROG).$(SECTION) ## Generate manpage (nroff format)

.PHONY: mandoc
mandoc: $(PROG).pdf ## Generate manpage (ps and pdf format)

.PHONY: readman
readman: $(PROG).$(SECTION) ## Display the manpage
	man ./$(PROG).$(SECTION)

$(PROG).$(SECTION): $(PROG)
	pod2man $(PODOPTS) $< | sed 's/@(#)ms.acc/ms.acc/' > $@

$(PROG).ps: $(PROG).$(SECTION)
	groff -man -Tps $< > $@

$(PROG).pdf: $(PROG).ps
	ps2pdf $<

.PHONY: test
test: $(PROG) ## Run simple tests
	@./$(PROG) -h |                                                 \
		grep '^Usage:' >$(NULL) &&				\
		echo 'Test  0 succesful (usage)'
	@./$(PROG) -d |                                                 \
		grep '^Content-Type: multipart/mixed' >$(NULL) &&       \
		echo 'Test  1 succesful (content-type)'
	@./$(PROG) -d -a |                                              \
		grep '^Content-Type: multipart/alternative' >$(NULL) && \
		echo 'Test  2 succesful (content-type)'
	@./$(PROG) -d -r $(TO) |                                        \
		grep '^To: '$(TO) >$(NULL) &&                           \
		echo 'Test  3 succesful (recipient)'
	@./$(PROG) -d -c $(CC) |                                        \
		grep '^Cc: <$(CC)>' >$(NULL) &&                         \
		echo 'Test  4 succesful (cc)'
	@./$(PROG) -d -f $(FROM) |                                      \
		grep '^From: <$(FROM)>' >$(NULL) &&                     \
		echo 'Test  5 succesful (from)'
	@./$(PROG) -d -s $(SUBJECT) |                                   \
		grep '^Subject: '$(SUBJECT) >$(NULL) &&                 \
		echo 'Test  6 succesful (subject)'
	@./$(PROG) -d -H $(HEADER) |                                    \
		grep '^'$(HEADER) >$(NULL) &&                           \
		echo 'Test  7 succesful (header)'
	@./$(PROG) -d -C $(CHARSET) -q -r $(TO) |                       \
		grep '^To: =?ISO-8859-15?Q?Recipient?= ' >$(NULL) &&    \
		echo 'Test  8 succesful (content-transfer-encoding)'
	@./$(PROG) -d -C $(CHARSET) -m -r $(TO) |                       \
		grep '^To: =?ISO-8859-15?B?UmVjaXBpZW50?= ' >$(NULL) && \
		echo 'Test  9 succesful (content-transfer-encoding)'
	@./$(PROG) -d -r $(TO) -q mailatt |                             \
		grep 'Transfer-Encoding: quoted-printable' >$(NULL) &&  \
		echo 'Test 10 succesful (content-transfer-encoding)'
	@./$(PROG) -d -r $(TO) -m mailatt |                             \
		grep 'Transfer-Encoding: base64' >$(NULL) &&            \
		echo 'Test 11 succesful (content-transfer-encoding)'
	@./$(PROG) -d -r $(TO) -u mailatt |                             \
		grep 'Transfer-Encoding: uuencode' >$(NULL) &&          \
		echo 'Test 12 succesful (content-transfer-encoding)'
	@./$(PROG) -d -r $(TO) -u mailatt |                             \
		grep '^begin 755 mailatt' >$(NULL) &&                   \
		echo 'Test 13 succesful (uuencode mode line)'
	@./$(PROG) -d -i test/msdos.html test/tick.png |                \
		grep -v '^Content-MD5: ' >$(NULL) &&                    \
		echo 'Test 14 succesful (content-md5)'
	@! ./$(PROG) -d -D -i test/long-lines.txt |                     \
		grep -v 'Content-MD5: ' |                               \
		grep '^Content-MD5: ' >$(NULL) &&                       \
		echo 'Test 15 succesful (content-md5)'
	@echo | ./$(PROG) -d -i - |                                     \
		grep '^Content-Disposition: inline' >$(NULL) &&         \
		echo 'Test 16 succesful (content-disposition)'
	@echo | ./$(PROG) -d - |                                        \
		grep '^Content-Disposition: attachment' >$(NULL) &&     \
		echo 'Test 17 succesful (content-disposition)'
	@echo | ./$(PROG) -d -i -M text/html - |                        \
		grep '^Content-Type: text/html' >$(NULL) &&             \
		echo 'Test 18 succesful (mime type)'
	@echo | ./$(PROG) -d -i -M application/x-pdf - |                \
		grep '^Content-Type: application/x-pdf' >$(NULL) &&     \
		echo 'Test 19 succesful (mime type)'
	@echo $(BODY) | ./$(PROG) -d -i - |                             \
		grep '^'$(BODY) >$(NULL) &&                             \
		echo 'Test 20 succesful (body)'

.PHONY: install
install: $(PROG) ## Copy script and manpage to system directories
	./install.sh

.PHONY: bump-patchlevel
bump-patchlevel: ## increment the script version by 0.0.1
	perl -i.bak -pe 's{^((?:# Version:\s+|\.ds Vw @.#. mailatt )\d+\.\d+)\.?(\d*)} \
			  {$$1 . "." . ($$2 + 1)}e' $(PROG)
	@echo New version: `./mailatt -v`

.PHONY: dump-minor
bump-minor: ## increment the script version by 0.1
	perl -i.bak -pe 's{^((?:# Version:\s+|\.ds Vw @.#. mailatt )\d+)\.(\d+)\.?\d*} \
			  {$$1 . "." . ($$2 + 1)}e' $(PROG)
	@echo New version: `./mailatt -v`

.PHONY: tag
tag: ## create a tag that corresponds to the script version number
	git tag v$$(awk '/^# Version/{ print $$3 }' mailatt)

.PHONY: clean
clean: ## Remove the manpages
	rm -f $(PROG).$(SECTION) $(PROG).ps $(PROG).pdf

.PHONY: distclean
distclean: clean ## Cleanup and prepare for distribution
	rm -f config.* $(PROG).bak

