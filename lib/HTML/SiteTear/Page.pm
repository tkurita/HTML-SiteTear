package HTML::SiteTear::Page;

use strict;
use warnings;

use Data::Dumper;
use Cwd;
use File::Spec;
use File::Basename;
use IO::File;
use File::Path;

use HTML::SiteTear::PageFilter;

require HTML::SiteTear::Item;
our @ISA = qw(HTML::SiteTear::Item);
our $VERSION = '1.2.4';

=head1 NAME

HTML::SiteTear::Page - treat HTML files

=head1 SYMPOSIS

	use HTML::SiteTear::Page;

	$page = HTML::SiteTear::Page->new($parent, $sourcePath, $kind);
	$page->setLinkPath($path); # usually called from the mothod "changePath"
                               # of the parent object.
	$page->copyToLinkPath();
	$page->copyLikedFiles();

=head1 DESCRIPTION

This module is to tread HTML files. It's also a sub class of L<HTML::SiteTear::Item>. Internal use only.

=head1 METHODS

=over 2

=item new

Make an instance of HTML::SiteTear::Page class.

	$page = HTML::SiteTear::Page->new($parent,$sourcePath, $kind)

$parent is an instance of HTML::SiteTear::Page which have an link to $sourcePath. $sourcePath is a path to a HTML file. $kind must be 'page'.

=cut
sub new {
	my ($class, $parent, $sourcePath, $kind) = @_;

	my $self = bless {'parent'=>$parent,
					 'sourcePath'=>$sourcePath,
					 'kind'=>$kind },$class;

	$self ->{'linkedFiles'} = [];
	return $self;
}

our $_filter_module;

sub setPageFilter {
	my ($class, $module) = @_;
	$_filter_module = $module;
	eval "require $_filter_module";
}

=item copyToLinkPath

Copy $sourcePath into new linked path from $parent.

	$page->copyToLinkPath();

=cut
sub copyToLinkPath {
	#print "start copyToLinkPath\n";
	my ($self) = @_;
	my $parentFile = $self->{'parent'}->targetPath;

	my $filter;
	if (defined $_filter_module) {
		$filter = $_filter_module->new($self);
	}
	else {
		$filter = HTML::SiteTear::PageFilter->new($self);
	}
	my $sourcePath = $self->sourcePath();
	unless (-e $sourcePath) {
		die("The file \"$sourcePath\" does not exists.\n");
		return 0;
	}
	
	my $targetPath;
	unless ($self->existsInCopiedFiles($sourcePath)){
		unless ($targetPath = $self->itemInFileMap($sourcePath)) {
			$targetPath = File::Spec->rel2abs($self->linkPath(),dirname($parentFile));
		}
		mkpath(dirname($targetPath));
		my $io = IO::File->new("> $targetPath");
		$targetPath = Cwd::realpath($targetPath);
		$self->setTargetPath($targetPath);
		$self->{'OUT'} = $io;
		print "Copying HTML...\n";
		print "from : $sourcePath\n";
		print "to : $targetPath\n\n";
		$filter->parseFile();
		$io->close;
		$self->add_to_copyied_files($sourcePath);
		$self->copyLinkedFiles();
	}
}

sub setBinmode {
	my ($self, $io_layer) = @_;
	binmode($self->{'OUT'}, $io_layer);
}

=item writeData

write HTML data to the linked path form the parent object. This method is called from HTML::SiteTear::PageFilder.

	$page->writeData($data)

=cut
sub writeData {
	my ($self, $data) = @_;
	$self->{'OUT'}->print($data);
}

=back

=head1 SEE ALOSO

L<HTML::SiteTear>, L<HTML::SiteTear::Item>, L<HTML::SiteTear::CSS>, L<HTML::SiteTear::Root>, L<HTML::SiteTear:PageFilter>

=head1 AUTHOR

Tetsuro KURITA <tkurita@mac.com>

=cut

1;
