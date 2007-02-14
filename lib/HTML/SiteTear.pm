package HTML::SiteTear;

use strict;
use warnings;
use File::Basename;
use File::Spec;
use Carp;
#use Data::Dumper; #system

use HTML::SiteTear::Root;
use HTML::SiteTear::Page;

our $VERSION = '1.3';

=head1 NAME

HTML::SiteTear - Make a separated copy form a part of a web site

=head1 SYMPOSIS

 use HTML::SiteTear;

 $p = HTML::SiteTear->new("/dev1/website/index.html");
 $p->copyTo("/dev1/website2/ReadMe.html");

=head1 DESCRIPTION

This module is to make a separated copy of a part of web site in local file system. All linked files (HTML file, image file, javascript, cascading style shieet) from a source HTML file will be copied under a new page.

This module is useful to make a destributable copy of a part of a web site.

=head1 REQUIRED MODULES

=over 2

=item L<HTML::Parser>

L<HTML::SiteTear::PageFilter> is a subclass of L<HTML::Parser>.

=back

=head1 METHODS

=over 2

=item new

Make an instance of this module. The path to source HTML file "$source_path" is required as an arguemnt.

	$p = HTML::SiteTear->new($source_path);

=cut
sub new {
	my ($class, $source_path) = @_;
	(-e $source_path) or croak "$source_path is not found.\n";
	my $self = bless {'sourcePath' => $source_path}, $class;
	return $self;
}

sub page_filter {
	my ($class, $module) = @_;
	HTML::SiteTear::Page->page_filter($module);
	return 1;
}

=item copy_to

Copy $source_path into $destination_path. All linked file in $source_path will be copied into directories under $destination_path

	$p->copy_to($destination_path);

=cut
sub copy_to {
	#print "start copyTo in SiteTear.pm\n";
	my ($self, $destination_path) = @_;
	my $source_path = $self->{'sourcePath'};

	if (-e $destination_path){
		if (-d $destination_path) {
		  $destination_path = File::Spec->catfile($destination_path,basename($source_path));
		}
	}

	my $root = HTML::SiteTear::Root->new($source_path, $destination_path);
	my $newSourcePage = HTML::SiteTear::Page->new($root, $source_path);
	$newSourcePage->linkpath( basename($destination_path) );
	$newSourcePage->copy_to_linkpath();
	return $newSourcePage;
}

=back

=head1 AUTHOR

Tetsuro KURITA <tkurita@mac.com>

=cut

##== obsolute

sub copyTo {
	return copy_to(@_);
}

1;
