# Mailatt

Mailatt is a portable Unix/Linux shell script for sending mail with MIME attachments.

It supports command-line specifiable Content-Type and Content-Transfer-Encoding with
sensible defaults.  There is support for HTML mail and non-ASCII character sets.

## Building:

The first (shebang) line may need fixing:

```
make shebang
```

## Example:

```
mailatt -i −s 'Filesystem usage' −r sysadmin@domain.nl message.html fsgraph−*.pdf
```

## Installing:

```
make install
```

