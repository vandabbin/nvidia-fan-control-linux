FAN_CONTROL_SH = fan-control.sh
FAN_CONTROL = fan-control

INSTALL = install
PREFIX = /usr/local/bin

.NOTPARALLEL:

.PHONY: all
all:

.PHONY: install
install:
	$(INSTALL) -Dm 0755 $(FAN_CONTROL_SH) $(DESTDIR)$(PREFIX)/$(FAN_CONTROL)

.PHONY: uninstall
uninstall:
	$(RM) $(DESTDIR)$(PREFIX)/$(FAN_CONTROL)

.PHONY: clean
clean:

