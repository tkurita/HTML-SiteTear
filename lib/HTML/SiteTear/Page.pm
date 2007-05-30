package HTML::SiteTear::Page;

use strict;
use warnings;
use Cwd;
use File::Spec;
use File::Basename;
use IO::File;
use File::Path;
use Data::Dumper;

use HTML::SiteTear::PageFilter;

require HTML::SiteTear::Item;
our @ISA = qw(HTML::SiteTear::Item);
our $VERSION = '1.30';

=head1 NAME

HTML::SiteTear::Page - treat HTML files

=head1 SYMPOSIS

  use HTML::SiteTear::Page;

  $page = HTML::SiteTear::Page->new($parent, $source_path, $kind);
  $page->linkpath($path); # usually called from the mothod "change_path"
                          # of the parent object.
  $page->copy_to_linkpath();
  $page->copy_linked_files();

=head1 DESCRIPTION

This module is to tread HTML files. It's also a sub class of L<HTML::SiteTear::Item>. Internal use only.

=head1 METHODS

=head2 new

    $page = HTML::SiteTear::Page->new('parent' => $parent,
                                      'source_path' => $source_path);

Make an instance of HTML::SiteTear::Page class.

$parent is an instance of HTML::SiteTear::Page which have an link to $source_path. $source_path is a path to a HTML file. $kind must be 'page'.

=cut

sub new {
    my $class = shift @_;
    my $self = $class->SUPER::new(@_);
    unless ($self->kind ) { $self->kind('page') };
    $self ->{'linkedFiles'} = [];
    return $self;
}

our $_filter_module;

sub page_filter {
    my ($class, $module) = @_;
    $_filter_module = $module;
    return eval "require $_filter_module";
}

=head2 copy_to_linkpath

    $page->copy_to_linkpath;

Copy $source_path into new linked path from $parent.

=cut

sub copy_to_linkpath {
    #print "start copy_to_linkpath\n";
    my ($self) = @_;
    my $parentFile = $self->parent->target_path;

    my $filter;
    if (defined $_filter_module) {
        $filter = $_filter_module->new($self);
    }
    else {
        $filter = HTML::SiteTear::PageFilter->new($self);
    }
    
    my $source_path = $self->source_path;
    unless (-e $source_path) {
        die("The file \"$source_path\" does not exists.\n");
        return 0;
    }

    unless ($self->exists_in_copied_files($source_path)){
        my $target_path;
        if (my $target_uri = $self->item_in_filemap($source_path)) {
            $target_path = $target_uri->file;
        } else {
            $target_path = $self->link_uri->file;
        }
        
        mkpath(dirname($target_path));
        my $io = IO::File->new("> $target_path");
        $target_path = Cwd::realpath($target_path);
        $self->target_path($target_path);
        $self->{'OUT'} = $io;
        print "Copying HTML...\n";
        print "from : $source_path\n";
        print "to : $target_path\n\n";
        ($source_path eq $target_path) and die "source and target is same file.\n";
        $filter->parse_file;
        $io->close;
        $self->add_to_copyied_files($source_path);
        $self->copy_linked_files;
    }
}

sub set_binmode {
    my ($self, $io_layer) = @_;
    binmode($self->{'OUT'}, $io_layer);
}

=head2 write_data

    $page->write_data($data)

Write HTML data to the linked path form the parent object. This method is called from HTML::SiteTear::PageFilder.

=cut

sub write_data {
    my ($self, $data) = @_;
    $self->{'OUT'}->print($data);
}

sub build_abs_url {
    my ($self, $linkpath) = @_;
    my $link_uri = URI->new($linkpath);
    if ($link_uri->scheme) {
        return $linkpath;
    }
    my $abs_uri = $link_uri->abs($self->source_uri);
    my $rel_from_root = $abs_uri->rel($self->source_root->site_root_file_uri);
    my $abs_in_site = $rel_from_root->abs($self->source_root->site_root_uri);
    return $abs_in_site->as_string;
#    my $source_path = $self->source_path;
#    my $abs_path = File::Spec->rel2abs($linkpath, dirname($source_path) );
#    $abs_path = Cwd::realpath($abs_path);
#    my $rel_path = File::Spec->abs2rel($abs_path, $self->source_root->site_root_path);
#    my $abs_url = File::Spec->catfile($self->source_root->site_root_url, $rel_path);
#    return $abs_url;
}

=head1 SEE ALOSO

L<HTML::SiteTear>, L<HTML::SiteTear::Item>, L<HTML::SiteTear::CSS>, L<HTML::SiteTear::Root>, L<HTML::SiteTear::dPageFilter>

=head1 AUTHOR

Tetsuro KURITA <tkurita@mac.com>

=cut

1;
