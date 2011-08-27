use strict;
use Data::Dumper;
use Template;
use IMDB::Film;

#============================================================
#      DATA
#============================================================

my %playset;
sub init
{
	%playset = 
	(
		title						=> '',
		credits         => {},
		score           => { title => undef, paragraphs => []},
		movie_night     => [],
		relationships   => [],
		needs           => [],
		locations       => [],
		objects         => [],
	);
}

#============================================================
#      STATES
#============================================================

my %states =
(
	THE_TITLE               =>   { CODE => \&theTitle, NEXT => 'CREDITS' },
	CREDITS                 =>   { CODE => \&credits, NEXT => 'THE_SCORE' },
	THE_SCORE               =>   { CODE => \&theScore, NEXT => 'MOVIE_NIGHT' },
	MOVIE_NIGHT             =>   { CODE => \&movieNight, NEXT => 'RELATIONSHIP_CATEGORY' },
	
	RELATIONSHIP_CATEGORY   =>   { CODE => \&relationshipsCategory, NEXT => 'NEEDS_CATEGORY' },
	RELATIONSHIP_ELEMENTS   =>   { CODE => \&relationshipsElements, NEXT => 'RELATIONSHIP_CATEGORY' },
	NEEDS_CATEGORY          =>   { CODE => \&needsCategory, NEXT => 'LOCATIONS_CATEGORY' },
	NEEDS_ELEMENTS          =>   { CODE => \&needsElements, NEXT => 'NEEDS_CATEGORY' },
	LOCATIONS_CATEGORY      =>   { CODE => \&locationsCategory, NEXT => 'OBJECTS_CATEGORY' },
	LOCATIONS_ELEMENTS      =>   { CODE => \&locationsElements, NEXT => 'LOCATIONS_CATEGORY' },
	OBJECTS_CATEGORY        =>   { CODE => \&objectsCategory, NEXT => 'NOOP' },
	OBJECTS_ELEMENTS        =>   { CODE => \&objectsElements, NEXT => 'OBJECTS_CATEGORY' },
	
	NOOP                    =>   { CODE => sub { 'NEXT'; }, NEXT => 'NOOP' },
);

sub theTitle
{
	shift =~ /.*\d+\s+(.*)/; # JM07 LUCKY STRIKE
	$playset{title} = caseForHeader($1);
	'NEXT';
}

sub credits
{
	my ($line, $next) = (shift, 'CREDITS');
	if ($line =~ /THE SCORE/i)
	{
		$next = 'NEXT';
	}
	elsif ($line ne '' and $line !~ /CREDITS/i)
	{
		# Written by Jason Morningstar Edited by Steve Segedy Lucky Strike was Playset of the Month, April 2010.
		$line =~ /Written by (.+)\s+Edited by/;
		my $author = trim($1);
		if($author ne '')
		{
			$playset{credits}->{author} = $author;
		}
	}
	$next;
}

sub theScore
{
	my ($line, $next) = (shift, 'NEXT');
	if ($line !~ /MOVIE NIGHT/i && $line ne '')
	{
		$next = 'THE_SCORE';
		if (defined($playset{score}->{title}))
		{
			push @{$playset{score}->{paragraphs}}, $line;
		}
		else
		{
			$playset{score}->{title} = caseForHeader($line);
		}
	}
	$next;
}

sub caseForHeader
{
	my $line = shift;
	my @items = ();
	foreach (split(/\s+/, lc $line))
	{
		push(@items, (ucfirst $_)) unless (trim($_) eq '');
	}
	join(' ', @items);
}

sub movieNight
{
	my ($line, $next) = (shift, 'NEXT');
	if ($line ne '' && $line !~ /RELATIONSHIPS/i)
	{
		$next = 'MOVIE_NIGHT';
		#A Simple Plan, Fargo, A History of Violence.
		my @movies = split /,/, $line;
		foreach(@movies)
		{
			if ($_ ne '' and $line !~ /MOVIE NIGHT/i)
			{
				my $title = trim($_);
				my $code = '';
				# eval {
					# my $imdb = new IMDB::Film(
						# crit        => $title,

						# cache		    => 1,
						# cache_root	=> './tmp/imdb_cache',
						# cache_exp	  => '7 d',
					# );
					# $code = $imdb->code();
				# };
				push @{$playset{movie_night}}, { title => $title, code => $code };
			}
		}
	}
	$next;
}

