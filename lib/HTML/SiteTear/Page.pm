package HTML::SiteTear::Page;

use strict;
use warnings;
use Cwd;
use File::Spec;
use File::Basename;
use IO::File;
use File::Path;
#use Data::Dumper;

use HTML::SiteTear::PageFilter;

require HTML::SiteTear::Item;
our @ISA = qw(HTML::SiteTear::Item);
our $VERSION = '1.2.4';

=head1 NAME

HTML::SiteTear::Page - treat HTML files

=head1 SYMPOSIS

	use HTML::SiteTear::Page;

	$page = HTML::SiteTear::Page->new($parent, $source_path, $kind);
	$page->linkpath($path); # usually called from the mothod "changePath"
                               # of the parent object.
	$page->copy_to_linkpath();
	$page->copy_linked_files();

=head1 DESCRIPTION

This module is to tread HTML files. It's also a sub class of L<HTML::SiteTear::Item>. Internal use only.

=head1 METHODS

=over 2

=item new

Make an instance of HTML::SiteTear::Page class.

	$page = HTML::SiteTear::Page->new($parent,$source_path, $kind)

$parent is an instance of HTML::SiteTear::Page which have an link to $source_path. $source_path is a path to a HTML file. $kind must be 'page'.

=cut
sub new {
	my ($class, $parent, $source_path, $kind) = @_;

	my $self = bless {'parent'=>$parent,
					 'source_path'=>$source_path,
					 'kind'=>$kind },$class;

	$self ->{'linkedFiles'} = [];
	return $self;
}

our $_filter_module;

sub page_filter {
	my ($class, $module) = @_;
	$_filter_module = $module;
	return eval "require $_filter_module";
}

=item copy_to_linkpath

Copy $source_path into new linked path from $parent.

	$page->copy_to_linkpath();

=cut
sub copy_to_linkpath {
	#print "start copy_to_linkpath\n";
	my ($self) = @_;
	my $parentFile = $self->{'parent'}->target_path;

	my $filter;
	if (defined $_filter_module) {
		$filter = $_filter_module->new($self);
	}
	else {
		$filter = HTML::SiteTear::PageFilter->new($self);
	}
	my $source_path = $self->source_path();
	unless (-e $source_path) {
		die("The file \"$source_path\" does not exists.\n");
		return 0;
	}
	
	my $target_path;
	unless ($self->exists_in_copied_files($source_path)){
		unless ($target_path = $self->item_in_filemap($source_path)) {
			$target_path = File::Spec->rel2abs($self->linkpath, dirname($parentFile));
		}
		mkpath(dirname($target_path));
		my $io = IO::File->new("> $target_path");
		$target_path = Cwd::realpath($target_path);
		$self->target_path($target_path);
		$self->{'OUT'} = $io;
		print "Copying HTML...\n";
		print "from : $source_path\n";
		print "to : $target_path\n\n";
		$filter->parse_file();
		$io->close;
		$self->add_to_copyied_files($source_path);
		$self->copy_linked_files;
	}
}

sub set_binmode {
	my ($self, $io_layer) = @_;
	binmode($self->{'OUT'}, $io_layer);
}

=item write_data

write HTML data to the linked path form the parent object. This method is called from HTML::SiteTear::PageFilder.

	$page->write_data($data)

=cut
sub write_data {
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
