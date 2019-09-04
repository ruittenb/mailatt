NULL    = /dev/null
SHEBANG = $(shell if which bash 1>$(NULL) 2>&1; then echo bash; elif which ksh 1>$(NULL) 2>&1; then echo ksh; else echo sh; fi)
PROG    = mailatt
SECTION = 1
BAK     =
PODOPTS = --release=' ' --center=' ' --date=`date +%Y-%m-%d` \
	  --section=$(SECTION) --name=$(PROG)

.DEFAULT_GOAL:=help

# Automatic self-documentation
.PHONY: help
help: ## Print help for each target
	@awk -v tab=16 'BEGIN { FS = ":.*## "; buffer = ""; color = "\033[36m"; nocolor = "\033[0m"; indent = "  "; usage(); } function trim(str) { gsub(/[ \t]+$$/, "", str); gsub(/^[ \t]+/, "", str); return str; } function spout(target, desc) { split(trim(target), fields, " "); for (i in fields) printf "%s%s%-" tab "s%s%s\n", indent, color, trim(fields[i]), nocolor, desc; } function usage() { printf "\nUsage:\n%smake %s<target>%s\n\nRecognized targets:\n", indent, color, nocolor; } /\\$$/ { gsub(/\\$$/, ""); buffer = buffer $$0; next; } buffer { $$0 = buffer $$0; buffer = ""; } /^[-a-zA-Z0-9*/%_. ]+:.*## / { pad = sprintf("\n%" tab "s" indent, ""); gsub(/\\n/, pad); spout($$1, $$2); } /^##@ / { gsub(/\\n/, "\n"); printf "\n%s\n", substr($$0, 5) } END { print "" }' $(MAKEFILE_LIST) # v1.54


.PHONY: all
all: shebang mandoc ## Fix shebang line in script file; generate manpage (all formats)

.PHONY: shebang
shebang: $(PROG) ## Fix shebang line in script file
	sed -i "$(BAK)" 's,^#!.*,#!/usr/bin/env $(SHEBANG),' $(PROG)

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
	./test.sh

.PHONY: install
install: $(PROG) ## Copy script and manpage to system directories
	./install.sh $(PROG) $(SECTION)

.PHONY: bump-patchlevel
bump-patchlevel: ## increment the script version by 0.0.1
	perl -i"$(BAK)" -pe 's{^((?:# Version:\s+|\.ds Vw @.#. mailatt )\d+\.\d+)\.?(\d*)} \
			  {$$1 . "." . ($$2 + 1)}e' $(PROG)
	@echo New version: `./mailatt -v`

.PHONY: dump-minor
bump-minor: ## increment the script version by 0.1
	perl -i"$(BAK)" -pe 's{^((?:# Version:\s+|\.ds Vw @.#. mailatt )\d+)\.(\d+)\.?\d*} \
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
	rm -f config.* $(PROG)$(BAK)

