package HTML::SiteTear;

use 5.008;
use strict;
use warnings;
use File::Basename;
use File::Spec;
use Carp;
use base qw(Class::Accessor);
HTML::SiteTear->mk_accessors( qw(source_path
                                 site_root_path
                                 site_root_url
                                 target_path) );
#use Data::Dumper; #system

use HTML::SiteTear::Root;
use HTML::SiteTear::Page;

our $VERSION = '1.30';

=head1 NAME

HTML::SiteTear - Make a separated copy of a part of the site

=head1 SYMPOSIS

 use HTML::SiteTear;

 $p = HTML::SiteTear->new("/dev1/website/index.html");
 $p->copy_to("/dev1/website2/ReadMe.html");

=head1 DESCRIPTION

This module is to make a separated copy of a part of web site in local file system. All linked files (HTML file, image file, javascript, cascading style shieet) from a source HTML file will be copied under a new page.

This module is useful to make a destributable copy of a part of a web site.

=head1 METHODS

=head2 new

    $p = HTML::SiteTear->new($source_path);
    $p = HTML::SiteTear->new('source_path' => $source_path,
                             'site_root_path' => $root_path,
                             'site_root_url' => $url);

Make an instance of this module. The path to source HTML file "$source_path" is required as an arguemnt. See L</ABSOLUTE LINK> about 'site_root_path' and 'site_root_url' parameters

=cut

sub new {
	my $class = shift @_;
    my $self;
    if (@_ == 1) {
        $self = bless {'source_path' => shift @_}, $class;
    }
    else {
        my %args = @_;
        $self = $class->SUPER::new(\%args);
    }
    $self->source_path or croak "source_path is not specified.\n";
    (-e $self->source_path) or croak $self->source_path." is not found.\n";

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
    my $source_path = $self->source_path;

    if (-e $destination_path){
        if (-d $destination_path) {
            $destination_path = File::Spec->catfile($destination_path,
                                               basename($source_path));
        }
    }
    $self->target_path($destination_path);
    my $root = HTML::SiteTear::Root->new(%$self);
    my $new_source_page = HTML::SiteTear::Page->new(
										'parent' => $root,
										'source_path' => $source_path);
    $new_source_page->linkpath( basename($destination_path) );
    $new_source_page->copy_to_linkpath;
    return $new_source_page;
}

=head1 ABSOLUTE LINK

The default behavior of HTML::SiteTear follows all of links in HTML files. In some case, there are links should not be followd. For example, if theare is a link to the top page of the site, all of files in the site will be copyied. Such links should be converted to absolute links (ex. "http://www.....").

To convert links should not be followed into absolute links,

=over

=item *

Give parameters of 'site_root_path' and 'site_root_url' to L</new> method.

=over

=item 'site_root_path'

A file path of the root of the site in the local file system.

=item 'site_root_url'

A URL corresponding to 'site_root_path' in WWW.

=back

=item *

To indicate links should be conveted to absolute links, enclose links in HTML files with specail comment tags <!-- begin abs_link --> and <!-- end abs_link -->

=back

=head1 AUTHOR

Tetsuro KURITA <tkurita@mac.com>

=cut

##== obsolute

sub copyTo {
	return copy_to(@_);
}

1;
