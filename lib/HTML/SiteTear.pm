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

=item L<Class::Accessor>

=back

=head1 METHODS

=head2 new

    $p = HTML::SiteTear->new($source_path);

Make an instance of this module. The path to source HTML file "$source_path" is required as an arguemnt.

=cut
sub new {
	my ($class, $source_path) = @_;
	(-e $source_path) or croak "$source_path is not found.\n";
	my $self = bless {'sourcePath' => $source_path}, $class;
	return $self;
}

sub page_filter {
	my ($class, $module) = @_;
	return HTML::SiteTear::Page->page_filter($module);
}

=head2 copy_to

    $p->copy_to($destination_path);

Copy $source_path into $destination_path. All linked file in $source_path will be copied into directories under $destination_path

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
	my $new_source_page = HTML::SiteTear::Page->new($root, $source_path);
	$new_source_page->linkpath( basename($destination_path) );
	$new_source_page->copy_to_linkpath();
	return $new_source_page;
}

=head1 AUTHOR

Tetsuro KURITA <tkurita@mac.com>

=cut

##== obsolute

sub copyTo {
	return copy_to(@_);
}

1;
