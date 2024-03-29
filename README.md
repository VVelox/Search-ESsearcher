# About

![essearcher](essearcher.png)

It provides a dynamic system for searching logs stored in
Elasticsearch. Currently it has out of the box support for the items below.

* [syslog](https://metacpan.org/pod/Search::ESsearcher::Templates::syslog)
* [postfix](https://metacpan.org/pod/Search::ESsearcher::Templates::postfix)
* [fail2ban via filebeat](https://metacpan.org/pod/Search::ESsearcher::Templates::bf2b)
* [HTTP access via filebeat](https://metacpan.org/pod/Search::ESsearcher::Templates::httpAccess)

# Configuring

If elasticsearch is not running on the same machine, then you will
need to setup the elastic file. By default this is
~/.config/essearcher/elastic/default . If not configured, the default
is as below.

```
{ "nodes": [ "127.0.0.1:9200" ] }
```

So if you want to set it to use ES on the server foo.bar, it would be
as below.

```
{ "nodes": [ "foo.bar:9200" ] }
```

The elastic file is JSON that will be passed to hash and passed to
[Search::Elasticsearch](https://metacpan.org/pod/Search::Elasticsearch)->new.

# As A Nagios Style Check

This requires three options, -n, -w, -c.

```
-n <check>
-w <warn>
-c <critical>

Check is the equality to use when comparing the number of hits found
for the search.

gt >
gte >=
lt <
lte <=

Critical and warn are the thresholds to use.
```

So for example for httpAccess if we want to alert for number of times
robots.txt is requested, we would do it like below.

```
essearcher -m httpAccess --dgte -5m --req robots.txt -n gt -w 2 -c 5
```

This will search for requests with 'robots.txt' in it within the last
5 minutes and will warn if the number of hits are great than 2 and go
critical if greater than 5.

# Extending

It has 5 parts that are listed below.

* options : [Getopt::Long](https://perldoc.perl.org/Getopt/Long.html)
  options that are parsed after the initial basic options. These are
  stored and used with the search and output template.
* elastic : This is a JSON that contains the options that will be used
  to initialize [Search::Elasticsearch](https://metacpan.org/pod/Search::Elasticsearch).
* search : This is a [Template](https://metacpan.org/pod/Template)
  template that will be fed to [Search::Elasticsearch](https://metacpan.org/pod/Search::Elasticsearch)->search.
* output : This is a [Template](https://metacpan.org/pod/Template)
  template that will be be used on each found item.

It will search for those specified in the following order.

1. $ENV{'HOME'}.'/.config/essearcher/'.$part.'/'.$name
1. $base.'/etc/essearcher/'.$part.'/'.$name
1. Search::ESsearcher::Templates::$name->$part (except for elastic)

# INSTALLING

## FreeBSD

```
pkg install perl5 p5-JSON p5-Error-Helper p5-Template p5-Template-Plugin-JSON p5-Time-ParseDate p5-Term-ANSIColor p5-Data-Dumper
cpanm Search::ESsearcher
```

## Linux

### CentOS

```
yum install cpanm
cpanm Search::ESsearcher
```

### Debian

```
apt install perl perl-base perl-modules make cpanminus
cpanm Search::ESsearcher
```

# Caveat

Please be aware that if a similar search has not been ran for awhile,
Elasticsearch will likely return a buggy/empty result that can't be
used. The usual return when this happens is empty JSON just containing
the key 'hits', which can be viewed via switch -R. When this happens,
just wait a few minutes or so to try again and Elasticsearch should
have reindex/cached/etc.

