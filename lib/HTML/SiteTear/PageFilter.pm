package HTML::SiteTear::PageFilter;

use strict;
use warnings;
use File::Basename;
use Encode;
use Encode::Guess;
#use Data::Dumper;

use HTML::Parser 3.40;
use HTML::HeadParser;
use base qw(HTML::Parser);

our $VERSION = '1.3';
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
	$self->{'page'} = $page;

	return $self;
}

=head2 parse_file

    $filter->parse_file();

Parse the HTML file given by $page and change link pathes. The output data are retuned thru the method "write_data".

=cut
sub parse_file {
	my ($self) = @_;
	
	## read file contents
	my $file = $self->{'page'}->source_path;
	open(my $in, "<", $file) or die "I can't open $file";
	my $text;
	{local $/; $text=<$in>;}
	close($in);
	
	## check file encodeing
	my $p = HTML::HeadParser->new;
	$p->utf8_mode(1);
	$p->parse($text);
	my $contentTypeText = $p->header('content-type');
	
	## decode text depending on its chracter encoding
	my $encoding = '';
	my $io_layer = '';
	if ($contentTypeText =~ /charset\s*=(.+)/) {
		$encoding = $1;
		if ($encoding eq 'utf-8') {
			utf8::decode($text);
			$encoding = 'utf8';
			$io_layer = ':utf8';
		}
	}
	
	unless ($io_layer) {
		unless ($encoding) {
			my $decoder = Encode::Guess->guess($text);
			ref($decoder) or die("Can't guess encoding of source HTML");
			$encoding = $decoder->name;
		}
		$io_layer = ":encoding($encoding)";
		$text = Encode::decode($encoding, $text);
	}
	
	## tell the Page object about the IO layer
	$self->{'page'}->set_binmode($io_layer);

	## parse
	$self->SUPER::parse($text);
}

=head1 SEE ALOSO

L<HTML::SiteTear>, L<HTML::SiteTear::Item>,  L<HTML::SiteTear::Root>, L<HTML::SiteTear:Page>

=head1 AUTHOR

Tetsuro KURITA <tkurita@mac.com>

=cut

##== overriding methods of HTML::Parser

sub declaration { $_[0]->output("<!$_[1]>")     }
sub process     { $_[0]->output($_[2])          }
sub comment     { $_[0]->output("<!--$_[1]-->") }
sub end         { $_[0]->output($_[2])          }
sub text        { $_[0]->output($_[1])          }

sub output{
  my $self =  $_[0];
  $self->{'page'}->write_data($_[1]);
}

sub start {
	my $self = shift @_;
	my $page = $self->{'page'};
	
	#treat image files
	if ($_[0] eq 'img'){
		my $img_file =  $_[1] ->{'src'};
		my $folder_name = $page->resource_folder_name;
		$_[1]->{'src'} = $page->change_path($img_file, $folder_name, $folder_name);
		my $tag_attrs = $self->build_attributes($_[1],$_[2]);
		$_[3] = "<$_[0]"."$tag_attrs>";
	}
	#background images
	elsif ($_[0] eq 'body'){
		if (exists($_[1]->{background})) {
			my $img_file =  $_[1] ->{'background'};
			my $folder_name = $page->resource_folder_name;
			$_[1]->{'background'} = $page->change_path($img_file, $folder_name, $folder_name);
			my $tag_attrs = $self->build_attributes($_[1],$_[2]);
			$_[3] = "<$_[0]"."$tag_attrs>";
		}
	}
	#linked stylesheet
	elsif ($_[0] eq 'link') {
		#print Dumper(@_);
		my $relation;
		if (defined( $relation = ($_[1] ->{rel}) )){
			$relation = lc $relation;
			if ($relation eq 'stylesheet') {
				my $styleSheetFile =  $_[1] ->{'href'};
				my $folder_name = $page->resource_folder_name;
				$_[1]->{'href'} = $page->change_path($styleSheetFile, $folder_name, 'css');
				my $tag_attrs = $self->build_attributes($_[1],$_[2]);
				$_[3] = "<$_[0]"."$tag_attrs>";
			}
		}
	}
	#frame
	elsif ($_[0] eq 'frame') {
		#print Dumper(@_);
		my $page_source = $_[1] ->{'src'};
		my $folder_name = $page->page_folder_name;
		$_[1]->{'src'} = $page->change_path($page_source, $folder_name, 'page');
		my $tag_attrs = $self->build_attributes($_[1],$_[2]);
		$_[3] = "<$_[0]"."$tag_attrs>";
	}
	#javascript
	elsif ($_[0] eq 'script'){
		if (exists($_[1]->{'src'})){
			my $scriptFile = $_[1]->{'src'};
			my $folder_name = $page->resource_folder_name;
			$_[1]->{'src'} = $page->change_path($scriptFile, $folder_name, $folder_name);
			my $tag_attrs = $self->build_attributes($_[1], $_[2]);
			$_[3] = "<$_[0]"."$tag_attrs>";
		}
	}
	#link
	elsif ($_[0] eq 'a'){
		if (exists($_[1]->{'href'})){
			my $href =  $_[1]->{'href'};
			my $kind = 'page';
			if ($href =~ /^(?!http:|https:|ftp:|mailto:|#)(.+)/ ){
				my $folder_name = $page->page_folder_name;
				if ($href =~/(.+)#(.*)/){
					$_[1]->{'href'} = $page->change_path($1, $folder_name, $kind)."#$2";
				}
				else{
					my @matchedSuffix = grep {$href =~ /\Q$_\E$/} @htmlSuffix;
					unless (@matchedSuffix) {
						$folder_name = $page->resource_folder_name;
						$kind = $folder_name;
					}
					$_[1]->{'href'} = $page->change_path($href, $folder_name, $kind);
				}
				my $tag_attrs = $self->build_attributes($_[1],$_[2]);
				$_[3] = "<$_[0]"."$tag_attrs>";
			}
		}
	}
	$self->output($_[3]);
}

sub build_attributes{
	my ($self, $attr_dict, $attr_names) = @_;
	my $tag_attrs='';
	foreach my $attr_name (@{$attr_names}) {
		my $attr_value = $attr_dict ->{$attr_name};
		$tag_attrs = "$tag_attrs $attr_name=\"$attr_value\"";
	}
	return $tag_attrs;
}

1;
