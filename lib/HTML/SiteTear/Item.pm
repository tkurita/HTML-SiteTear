package HTML::SiteTear::Item;

use strict;
use warnings;

use File::Spec;
use File::Basename;
use File::Copy;
use File::Path; #system
use Cwd;
#use Data::Dumper;

require HTML::SiteTear::Page;
require HTML::SiteTear::CSS;

our $VERSION = '1.2.3';

=pod
=head1 NAME

HTML::SiteTear::Item - treat javascript files, image files and so on.

=head1 SYMPOSIS

 use HTML::SiteTear::Item;

 $item = HTML::SiteTear::Item->new($parent,$sourcePath,$kind);
 $item->setLinkPath($path); # usually called from the mothod "changePath"
                            # of the parent object.
 $item->copyToLinkPath();
 $item->copyLikedFiles();

=head1 DESCRIPTION

This module is to treat general files liked from web pages. It's also a super class of L<HTML::SiteTear::Page>, L<HTML::SiteTear::CSS>. Internal use only.

=head1 METHODS

=over 2

=item new

Make an instance of this moduel. $parent must be an instance of HTML::SiteTear::Root or HTML::SiteTear::Page. This method is called from $parent.

	$item = HTML::SiteTear::Item->new($parent,$sourcePath,$kind);

=cut

sub new {
	my ($class,$parent,$sourcePath,$kind) = @_;
	
	my $self = bless {'parent' => $parent,
					 'sourcePath' => $sourcePath,
					 'kind' => $kind}, $class;
	return $self;
}

=item copyToLinkPath

Copy $sourcePath into new linked path from $parent.

	$item->copyToLinkPath();

=cut
sub copyToLinkPath {
	my ($self) = @_;
	my $sourcePath = $self->sourcePath;

	#unless($self->existsInFileMap($sourcePath)) {
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
		copy($sourcePath, $targetPath);
		$self->add_to_copyied_files($sourcePath);
		$self->setTargetPath(  Cwd::realpath($targetPath) );
	}
}

=item addToLinkedFiles

Add $linkedObj into the internal list. in $linkedObj is an instance of HTML::SiteTear::Item or subclass of HTML::SiteTear::Item for linked files from $sourcePath. 

	$item->addToLinkedFiles($linkedObj)

=cut
sub addToLinkedFiles {
	my ($self, $linkedObj) = @_;
	push (@{$self->{'linkedFiles'}}, $linkedObj);
}

=item changePath

make a new link path from a link path($linkPath) in $sourcePath. $folderName is folder name to store, if $linkPath is not under $sourcePath.

	$newLinkPath = $item->changePath($linkPath,$folderName,$kind)

=cut
sub changePath {
#	print STDERR "start changePath\n";
	my ($self, $linkPath, $folderName, $kind) = @_;
	my $resultPath;
	unless (defined($kind)){
		$kind = $folderName;
	}
#	print "$linkPath\n";
	if (File::Spec->file_name_is_absolute($linkPath)) {
		return $linkPath;
	}
	my $absoluteSourcePath = File::Spec->rel2abs($linkPath,dirname($self->sourcePath) );
	$absoluteSourcePath = Cwd::realpath($absoluteSourcePath);

	## sourceRoot 以下にあるかどうかを判定するために sourceRoot からの相対パスを求める。
#	print "absoluteSourcePath : $absoluteSourcePath\n";
	my $relativeFromRoot = File::Spec->abs2rel($absoluteSourcePath,dirname($self->sourceRoot));
	if ($self->existsInFileMap($absoluteSourcePath) ) {
		$resultPath = $self->relForMappedFile($absoluteSourcePath, dirname($self->targetPath) );
	}
	else {
		my $newLinkedObj;
		if ($kind eq 'page') {
			$newLinkedObj = HTML::SiteTear::Page->new($self, $absoluteSourcePath,$kind);
		}
		elsif ($kind eq 'css') {
			$newLinkedObj = HTML::SiteTear::CSS->new($self, $absoluteSourcePath,$kind);
		}
		else {
		 	$newLinkedObj = HTML::SiteTear::Item->new($self, $absoluteSourcePath,$kind);
		}
	
		my $newLinkPath;
		my $updirStr = File::Spec->updir();
	
		if ($relativeFromRoot =~ /^\Q$updirStr\E/) {
			## sourceRoot 以下に無い場合
			my $fileName = basename($linkPath);
			$newLinkPath = "$folderName/".$fileName;
	
		}
		else { # sourceRoot 以下にある場合は リンクするパスを変更しない。
			$newLinkPath = $linkPath;
		}
	
		$newLinkedObj->setLinkPath( $newLinkPath );
		$self->addToLinkedFiles($newLinkedObj);
		my $targetPath = File::Spec->rel2abs($newLinkPath, dirname($self->targetPath));
		$self->addToFileMap($absoluteSourcePath, $targetPath);
		$resultPath = $newLinkPath;
	}
	#print "end of changePath\n";
	return $resultPath
}

=item copyLinkedFiles

Call method "copyToLinkPath()" of every object added by "addToLikedFiles($linkedObj)".

	$item->copyLinkedFiles();

