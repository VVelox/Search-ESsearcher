package Search::ESsearcher::Templates::syslog;

use 5.006;
use strict;
use warnings;

=head1 NAME

Search::ESsearcher::Templates::syslog - Provides a basic syslog template 

=head1 VERSION

Version 0.0.0

=cut

our $VERSION = '0.0.0';


=head1 SYNOPSIS

    use Search::ESsearcher::Templates::syslog;

    my $options = Search::ESsearcher::Templates::syslog->options;
    my $search = Search::ESsearcher::Templates::syslog->search;
    my $output = Search::ESsearcher::Templates::syslog->output;

=head1 LOGSTASH

This uses a logstash configuration below.

    input {
      syslog {
        host => "10.10.10.10"
        port => 11514
        type => "syslog"
      }
    }
    
    filter { }
    
    output {
      if [type] == "syslog" {
        elasticsearch {
          hosts => [ "127.0.0.1:9200" ]
        }
      }
    }

=cut


sub search{
return '
[% USE JSON ( pretty => 1 ) %]
[% DEFAULT o.host = "*" %]
[% DEFAULT o.src = "*" %]
[% DEFAULT o.program = "*" %]
[% DEFAULT o.facility = "*" %]
[% DEFAULT o.severity = "*" %]
[% DEFAULT o.pid = "*" %]
[% DEFAULT o.msg = "*" %]
[% DEFAULT o.size = "50" %]
[% DEFAULT o.field = "type" %]
[% DEFAULT o.fieldv = "syslog" %]
{
 "index": "logstash-*",
 "body": {
	 "size": [% o.size.json %],
	 "query": {
		 "bool": {
			 "must": [
					  {
					   "term": { [% o.field.json %]: [% o.fieldv.json %] } },
					  {"query_string": {
						  "default_field": "host",
						  "query": [% aon( o.host ).json %]
					  }
					   },
					  {"query_string": {
						  "default_field": "logsource",
						  "query": [% aon( o.src ).json %]
					  }
					   },
					  {"query_string": {
						  "default_field": "program",
						  "query": [% aon( o.program ).json %]
					  }
					   },
					  {"query_string": {
						  "default_field": "facility_label",
						  "query": [% aon( o.facility ).json %]
					  }
					   },
					  {"query_string": {
						  "default_field": "severity_label",
						  "query": [% aon( o.severity ).json %]
					  }
					   },
					  {"query_string": {
						  "default_field": "pid",
						  "query": [% aon( o.pid ).json %]
					  }
					   },
					  {"query_string": {
						  "default_field": "message",
						  "query": [% o.msg.json %]
					  }
					   },
					  [% IF o.dgt %]
					  {"range": {
						  "@timestamp": {
							  "gt": [% pd( o.dgt ).json %]
						  }
					  }
					   },
					  [% END %]
					  [% IF o.dgte %]
					  {"range": {
						  "@timestamp": {
							  "gte": [% pd( o.dgte ).json %]
						  }
					  }
					   },
					  [% END %]
					  [% IF o.dlt %]
					  {"range": {
						  "@timestamp": {
							  "lt": [% pd( o.dlt ).json %]
						  }
					  }
					   },
					  [% END %]
					  [% IF o.dlte %]
					  {"range": {
						  "@timestamp": {
							  "lte": [% pd( o.dlte ).json %]
						  }
					  }
					   },
					  [% END %]
					  ]
		 }
	 },
	 "sort": [
			  {
			   "@timestamp": {"order" : "desc"}}
			  ]
 }
 }
';
}

sub options{
return '
log=s
host=s
src=s
program=s
size=s
facility=s
severity=s
pid=s
dgt=s
dgte=s
dlt=s
dlte=s
msg=s
';
}

sub output{
	return '[% c("cyan") %][% f.timestamp %] [% c("bright_blue") %][% f.logsource %] '.
	'[% c("bright_green") %][% f.program %][% c("bright_magenta") %][[% c("bright_yellow") %]'.
	'[% f.pid %][% c("bright_magenta") %]] [% c("white") %][% f.message %]';
}
