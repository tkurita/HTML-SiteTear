package HTML::SiteTear::CSS;

#use lib '/Users/tkurita/Factories/PerlDev/ProjectsX/SiteTear/Perl_Module/lib';
use strict;
use warnings;

use File::Spec;
use File::Basename;
use File::Path;

require HTML::SiteTear::Item;
our @ISA = qw(HTML::SiteTear::Item);

our $VERSION = '1.2.3';

=head1 NAME

HTML::SiteTear::CSS - treat cascading style sheet files.

=head1 SYMPOSIS

 use HTML::SiteTear::CSS;

 $item = HTML::SiteTear::CSS->new($parent,$sourcePath,$kind);
 $item->setLinkPath($path); # usually called from the mothod "changePath"
                            # of the parent object.
 $item->copyToLinkPath();
 $item->copyLikedFiles();

=head1 DESCRIPTION

This module is to treat cascading style sheet files liked from web pages. It's also a sub class of L<HTML::SiteTear::Item>. Internal use only.

=head1 METHODS

=over 2

=item new

Make an instance of this moduel. The parent object "$parent" must be an instance of HTML::SiteTear::Page. This method is called from $parent.

	$css = HTML::SiteTear::CSS->new($parent, $sourcePath, $kind);

=cut
sub new {
  my $class = shift @_;
  my $self = $class->SUPER::new(@_);
  $self = bless $self,$class;
  $self->{'linkedFiles'} = [];
  return $self;
}

=item cssCopy

Copy a cascading style sheet file "$sourcePath" into $targetPath dealing with internal links. This method is called form the method "copyToLinkPath".

	$css->cssCopy($sourcePath, $targetPath);

=cut
sub cssCopy {
  my ($self, $targetPath) = @_;
  my $sourcePath = $self->sourcePath;
  open(CSSIN, "< $sourcePath");
  open(CSSOUT, "> $targetPath");
  while (my $theLine = <CSSIN>) {
	if ($theLine =~ /url\(([^()]+)\)/) {
	  my $newLink = $self->changePath($1, $self->resourceFolderName,'css');
	  $theLine =~ s/url\([^()]+\)/url\($newLink\)/;
	}
	print CSSOUT $theLine;
  }
  close(CSSIN);
  close(CSSOUT);
}

=item copyToLinkPath

Copy $sourcePath into new linked path from $parent.

	$item->copyToLinkPath();

=cut
sub copyToLinkPath {
	my ($self) = @_;
	my $sourcePath = $self->sourcePath;
	unless ($self->existsInCopiedFiles($sourcePath)) {
		unless (-e $sourcePath) {
			die("The file \"$sourcePath\" does not exists.\n");
			return;
		}
		
		my $targetPath;
		unless ($targetPath = $self->itemInFileMap($sourcePath)) {
			my $parentFile = $self->{'parent'}->targetPath;
			$targetPath = File::Spec->rel2abs($self->linkPath, dirname($parentFile));
		}

		print "Copying asset...\n";
		print "from : $sourcePath\n";
		print "to : $targetPath\n\n";
		mkpath(dirname($targetPath));
		$self->setTargetPath($targetPath); #temporary set for cssCopy
		$self->cssCopy($targetPath);
		$self->setTargetPath(Cwd::realpath($targetPath));
		$self->add_to_copyied_files($sourcePath);
		$self->copyLinkedFiles();
	}
}

=back

=head1 SEE ALSO

L<HTML::SiteTear>, L<HTML::SiteTear::Page>, L<HTML::SiteTear::CSS>, L<HTML::SiteTear::Root>

=head1 AUTHOR

Tetsuro KURITA <tkurita@mac.com>

=cut

1;