sub relationshipsCategory
{
	my ($line, $context) = @_;
	$context->{next_state_root} = 'RELATIONSHIP';
	$context->{section} = $playset{relationships};
	$context->{regex} = 'RELATIONSHIPS';
	category($line, $context);
}

sub relationshipsElements
{
	my ($line, $context) = @_;
	$context->{section} = $playset{relationships};
	$context->{next_state} = 'RELATIONSHIP_ELEMENTS';

	elements($line, $context);
}

sub needsCategory
{
	my ($line, $context) = @_;
	$context->{next_state_root} = 'NEEDS';
	$context->{section} = $playset{needs};
	$context->{regex} = 'NEEDS';
	category($line, $context);
}

sub needsElements
{
	my ($line, $context) = @_;
	$context->{section} = $playset{needs};
	$context->{next_state} = 'NEEDS_ELEMENTS';

	elements($line, $context);
}

sub locationsCategory
{
	my ($line, $context) = @_;
	$context->{next_state_root} = 'LOCATIONS';
	$context->{section} = $playset{locations};
	$context->{regex} = 'LOCATIONS';
	category($line, $context);
}

sub locationsElements
{
	my ($line, $context) = @_;
	$context->{section} = $playset{locations};
	$context->{next_state} = 'LOCATIONS_ELEMENTS';

	elements($line, $context);
}

sub objectsCategory
{
	my ($line, $context) = @_;
	$context->{next_state_root} = 'OBJECTS';
	$context->{section} = $playset{objects};
	$context->{regex} = 'OBJECTS';
	category($line, $context);
}

sub objectsElements
{
	my ($line, $context) = @_;
	$context->{section} = $playset{objects};
	$context->{next_state} = 'OBJECTS_ELEMENTS';

	elements($line, $context);
}

sub category
{
  my ($line, $context) = @_;
	my $next = $context->{next_state_root} . '_CATEGORY';
	my @categories = @{$context->{section}};
	if ($#categories == 5)
	{
		$next = 'NEXT';
	}
	elsif ($line ne '' and $line !~ /$context->{regex}/i)
	{
		$line =~ /.*\d{1}\s*(.*)/; #1 FRIENDSHIP
		my $category_name = ucfirst lc $1;
		if (trim($category_name) ne '')
		{
			push @{$context->{section}}, { name => $category_name };
			$next = $context->{next_state_root} . '_ELEMENTS';
		}
	}
	$next;
}

sub elements
{
  my ($line, $context) = @_;
	my $section = $context->{section};
	my $next = $context->{next_state} || 'NEXT';

	if ($line ne '')
	{
		$section->[$#{$section}]->{elements} = parseElements($line);
		$next = 'NEXT';
	}
	$next;
}

sub trim
{
	my $line = shift;
	$line =~ s/^\s*(.*?)\s*$/$1/;
	$line;
}

sub parseElements
{
	my $line = shift;
	my @elements = ();

	#1 Neighbours 2 Mutual outcasts 3 Best friends 5 Extremely unlikely friends 5 Keepers of a dark secret 6 Church friends
	foreach (split(/[123456|a] (.*) [123456|b] (.*) [123456|c] (.*) [123456|d] (.*) [123456|e] (.*) [123456|f] (.*)/, $line))
	{
		push @elements, trim($_) unless ($_ eq '');
	}
	\@elements;
}

#============================================================
#      PARSING
#============================================================

sub parse
{
	my ($file, $state_name) = (shift, 'THE_TITLE');
	open SOURCE, $file or die $!;
	while (<SOURCE>)
	{
		chomp;
		my $context = {};
		my $state = $states{$state_name};
		my $next = $state->{CODE}->($_, $context);
		$state_name = (exists $state->{$next}) ? $state->{$next} : $next;
	}
	close SOURCE;
}

sub render
{
	my $tt = Template->new(
	{
		INCLUDE_PATH => 'templates/wiki',
		RELATIVE     => 1,
	}) || die "$Template::ERROR\n";

	my $rend = sub
	{
		my ($template, $outfile) = @_;
		$tt->process($template, \%playset, $outfile) || die $tt->error(), "\n";
	};

	&$rend('playset-toc.txt', "output/$playset{title}-toc.txt");
	&$rend('playset-elements.txt', "output/$playset{title}-elements.txt");
}

#============================================================
#      MAIN
#============================================================

opendir(my $dh, 'sources') || die;
while ( defined (my $file = readdir $dh) )
{
	next if $file =~ /^\.\.?$/;
	init();
	parse("sources/$file");
	render();
	print "Processed '$playset{title}'.\n";
}
closedir $dh;