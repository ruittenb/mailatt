# Mailatt

Mailatt is a portable Unix/Linux shell script for sending mail with MIME attachments.

The Content-Type and Content-Transfer-Encoding are guessed, but can be overruled with command line options. There is support for HTML mail and non-ASCII character sets.

## Building:

It's ready to go!

## Example:


```
mailatt −s 'Filesystem usage' −r sysadmin@domain.nl -i message.html fsgraph−*.eps
```


## Installing:


```
make install
```