=cut
sub copyLinkedFiles {
	my ($self) = @_;
	my @pageList = (); 

	foreach my $linkedFile (@{$self->{'linkedFiles'}}) {
		if ($linkedFile->{'kind'} eq 'page') {
			push @pageList, $linkedFile; 
		}
		else {
			$linkedFile->copyToLinkPath();
		}
	}
  
	#HTML file must be copied after other assets.
	unless (@pageList) {return};
	foreach my $linkedFile (@pageList) {
		$linkedFile->copyToLinkPath();
	}
}


####### methods to access root object

=item add_to_copyied_files

Add a file path already copied to the copiedFiles table of the root object of the parent chain.

	$item->add_to_copyied_files($sourcePath);

=cut
sub add_to_copyied_files {
	my ($self, $path) = @_;
	$self->{'parent'}->add_to_copyied_files($path);
}

=item existsInCopiedFiles

Check existance of $sourcePath in the copiedFiles entry.

	$item->existsInCopiedFiles($sourcePath);

=cut
sub existsInCopiedFiles {
	my ($self, $path) = @_;
	return $self->{'parent'}->existsInCopiedFiles($path);
}

=item addToFileMap

Add a relation between $sourcePath and $targetPath to the internal table of the root object of the parent chain.

	$item->addToFileMap($sourcePath, $targetPath);

=cut
sub addToFileMap {
	my ($self,$sourcePath,$targetPath) = @_;
	$self->{'parent'}->addToFileMap($sourcePath, $targetPath);
}

=item existsInFileMap

Check existance of $sourcePath in the internal table the root object of parent chain.

	$bool = $item->existsInFileMap($sourcePath);

=cut
sub existsInFileMap{
	my ($self, $path) = @_;
	return $self->{'parent'}->existsInFileMap($path);
}


sub itemInFileMap {
	my ($self, $path) = @_;
	return $self->{'parent'}->itemInFileMap($path);
}

=item sourceRoot

Get the root source path which is an argument of HTML::SiteTear::CopyTo.

	$sourceRoot = $item->sourceRoot;

=cut
sub sourceRoot{
	my ($self) = @_;
	return $self->{'parent'}->sourceRoot;
}

=item relForMappedFile

Get a relative path of the target path corresponding to $sourcePash based from $base.

	$relativePath = $item->relForMappedFile($sourcePath, $base);

=cut
sub relForMappedFile {
  my ($self, $sourcePath, $base) = @_;
  return $self->{'parent'}->relForMappedFile($sourcePath, $base);
}

####### accessorts

=item sourcePath

Get the source path of this objcet.

	$item->sourcePath;

=cut
sub sourcePath {
	my ($self) = @_;
	return $self->{'sourcePath'};
}


=item setTargetPath

Set the target path which is the copy destination of $sourcePath. This method is called from "copyToLinkPath()".

	$item->pageFolderName

=cut
sub setTargetPath {
  my ($self,$path) = @_;
  $self->{'targetPath'} = $path;
}

sub targetPath {
  my ($self) = @_;
  return $self->{'targetPath'};
}

sub linkPath {
  my ($self) = @_;
  return $self->{'linkPath'};
}

=item setLinkPath

Set the new link path from $parent. Usually called from the method "changePath" of the parent object.

	$item->setLinkPath($path);

=cut
sub setLinkPath {
  my ($self, $path) = @_;
  $self->{'linkPath'} = $path;
}

=item pageFolderName

get name of a folder to store HTML files linked from $sourcePath. If $item does not have the name, $parent give the name.

	$item->pageFolderName

=cut
sub pageFolderName {
  my ($self) = @_;
  if (exists $self->{'pageFolderName'}) {
	return $self->{'pageFolderName'};
  }
  else {
	return $self->{'parent'}->pageFolderName;
  }
}

=item setPageFolderName

set name of a folder to store HTML files linked from $sourcePath.

	$item->setPageFolderName($folderName)

=cut
sub setPageFolderName {
  my ($self, $folderName) = @_;
  $self->{'pageFolderName'} = $folderName;
}

=item resourceFolderName

get name of a folder to store not HTML files(javascript, image, CSS) linked from $sourcePath. If $item does not have the name, $parent gives the name.

	$item->resourceFolderName

=cut
sub resourceFolderName {
  my ($self) = @_;
  if (exists $self->{'resourceFolderName'}) {
	return $self->{'resourceFolderName'};
  }
  else {
	return $self->{'parent'}->resourceFolderName;
  }
}

=item setResourceFolderName

set name of a folder to store not HTML files(javascript, image, CSS) linked from $sourcePath.

	$item->setResourceFolderName($folderName)

=cut
sub setResourceFolderName {
  my ($self, $folderName) = @_;
  $self->{'resourceFolderName'} = $folderName;
}

=back

=head1 SEE ALSO

L<HTML::SiteTear>, L<HTML::SiteTear::Page>, L<HTML::SiteTear::CSS>, L<HTML::SiteTear::Root>

=head1 AUTHOR

Tetsuro KURITA <tkurita@mac.com>

=cut

1;
