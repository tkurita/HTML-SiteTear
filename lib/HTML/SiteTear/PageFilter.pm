package HTML::SiteTear::PageFilter;

use strict;
use warnings;
use File::Basename;
use Encode;
use Encode::Guess;
use URI;
use Data::Dumper;

use HTML::Parser 3.40;
use HTML::HeadParser;
use base qw(HTML::Parser Class::Accessor);
__PACKAGE__->mk_accessors(qw(has_remote_base
                            page));

use HTML::Copy;

our $VERSION = '1.31';
our @htmlSuffix = qw(.html .htm);

=head1 NAME

HTML::SiteTear::PageFilter - change link pathes in HTML files.

=head1 SYMPOSIS

 use HTML::SiteTear::PageFilter;

 # $page must be an instance of L<HTML::SiteTear::Page>.
 $filter = HTML::SiteTear::PageFilter->new($page);
 $fileter->parse_file();

=head1 DESCRIPTION

This module is to change link pathes in HTML files. It's a sub class of L<HTML::Parser>. Internal use only.

=head1 METHODS

=head2 new

    $filter = HTML::SiteTear::PageFilter->new($page);

Make an instance of this moduel. $parent must be an instance of HTML::SiteTear::Root or HTML::SiteTear::Page. This method is called from $parent.

=cut
sub new {
    my ($class, $page) = @_;
    my $parent = $class->SUPER::new();
    my $self = bless $parent, $class;
    $self->page($page);
    $self->{'allow_abs_link'} = $page->source_root->allow_abs_link;
    $self->{'use_abs_link'} = 0;
    $self->has_remote_base(0);
    return $self;
}

=head2 parse_file

    $filter->parse_file;

Parse the HTML file given by $page and change link pathes. The output data are retuned thru the method "write_data".

=cut

sub parse_file {
    my ($self) = @_;
    my $p = HTML::Copy->new($self->page->source_path);
    $self->page->set_binmode($p->io_layer);
    $self->SUPER::parse($p->source_html);
}

=head1 SEE ALOSO

L<HTML::SiteTear>, L<HTML::SiteTear::Item>,  L<HTML::SiteTear::Root>, L<HTML::SiteTear:Page>

=head1 AUTHOR

Tetsuro KURITA <tkurita@mac.com>

=cut

##== private methods
sub output {
  my ($self, $data) = @_;
  $self->page->write_data($data);
}

#sub build_attributes{
#    my ($self, $attr_dict, $attr_names) = @_;
#    my @attrs = ();
#    foreach my $attr_name (@{$attr_names}) {
#        if ($attr_name eq '/') {
#            push @attrs, '/';
#        } else {
#            my $attr_value = $attr_dict->{$attr_name};
#            push @attrs, "$attr_name=\"$attr_value\"";
#        }
#    }
#    return join(' ', @attrs);
#}

##== overriding methods of HTML::Parser

sub declaration { $_[0]->output("<!$_[1]>")     }
sub process     { $_[0]->output($_[2])          }
sub end         { $_[0]->output($_[2])          }
sub text        { $_[0]->output($_[1])          }

sub comment {
    my ($self, $comment) = @_;

    if ($self->{'allow_abs_link'}) {
        if ($comment =~ /^\s*begin abs_link/) {
            $self->{'use_abs_link'} = 1;
        
        } elsif($comment =~ /^\s*end abs_link/) {
            $self->{'use_abs_link'} = 0;
        }
    }

    $self->output("<!--$comment-->");
}

