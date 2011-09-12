use strict;
use File::Copy;

opendir(my $indh, 'output') || die;
while ( defined (my $file = readdir $indh) )
{
	next if $file =~ /^\.\.?$/;

	my $in_file  = "output/$file";
  
  my $tmp = lc($file);
  $tmp =~ s/,//;
  $tmp =~ s/ //g;
  $tmp =~ s/\.json//;

	my $out_file = "output/$tmp.json";
  #print "'$out_file'\n";
	move($in_file, $out_file) or die "Rename failed: $!";
}
closedir $indh;