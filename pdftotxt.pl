#
# Convert all PDFs in a directory to plain text.
#
# Calls out to the Xpdf pdftotext executable: http://foolabs.com/xpdf/home.html

use strict;

my $pdf_src_dir = $ARGV[0] || 'playsets';

opendir(my $dh, $pdf_src_dir) || die;
while ( defined (my $file = readdir $dh) )
{
	next if $file =~ /^\.\.?$/;
	my $pdf = "$pdf_src_dir/$file" ;
	`pdftotext "$pdf"`;
}
closedir $dh;