sub start {
    my ($self, $tag, $attr_dict, $attr_names, $tag_text) = @_; 
    my $page = $self->page;
    my $empty_tag_end = ($tag =~ /\/>$/) ? ' />' : '>';
    
    if ($self->has_remote_base) {
        return $self->output($tag_text);
    }
    
    my $process_link = sub {
        my ($target_attr, $folder_name, $kind) = @_;
        if (my $link = $attr_dict->{$target_attr}) {
            if ($self->{'use_abs_link'}) {
                $attr_dict->{$target_attr} = $page->build_abs_url($link);
            } else {
                unless ($kind) {$kind = $folder_name};
                $attr_dict->{$target_attr} 
                        = $page->change_path($link, $folder_name, $kind);
            }
            return HTML::Copy->build_attributes($attr_dict, $attr_names);
        }
        return ();
    };
    
    #treat image files
    if ($tag eq 'base') {
        my $uri = URI->new($attr_dict->{'href'});
        if (!($uri->scheme) or ($uri->scheme eq 'file')) {
            $page->base_uri($uri->abs($page->base_uri));
            $tag_text  = '';
        } else {
            $self->has_remote_base(1);
        }
        
    } elsif ($tag eq 'img') {
#        my $img_file =  $attr_dict ->{'src'};
#        my $folder_name = $page->resource_folder_name;
#        $attr_dict->{'src'} = $page->change_path($img_file, $folder_name, $folder_name);
#        my $tag_attrs = HTML::Copy->build_attributes($attr_dict, $attr_names);
        if (my $tag_attrs = &$process_link('src', $page->resource_folder_name)) {
            $tag_text = "<$tag $tag_attrs".$empty_tag_end;
        }

    } elsif ($tag eq 'body') { #background images
#        if (exists($attr_dict->{'background'})) {
#            my $img_file =  $attr_dict ->{'background'};
#            my $folder_name = $page->resource_folder_name;
#            $attr_dict->{'background'} = $page->change_path($img_file, $folder_name, $folder_name);
#            my $tag_attrs = HTML::Copy->build_attributes($attr_dict, $attr_names);
#            $tag_text = "<$tag $tag_attrs>";
#        }
        if (my $tag_attrs = &$process_link('background', $page->resource_folder_name)) {
            $tag_text = "<$tag $tag_attrs>";
        }
    }
    #linked stylesheet
    elsif ($tag eq 'link') {
        #print Dumper(@_);
#        my $relation;
#        if (defined( $relation = ($attr_dict ->{'rel'}) )){
#            $relation = lc $relation;
#            if ($relation eq 'stylesheet') {
#                my $styleSheetFile =  $attr_dict ->{'href'};
#                my $folder_name = $page->resource_folder_name;
#                $attr_dict->{'href'} = $page->change_path($styleSheetFile, $folder_name, 'css');
#                my $tag_attrs = HTML::Copy->build_attributes($attr_dict, $attr_names);
#                $tag_text = "<$tag $tag_attrs".$empty_tag_end;
#            }
#        }
        my $folder_name = $page->resource_folder_name;
        my $kind = $folder_name;
        my $relation;
        if (defined( $relation = ($attr_dict ->{'rel'}) )){
            $relation = lc $relation;
            if ($relation eq 'stylesheet') {
                $kind = 'css';
            }
        }
        
        if (my $tag_attrs = &$process_link('href', $folder_name, $kind)) {
            $tag_text = "<$tag $tag_attrs".$empty_tag_end;
        }
    }
    #frame
    elsif ($tag eq 'frame') {
        #print Dumper(@_);
#        my $page_source = $attr_dict ->{'src'};
#        my $folder_name = $page->page_folder_name;
#        $attr_dict->{'src'} = $page->change_path($page_source, $folder_name, 'page');
#        my $tag_attrs = HTML::Copy->build_attributes($attr_dict, $attr_names);
#        $tag_text = "<$tag $tag_attrs".$empty_tag_end;
        if (my $tag_attrs = &$process_link('src', $page->page_folder_name, 'page')) {
            $tag_text = "<$tag $tag_attrs".$empty_tag_end;
        }    
    }
    #javascript
    elsif ($tag eq 'script') {
#        if (exists($attr_dict->{'src'})) {
#            my $scriptFile = $attr_dict->{'src'};
#            my $folder_name = $page->resource_folder_name;
#            $attr_dict->{'src'} = $page->change_path($scriptFile, 
#                                    $folder_name, $folder_name);
#            my $tag_attrs = HTML::Copy->build_attributes($attr_dict, $attr_names);
#            $tag_text = "<$tag $tag_attrs>";
#        }
        if (my $tag_attrs = &$process_link('src', $page->resource_folder_name)) {
            $tag_text = "<$tag $tag_attrs>";
        }
    }
    #link
    elsif ($tag eq 'a') {
        if ( exists($attr_dict->{'href'}) ) {
            my $href =  $attr_dict->{'href'};
            my $kind = 'page';
            my $folder_name = $page->page_folder_name;
            if ($href !~/(.+)#(.*)/) {
                my @matchedSuffix = grep {$href =~ /\Q$_\E$/} @htmlSuffix;
                unless (@matchedSuffix) {
                    $folder_name = $page->resource_folder_name;
                    $kind = $folder_name;
                }
            }
#            if ($href !~ /^(http:|https:|ftp:|mailto:|help:|#)/ ){
#                if ($self->{'use_abs_link'}) {
#                    $attr_dict->{href} = $self->{'page'}->build_abs_url($href);
#                 }
#                 else {
#                    my $folder_name = $page->page_folder_name;
#                    if ($href =~/(.+)#(.*)/){
#                        $attr_dict->{'href'} = $page->change_path($1, $folder_name, $kind)."#$2";
#                    }
#                    else{
#                        my @matchedSuffix = grep {$href =~ /\Q$_\E$/} @htmlSuffix;
#                        unless (@matchedSuffix) {
#                            $folder_name = $page->resource_folder_name;
#                            $kind = $folder_name;
#                        }
#                        $attr_dict->{'href'} = $page->change_path($href, $folder_name, $kind);
#                    }
#                }
#                my $tag_attrs = HTML::Copy->build_attributes($attr_dict, $attr_names);
#                $tag_text = "<$tag $tag_attrs>";
#            }
            if (my $tag_attrs = &$process_link('href', $folder_name, $kind)) {
                $tag_text = "<$tag $tag_attrs>";
            }
        }
    }
    
    $self->output($tag_text);
}

1;
