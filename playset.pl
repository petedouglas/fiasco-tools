use strict;
use warnings;
use Data::Dumper;
use Template;

#============================================================
#      DATA
#============================================================

my %playset;
sub init
{
	%playset = 
	(
		title		=> '',
		credits         => { authors => [], editors => [], licence => undef },
		score           => { title => undef, paragraphs => [], tagline => '' },
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
	THE_TITLE               =>   { CODE => \&the_title, NEXT => 'CREDITS' },
	CREDITS                 =>   { CODE => \&credits, NEXT => 'THE_SCORE' },
	THE_SCORE               =>   { CODE => \&the_score, NEXT => 'MOVIE_NIGHT' },
	MOVIE_NIGHT             =>   { CODE => \&movie_night, NEXT => 'RELATIONSHIP_CATEGORY' },
	
	RELATIONSHIP_CATEGORY   =>   { CODE => \&relationships_category, NEXT => 'NEEDS_CATEGORY' },
	RELATIONSHIP_ELEMENTS   =>   { CODE => \&relationships_elements, NEXT => 'RELATIONSHIP_CATEGORY' },
	NEEDS_CATEGORY          =>   { CODE => \&needs_category, NEXT => 'LOCATIONS_CATEGORY' },
	NEEDS_ELEMENTS          =>   { CODE => \&needs_elements, NEXT => 'NEEDS_CATEGORY' },
	LOCATIONS_CATEGORY      =>   { CODE => \&locations_category, NEXT => 'OBJECTS_CATEGORY' },
	LOCATIONS_ELEMENTS      =>   { CODE => \&locations_elements, NEXT => 'LOCATIONS_CATEGORY' },
	OBJECTS_CATEGORY        =>   { CODE => \&objects_category, NEXT => 'NOOP' },
	OBJECTS_ELEMENTS        =>   { CODE => \&objects_elements, NEXT => 'OBJECTS_CATEGORY' },
	
	NOOP                    =>   { CODE => sub { 'NEXT'; }, NEXT => 'NOOP' },
);

sub the_title
{
	shift =~ /(.*\d+)\s+(.*)/; # JM07 LUCKY STRIKE
	$playset{title} = convert_to_header_case($2);
	'NEXT';
}

sub the_tagline
{
	my ($line, $context) = @_;
	if ($playset{score}->{tagline} eq '')
	{
		if ($line =~ /^\.\.\.(.*)/) #...all the damn time
		{
			my $tagline = convert_to_header_case(trim($1));
			if ($tagline ne '')
			{
				$playset{score}->{tagline} = $tagline;
			}
		}
	}
	$context->{CODE}->($line, $context);
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
			push @{$playset{credits}->{authors}}, $author;
		}
	}
	$next;
}

sub the_score
{
	my ($line, $next) = (shift, 'THE_SCORE');
	if ($line =~ /MOVIE NIGHT/i)
	{
		$next = 'MOVIE_NIGHT';
	}
	elsif ($line ne '')
	{
		if (defined($playset{score}->{title}))
		{
			push @{$playset{score}->{paragraphs}}, $line;
		}
		else
		{
			$playset{score}->{title} = convert_to_header_case($line);
		}
	}
	$next;
}

sub convert_to_header_case
{
	my $line = shift;
	my @items = ();
	foreach (split(/\s+/, lc $line))
	{
		push(@items, (ucfirst $_)) unless (trim($_) eq '');
	}
	join(' ', @items);
}

sub movie_night
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
				# remove any pesky trailing period (screws up IMDB search)
				if (substr($title, -1, 1) eq '.')
				{
					chop $title;
				}
				my $code = ''; # TODO use IMDB::Film
				push @{$playset{movie_night}}, { title => $title, code => $code };
			}
		}
	}
	$next;
}

sub relationships_category
{
	my ($line, $context) = @_;
	$context->{next_state_root} = 'RELATIONSHIP';
	$context->{section} = $playset{relationships};
	$context->{regex} = 'RELATIONSHIPS';
	category($line, $context);
}

sub relationships_elements
{
	my ($line, $context) = @_;
	$context->{section} = $playset{relationships};
	$context->{next_state} = 'RELATIONSHIP_ELEMENTS';

	elements($line, $context);
}

sub needs_category
{
	my ($line, $context) = @_;
	$context->{next_state_root} = 'NEEDS';
	$context->{section} = $playset{needs};
	$context->{regex} = 'NEEDS';
	category($line, $context);
}

sub needs_elements
{
	my ($line, $context) = @_;
	$context->{section} = $playset{needs};
	$context->{next_state} = 'NEEDS_ELEMENTS';

	elements($line, $context);
}

sub locations_category
{
	my ($line, $context) = @_;
	$context->{next_state_root} = 'LOCATIONS';
	$context->{section} = $playset{locations};
	$context->{regex} = 'LOCATIONS';
	category($line, $context);
}

sub locations_elements
{
	my ($line, $context) = @_;
	$context->{section} = $playset{locations};
	$context->{next_state} = 'LOCATIONS_ELEMENTS';

	elements($line, $context);
}

sub objects_category
{
	my ($line, $context) = @_;
	$context->{next_state_root} = 'OBJECTS';
	$context->{section} = $playset{objects};
	$context->{regex} = 'OBJECTS';
	category($line, $context);
}

sub objects_elements
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
		$section->[-1]->{elements} = parse_elements($line);
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

sub parse_elements
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
#      MAIN
#============================================================

sub parse
{
	my ($file, $state_name) = (shift, 'THE_TITLE');
	open my $source, q{<}, $file or die $!;
	while (<$source>)
	{
		chomp;
		my $context = {};
		my $state = $states{$state_name};
		$context->{CODE} = $state->{CODE};
		my $next = the_tagline($_, $context);
		$state_name = (exists $state->{$next}) ? $state->{$next} : $next;
	}
	close $source;
}

sub render_wiki
{
	my ($engine) = @_;
	render($engine, 'playset-toc.txt', "output/$playset{title}-toc.txt");
	render($engine, 'playset-elements.txt', "output/$playset{title}-elements.txt");
	render($engine, 'playset-insta-setup.txt', "output/$playset{title}-insta-setup.txt");
}

sub render
{
	my ($engine, $template, $outfile) = @_;
	$engine->process($template, \%playset, $outfile, binmode => ':utf8') || die $engine->error(), "\n";
};

my %formats =
(
	wiki  => \&render_wiki,
	json  => sub { render(shift, 'playset.txt', "output/$playset{title}.json"); },
	rst   => sub { render(shift, 'playset.txt', "output/$playset{title}-rst.txt"); }
);

my @formats = (shift || 'wiki');
if ($formats[0] eq 'all')
{
	pop @formats;
	foreach my $format (keys %formats)	{	push(@formats, $format); }
}

opendir(my $dh, 'sources') || die;
while ( defined (my $file = readdir $dh) )
{
	next if $file =~ /^\.\.?$/;
	init();
	parse("sources/$file");
	foreach my $format (@formats)
	{
		next unless (exists $formats{$format});
		my $engine = Template->new(
		{
			INCLUDE_PATH => "templates/$format",
			RELATIVE     => 1,
		}) || die "$Template::ERROR\n";
		$formats{$format}->($engine);
	}
	print "Processed '$playset{title}' : '$playset{score}->{tagline}'\n";
}
closedir $dh;
