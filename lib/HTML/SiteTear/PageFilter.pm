package HTML::SiteTear::PageFilter;

use strict;
use warnings;
#use Data::Dumper;

use HTML::Parser 3.40; #CPAN
use HTML::HeadParser;
use base qw(HTML::Parser);
use File::Basename;
use Encode;


our $VERSION = '1.2.6';
our @htmlSuffix = qw(.html .htm);

=head1 NAME

HTML::SiteTear::PageFilter - change link pathes in HTML files.

=head1 SYMPOSIS

 use HTML::SiteTear::PageFilter;

 # $page must be an instance of L<HTML::SiteTear::Page>.
 $filter = HTML::SiteTear::PageFilter->new($page);
 $fileter->parseFile();

=head1 DESCRIPTION

This module is to change link pathes in HTML files. It's a sub class of L<HTML::Parser>. Internal use only.

=head1 METHODS

=over 2

=item new

Make an instance of this moduel. $parent must be an instance of HTML::SiteTear::Root or HTML::SiteTear::Page. This method is called from $parent.

	$filter = HTML::SiteTear::PageFilter->new($page);

=cut

sub new {
	my ($class, $page) = @_;

	my $parent = $class->SUPER::new();
	my $self = bless $parent,$class;
	$self->{'page'} = $page;

	return $self;
}

=item parseFile

Parse the HTML file given by $page and change link pathes. The output data are retuned thru the method "writeData".

	$filter->parseFile();

=cut

sub parseFile {
	my ($self) = @_;
	
	## read file contents
	my $file = $self->{'page'}->{'sourcePath'};
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
		else {
			$io_layer = ":encoding($encoding)";
			$text = Encode::decode($encoding, $text);
		}
		
	}
	
	## tell the Page object about the IO layer
	$self->{'page'}->setBinmode($io_layer);

	## parse
	$self->SUPER::parse($text);
}

## overriding methods of HTML::Parser

sub declaration { $_[0]->output("<!$_[1]>")     }
sub process     { $_[0]->output($_[2])          }
sub comment     { $_[0]->output("<!--$_[1]-->") }
sub end         { $_[0]->output($_[2])          }
sub text        { $_[0]->output($_[1])          }

sub output{
  my $self =  $_[0];
  $self->{'page'}->writeData($_[1]);
}

sub start {
	my $self = shift @_;
	my $page = $self->{'page'};
	my $optionName;
	
	#treat image files
	if ($_[0] eq 'img'){
		my $imgFile =  $_[1] ->{src};
		my $folderName = $page->resourceFolderName;
		$_[1]->{src} = $page->changePath($imgFile, $folderName, $folderName);
		my $tagOptions = $self->buildTagOptions($_[1],$_[2]);
		$_[3] = "<$_[0]"."$tagOptions>";
	}
	#background images
	elsif ($_[0] eq 'body'){
		if (exists($_[1]->{background})) {
			my $imgFile =  $_[1] ->{background};
			my $folderName = $page->resourceFolderName;
			$_[1]->{background} = $page->changePath($imgFile,$folderName,$folderName);
			my $tagOptions = $self->buildTagOptions($_[1],$_[2]);
			$_[3] = "<$_[0]"."$tagOptions>";
		}
	}
	#linked stylesheet
	elsif ($_[0] eq 'link') {
		#print Dumper(@_);
		my $relation;
		if (defined( $relation = ($_[1] ->{rel}) )){
			$relation = lc $relation;
			if ($relation eq 'stylesheet') {
				my $styleSheetFile =  $_[1] ->{href};
				my $folderName = $page->resourceFolderName;
				$_[1]->{href} = $page->changePath($styleSheetFile, $folderName, 'css');
				my $tagOptions = $self->buildTagOptions($_[1],$_[2]);
				$_[3] = "<$_[0]"."$tagOptions>";
			}
		}
	}
	#frame
	elsif ($_[0] eq 'frame') {
		#print Dumper(@_);
		my $pageSource = $_[1] ->{src};
		my $folderName = $page->pageFolderName;
		$_[1]->{src} = $page->changePath($pageSource,$folderName,'page');
		my $tagOptions = $self->buildTagOptions($_[1],$_[2]);
		$_[3] = "<$_[0]"."$tagOptions>";
	}
	#javascript
	elsif ($_[0] eq 'script'){
		if (exists($_[1]->{src})){
			my $scriptFile =  $_[1] ->{src};
			my $folderName = $page->resourceFolderName;
			$_[1]->{src} = $page->changePath($scriptFile, $folderName, $folderName);
			my $tagOptions = $self->buildTagOptions($_[1],$_[2]);
			$_[3] = "<$_[0]"."$tagOptions>";
		}
	}
	#link
	elsif ($_[0] eq 'a'){
		if (exists($_[1]->{href})){
			my $href =  $_[1]->{href};
			my $kind = 'page';
			if ($href =~ /^(?!http:|https:|ftp:|mailto:|#)(.+)/ ){
				my $folderName = $page->pageFolderName;
				if ($href =~/(.+)#(.*)/){
					$_[1]->{href} = $page->changePath($1, $folderName, $kind)."#$2";
				}
				else{
					my @matchedSuffix = grep {$href =~ /\Q$_\E$/} @htmlSuffix;
					unless (@matchedSuffix) {
						$folderName = $page->resourceFolderName;
						$kind = $folderName;
					}
					$_[1]->{href} = $page->changePath($href, $folderName, $kind);
				}
				my $tagOptions = $self->buildTagOptions($_[1],$_[2]);
				$_[3] = "<$_[0]"."$tagOptions>";
			}
		}
	}
	$self->output($_[3]);
}

sub buildTagOptions{
	my ($self, $optionValueRecord, $optionNameList) = @_;
	my $tagOptions='';
	foreach my $optionName (@{$optionNameList}) {
		my $optionValue = $optionValueRecord ->{$optionName};
		$tagOptions = "$tagOptions $optionName=\"$optionValue\"";
	}
	return $tagOptions;
}

=back

=head1 SEE ALOSO

L<HTML::SiteTear>, L<HTML::SiteTear::Item>,  L<HTML::SiteTear::Root>, L<HTML::SiteTear:Page>

=head1 AUTHOR

Tetsuro KURITA <tkurita@mac.com>

=cut

1;
