package Search::ESsearcher;

use 5.006;
use base Error::Helper;
use strict;
use warnings;
use Getopt::Long;
use JSON;
use Template;
use Search::Elasticsearch;
use Term::ANSIColor;
use Time::ParseDate;

=head1 NAME

Search::ESsearcher - The great new Search::ESsearcher!

=head1 VERSION

Version 0.0.0

=cut

our $VERSION = '0.0.0';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Search::ESsearcher;

    my $ess = Search::ESsearcher->new();

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 METHODS

=head2 new

This initiates the object.

    my $ss=Search::ESsearcher->new;

=cut

sub new{

	my $self = {
				perror=>undef,
				error=>undef,
				errorString=>"",
				base=>undef,
				search=>'syslog',
				search_template=>undef,
				search_filled_in=>undef,
				search_usable=>undef,
				output=>'syslog',
				output_template=>undef,
				options=>'syslog',
				options_array=>undef,
				elastic=>'default',
				elastic_hash=>{
						  nodes => [
								   '127.0.0.1:9200'
								   ]
						  },
				errorExtra=>{
							 flags=>{
									 '1'=>'IOerror',
									 '2'=>'NOfile',
									 '3'=>'nameInvalid',
									 '4'=>'searchNotUsable',
									 '5'=>'elasticNotLoadable',
									 '6'=>'notResults',
									 }
							 },
				};
    bless $self;

	# finds the etc base to use
	if ( -d '/usr/local/etc/essearch/' ) {
		$self->{base}='/usr/local/etc/essearch/';
	} elsif ( -d '/etc/essearch/' ) {
		$self->{base}='/etc/essearch/';
	} elsif ( $0 =~ /bin\/essearcher$/ ) {
		$self->{base}=$0;
		$self->{base}=~s/\/bin\/essearcher$/\/etc\/essearch\//;
	}

	# inits Template
	$self->{t}=Template->new({
							  EVAL_PERL=>1,
							  INTERPOLATE=>1,
							  POST_CHOMP=>1,
							  });

	# inits JSON
	$self->{j}=JSON->new;
	$self->{j}->pretty(1); # make the output sanely human readable
	$self->{j}->relaxed(1); # make writing search templates a bit easier

	return $self;
}

=head elastic_get

This returns what Elasticsearch config will be used.

    my $elastic=$ess->elastic_get;

=cut

sub elastic_get{
	my $self=$_[0];
	my $name=$_[1];

	if ( ! $self->errorblank ) {
        return undef;
    }

	return $self->{elastic};
}

=head elastic_set

This sets the name of the config file to use.

One option is taken and name of the config file to load.

Undef sets it back to the default, "default".

    $ess->elastic_set('foo');

    $ess->elastic_set(undef);

=cut

sub elastic_set{
	my $self=$_[0];
	my $name=$_[1];

	if ( ! $self->errorblank ) {
        return undef;
    }

	if (! $self->name_validate( $name ) ){
		$self->{error}=3;
		$self->{errorString}='"'.$name.'" is not a valid name';
		$self->warn;
		return undef;
	}

	if( !defined( $name ) ){
		$name='default';
	}

	$self->{elastic}=$name;

	return 1;
}


=head2 get_options

This fetches the options.

=cut

sub get_options{
	my $self=$_[0];

	if ( ! $self->errorblank ) {
        return undef;
    }

	my %parsed_options;

	GetOptions( \%parsed_options, @{ $self->{options_array} } );


	$self->{parsed_options}=\%parsed_options;

	return 1;
}

=head2 load_options

=cut

