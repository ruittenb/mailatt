NULL    = /dev/null
SHEBANG = $(shell which bash 2>$(NULL) || which ksh 2>$(NULL) || which sh 2>$(NULL))
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
	@awk 'BEGIN { FS = ":.*## "; tab = 12; color = "\033[36m"; indent = "  "; printf "\nUsage:\n  make " color "<target>\033[0m\n\nRecognized targets:\n" } /^[a-zA-Z0-9%_-]+:.*?## / { pad = sprintf("\n%" tab "s" indent, "", $$2); gsub(/\\n/, pad); printf indent color "%-" tab "s\033[0m%s\n", $$1, $$2 } /^##@ / { gsub(/\\n/, "\n"); printf "\n%s\n", substr($$0, 5) } END { print "" }' $(MAKEFILE_LIST) # v1.43

.PHONY: all
all: bin mandoc ## Fix shebang line in script file; generate manpage (all formats)

.PHONY: bin
bin: $(PROG) ## Fix shebang line in script file
	sed -i.bak 's,^#!.*,#!$(SHEBANG),' $<

.PHONY: man
man: $(PROG).$(SECTION) ## Generate manpage (nroff format)

.PHONY: mandoc
mandoc: $(PROG).pdf ## Generate manpage (ps and pdf format)

$(PROG).$(SECTION): $(PROG)
	pod2man $(PODOPTS) $< | sed 's/@(#)ms.acc/ms.acc/' > $@

$(PROG).ps: $(PROG).$(SECTION)
	groff -man -Tps $< > $@

$(PROG).pdf: $(PROG).ps
	ps2pdf $<

.PHONY: test
test: $(PROG) ## Run simple test
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
	@echo | ./$(PROG) -d -i - |                                     \
		grep '^Content-Disposition: inline' >$(NULL) &&         \
		echo 'Test 10 succesful (content-disposition)'
	@echo | ./$(PROG) -d - |                                        \
		grep '^Content-Disposition: attachment' >$(NULL) &&     \
		echo 'Test 11 succesful (content-disposition)'
	@echo | ./$(PROG) -d -i -M text/html - |                        \
		grep '^Content-Type: text/html' >$(NULL) &&             \
		echo 'Test 12 succesful (mime type)'
	@echo | ./$(PROG) -d -i -M application/x-pdf - |                \
		grep '^Content-Type: application/x-pdf' >$(NULL) &&     \
		echo 'Test 13 succesful (mime type)'
	@echo $(BODY) | ./$(PROG) -d -i - |                             \
		grep '^'$(BODY) >$(NULL) &&                             \
		echo 'Test 14 succesful (body)'

.PHONY: install
install: $(PROG) ## Copy binary and manpage to system directories
	./install.sh

.PHONY: clean
clean: ## Remove the manpages
	rm -f $(PROG).$(SECTION) $(PROG).ps $(PROG).pdf

.PHONY: distclean
distclean: clean ## Cleanup and prepare for distribution
	rm -f config.* $(PROG).bak