sub load_options{
	my $self=$_[0];

	if ( ! $self->errorblank ) {
        return undef;
    }

	my $file;
	my $data;

	# ~/ -> etc -> module -> error
	if (
		( defined( $ENV{'HOME'} ) ) &&
		( -f $ENV{'HOME'}.'/.config/essearcher/options/'.$self->{options} )
		) {
		$file=$ENV{'HOME'}.'/.config/essearcher/options/'.$self->{options};
	} elsif (
			 ( defined( $self->{base} ) ) &&
			 ( -f $self->{base}.'/etc/essearcher/options/'.$self->{options} )
			 ) {
		$file=$self->{base}.'/etc/essearcher/options/'.$self->{options};
	} else {
		# do a quick check of making sure we have a valid name before trying a module...
		# not all valid names are perl module name valid, but it will prevent arbitrary code execution
		if ( $self->name_validate( $self->{options} ) ){
			my $to_eval='use Search::ESsearcher::Templates::'.$self->{options}.
			'; $data=Search::ESsearcher::Templates::'.$self->{options}.'->options;';
			eval( $to_eval );
		}
		# if undefined, it means the eval failed
		if ( ! defined( $data ) ){
			$self->{error}=2;
			$self->{errorString}='No options file or module with the name "'.$self->{options}.'" was found';
			$self->warn;
			return undef;
		}
	}

	if ( defined( $file ) ) {
		my $fh;
		if (! open($fh, '<', $file ) ) {
			$self->{error}=1;
			$self->{errorString}='Failed to open "'.$file.'"',
			$self->warn;
			return undef;
		}
		# if it is larger than 2M bytes, something is wrong as the options
		# it takes is literally longer than all HHGTTG books combined
		if (! read($fh, $data, 200000000 )) {
			$self->{error}=1;
			$self->{errorString}='Failed to read "'.$file.'"',
			$self->warn;
			return undef;
		}
		close($fh);
	}

	# split it appart and remove comments and blank lines
	my @options=split(/\n/,$data);
	@options=grep(!/^#/, @options);
	@options=grep(!/^$/, @options);

	# we have now completed with out error, so save it
	$self->{options_array}=\@options;

	return 1;
}

=head2 load_output

=cut

sub load_elastic{
	my $self=$_[0];

	if ( ! $self->errorblank ) {
        return undef;
    }

	my $file=undef;

	# ~/ -> etc -> error
	if (
		( defined( $ENV{'HOME'} ) ) &&
		( -f $ENV{'HOME'}.'/.config/essearcher/elastic/'.$self->{elastic} )
		) {
		$file=$ENV{'HOME'}.'/.config/essearcher/elastic/'.$self->{elastic};
	} elsif (
			 ( defined( $self->{base} ) ) &&
			 ( -f $self->{base}.'/etc/essearcher/elastic/'.$self->{elastic} )
			 ) {
		$file=$self->{base}.'/etc/essearcher/elastic/'.$self->{elastic};
	} else {
		$self->{elastic_hash}={
								nodes => [
										  '127.0.0.1:9200'
										  ]
							   };
	}

	if (defined( $file )) {
		my $fh;
		if (! open($fh, '<', $file ) ) {
			$self->{error}=1;
			$self->{errorString}='Failed to open "'.$file.'"',
			$self->warn;
			return undef;
		}
		my $data;
		# if it is larger than 2M bytes, something is wrong as the template
		# it takes is literally longer than all HHGTTG books combined
		if (! read($fh, $data, 200000000 )) {
			$self->{error}=1;
			$self->{errorString}='Failed to read "'.$file.'"',
			$self->warn;
			return undef;
		}
		close($fh);

		eval {
			my $decoded=$self->{j}->decode( $data );
			$self->{elastic_hash}=$decoded;
		};
		if ( $@ ){
			$self->{error}=5;
			$self->{errorString}=$@;
			$self->warn;
			return undef;
		}

	}

	eval{
		$self->{es}=Search::Elasticsearch->new( $self->{elastic_hash} );
		};
	if ( $@ ){
		$self->{error}=5;
		$self->{errorString}=$@;
		$self->warn;
		return undef;
	}

	return 1;
}

=head2 load_output

=cut

sub load_output{
	my $self=$_[0];

	if ( ! $self->errorblank ) {
        return undef;
    }

	my $file=undef;
	my $data=undef;

	# ~/ -> etc -> module -> error
	if (
		( defined( $ENV{'HOME'} ) ) &&
		( -f $ENV{'HOME'}.'/.config/essearcher/output/'.$self->{output} )
		) {
		$file=$ENV{'HOME'}.'/.config/essearcher/output/'.$self->{output};
	} elsif (
			 ( defined( $self->{base} ) ) &&
			 ( -f $self->{base}.'/etc/essearcher/output/'.$self->{output} )
			 ) {
		$file=$self->{base}.'/etc/essearcher/outpot/'.$self->{output};
	} else {
		# do a quick check of making sure we have a valid name before trying a module...
		# not all valid names are perl module name valid, but it will prevent arbitrary code execution
		if ( $self->name_validate( $self->{options} ) ) {
			my $to_eval='use Search::ESsearcher::Templates::'.$self->{output}.
			'; $data=Search::ESsearcher::Templates::'.$self->{output}.'->output;';
			eval( $to_eval );
		}
		# if undefined, it means the eval failed
		if ( ! defined( $data ) ) {
			$self->{error}=2;
			$self->{errorString}='No options file with the name "'.$self->{output}.'" was found';
			$self->warn;
			return undef;
		}
	}

	if ( ! defined( $data ) ) {
		my $fh;
		if (! open($fh, '<', $file ) ) {
			$self->{error}=1;
			$self->{errorString}='Failed to open "'.$file.'"',
			$self->warn;
			return undef;
		}
		# if it is larger than 2M bytes, something is wrong as the template
		# it takes is literally longer than all HHGTTG books combined
		if (! read($fh, $data, 200000000 )) {
			$self->{error}=1;
			$self->{errorString}='Failed to read "'.$file.'"',
			$self->warn;
			return undef;
		}
		close($fh);
	}

	# we have now completed with out error, so save it
	$self->{output_template}=$data;

}

=head2 load_search

=cut

sub load_search{
	my $self=$_[0];

	if ( ! $self->errorblank ) {
        return undef;
    }

	my $file=undef;
	my $data;

	# ~/ -> etc -> module -> error
	if (
		( defined( $ENV{'HOME'} ) ) &&
		( -f $ENV{'HOME'}.'/.config/essearcher/search/'.$self->{search} )
		) {
		$file=$ENV{'HOME'}.'/.config/essearcher/search/'.$self->{search};
	} elsif (
			 ( defined( $self->{base} ) ) &&
			 ( -f $self->{base}.'/etc/essearcher/search/'.$self->{search} )
			 ) {
		$file=$self->{base}.'/etc/essearcher/search/'.$self->{search};
	} else {
		# do a quick check of making sure we have a valid name before trying a module...
		# not all valid names are perl module name valid, but it will prevent arbitrary code execution
		if ( $self->name_validate( $self->{options} ) ){
			my $to_eval='use Search::ESsearcher::Templates::'.$self->{options}.
			'; $data=Search::ESsearcher::Templates::'.$self->{options}.'->search;';
			eval( $to_eval );
		}
		# if undefined, it means the eval failed
		if ( ! defined( $data ) ){
			$self->{error}=2;
			$self->{errorString}='No template file with the name "'.$self->{search}.'" was found';
			$self->warn;
			return undef;
		}
	}

	if ( ! defined( $data ) ) {
		my $fh;
		if (! open($fh, '<', $file ) ) {
			$self->{error}=1;
			$self->{errorString}='Failed to open "'.$file.'"',
			$self->warn;
			return undef;
		}
		# if it is larger than 2M bytes, something is wrong as the template
		# it takes is literally longer than all HHGTTG books combined
		if (! read($fh, $data, 200000000 )) {
			$self->{error}=1;
			$self->{errorString}='Failed to read "'.$file.'"',
			$self->warn;
			return undef;
		}
		close($fh);
	}

	# we have now completed with out error, so save it
	$self->{search_template}=$data;

	return 1;
}

=head2 name_valide

=cut

sub name_validate{
	my $self=$_[0];
	my $name=$_[1];

	if ( ! $self->errorblank ) {
        return undef;
    }

	if (! defined( $name ) ){
		return 1;
	}

	$name=~s/[A-Za-z\:\-\=\_+\ ]+//;

	if ( $name !~ /^$/ ){
		return undef;
	}

	return 1;
}

=head options_get

=cut

sub options_get{
	my $self=$_[0];

	if ( ! $self->errorblank ) {
        return undef;
    }

	return $self->{options};
}

=head options_set

=cut

sub options_set{
	my $self=$_[0];
	my $name=$_[1];

	if ( ! $self->errorblank ) {
        return undef;
    }

	if (! $self->name_validate( $name ) ){
		$self->{error}=3;
		$self->{errorString}='"'.$name.'" is not a valid name';
		$self->warn;
		return undef;
	}

	if( !defined( $name ) ){
		$name='syslog';
	}

	$self->{options}=$name;

	return 1;
}

=head output_get

=cut

sub output_get{
	my $self=$_[0];
	my $name=$_[1];

	if ( ! $self->errorblank ) {
        return undef;
    }

	return $self->{output};
}

=head output_set

=cut

sub output_set{
	my $self=$_[0];
	my $name=$_[1];

	if ( ! $self->errorblank ) {
        return undef;
    }

	if (! $self->name_validate( $name ) ){
		$self->{error}=3;
		$self->{errorString}='"'.$name.'" is not a valid name';
		$self->warn;
		return undef;
	}

	if( !defined( $name ) ){
		$name='syslog';
	}

	$self->{output}=$name;

	return 1;
}

=head2 results_process

=cut

sub results_process{
	my $self=$_[0];
	my $results=$_[1];

	if ( ! $self->errorblank ) {
        return undef;
    }

	#make sure we have a sane object passed to us
	if (
		( ref( $results ) ne 'HASH' ) ||
		( !defined( $results->{hits} ) )||
		( !defined( $results->{hits}{hits} ) )
		){
		$self->{error}=6;
		$self->{errorString}='The passed results variable does not a appear to be a search results return';
		$self->warn;
		return undef;
	}

	#use Data::Dumper;
	#print Dumper( $results->{hits}{hits} );

	my $vars={
			  o=>$self->{parsed_options},
			  r=>$results,
			  c=>sub{ return color( $_[0] ); },
			  pd=>sub{
				  if( $_[0] =~ /^raw\:/ ){
					  $_[0] =~ s/^raw\://;
					  return $_[0];
				  }
				  $_[0]=~s/m$/minutes/;
				  $_[0]=~s/M$/months/;
				  $_[0]=~s/d$/days/;
				  $_[0]=~s/h$/hours/;
				  $_[0]=~s/h$/weeks/;
				  $_[0]=~s/y$/years/;
				  $_[0]=~s/([0123456789])$/$1seconds/;
				  $_[0]=~s/([0123456789])s$/$1seconds/;
				  my $secs="";
				  eval{ $secs=parsedate( $_[0] ); };
				  return $secs;
			  },
			  };

	my @formatted;
	foreach my $doc ( @{ $results->{hits}{hits} } ){
		$vars->{doc}=$doc;
		$vars->{f}=$doc->{_source};

		my $processed;
		$self->{t}->process( \$self->{output_template}, $vars , \$processed );
		chomp($processed);

		push(@formatted,$processed);
	}

	@formatted=reverse(@formatted);

	my $formatted_string=join("\n", @formatted);

	print $formatted_string;
}

=head search_get

=cut

sub search_get{
	my $self=$_[0];
	my $name=$_[1];

	if ( ! $self->errorblank ) {
        return undef;
    }

	return $self->{search};
}

=head2 search_fill_in

=cut

sub search_fill_in{
	my $self=$_[0];
	my $name=$_[1];

	if ( ! $self->errorblank ) {
        return undef;
    }

	my $vars={
			  o=>$self->{parsed_options},
			  pd=>sub{
				  if( $_[0] =~ /^raw\:/ ){
					  $_[0] =~ s/^raw\://;
					  return $_[0];
				  }
				  $_[0]=~s/m$/minutes/;
				  $_[0]=~s/M$/months/;
				  $_[0]=~s/d$/days/;
				  $_[0]=~s/h$/hours/;
				  $_[0]=~s/h$/weeks/;
				  $_[0]=~s/y$/years/;
				  $_[0]=~s/([0123456789])$/$1seconds/;
				  $_[0]=~s/([0123456789])s$/$1seconds/;
				  my $secs="";
				  eval{ $secs=parsedate( $_[0] ); };
				  return $secs;
        },
			  };

	my $processed;
	$self->{t}->process( \$self->{search_template}, $vars , \$processed );

	$self->{search_filled_in}=$processed;

	$self->{search_usable}=undef;

	eval {
		my $decoded=$self->{j}->decode( $processed );
		$self->{search_hash}=$decoded;
		 };
	if ( $@ ){
		$self->{error}=4;
		$self->{errorString}='The returned filled in search template does not parse as JSON... '.$@;
		$self->warn;
		return $processed;
	}

	return $processed;
}

=head2 search_run

=cut

sub search_run{
	my $self=$_[0];
	my $name=$_[1];

	if ( ! $self->errorblank ) {
        return undef;
    }

	my $results;
	eval{
		$results=$self->{es}->search( $self->{search_hash} );
	};

	return $results;
}

=head search_set

=cut

sub search_set{
	my $self=$_[0];
	my $name=$_[1];

	if ( ! $self->errorblank ) {
        return undef;
    }

	if (! $self->name_validate( $name ) ){
		$self->{error}=3;
		$self->{errorString}='"'.$name.'" is not a valid name';
		$self->warn;
		return undef;
	}

	if( !defined( $name ) ){
		$name='syslog';
	}

	$self->{search}=$name;

	return 1;
}

=head1 AUTHOR

Zane C. Bowers-Hadley, C<< <vvelox at vvelox.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-search-essearcher at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/NoAuth/ReportBug.html?Queue=Search-ESsearcher>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Search::ESsearcher


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<https://rt.cpan.org/NoAuth/Bugs.html?Dist=Search-ESsearcher>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Search-ESsearcher>

=item * CPAN Ratings

L<https://cpanratings.perl.org/d/Search-ESsearcher>

=item * Search CPAN

L<https://metacpan.org/release/Search-ESsearcher>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2019 by Zane C. Bowers-Hadley.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)


=cut

1;								# End of Search::ESsearcher
