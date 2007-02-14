package HTML::SiteTear::Root;

use strict;
use warnings;
use Data::Dumper;
use File::Spec;
use File::Basename;
use Cwd;

our $VERSION = '1.2.3';

=head1 NAME

HTML::SiteTear::Root - a root object in a parent chain.

=head1 SYMPOSIS

 use HTML::SiteTear::Root;

 $root = HTML::SiteTear::Root->new();

=head1 DESCRIPTION

An instanece of this module is for a root object in a parent chain and manage a relation tabel of all source pathes and target pathes. Also gives default folder names.

=cut

our $defaultPageFolderName = 'pages';
our $defaultResourceFolderName = 'assets';

=head1 METHODS

=over 2

=item new

make a new instance.

    $root = HTML::SiteTear::Root->new($sourceRoot, $targetPath);

=cut
sub new{
	my ($class, $sourceRoot, $targetPath) =  @_;

	my $self = bless {'sourceRoot'=>$sourceRoot,
					'targetPath'=>$targetPath,
					'fileMapRef'=>{},
					'copiedFiles'=>[]}, $class;
	$self->set_folder_names();
	return $self;
}

sub set_folder_names {
  my ($self) = @_;
  $self->{'resourceFolderName'} = $defaultResourceFolderName;
  $self->{'pageFolderName'} = $defaultPageFolderName;
}

=item add_to_copyied_files

Add a file path already copied to the copiedFiles table of the root object of the parent chain.

	$item->add_to_copyied_files($sourcePath)

=cut
sub add_to_copyied_files {
	my ($self, $path) = @_;
	#$path = Cwd::realpath($path);
	push @{$self->{'copiedFiles'}}, $path;
	return 1;
}

=item existsInCopiedFiles

Check existance of $sourcePath in the copiedFiles entry.

	$item->existsInCopiedFiles($sourcePath)
=cut
sub existsInCopiedFiles {
	my ($self, $path) = @_;
	return grep(/^$path$/, @{$self->{copiedFiles}});
}

=item addToFileMap

add to copyied file information into the internal table "FileMap".

    $root->addToFileMap($sourcePath,$targetPath);

=cut
sub addToFileMap {
  my ($self, $sourcePath, $targetPath) = @_;
  #$targetPath = Cwd::realpath($targetPath);
  $self->{'fileMapRef'}->{$sourcePath} = $targetPath;
  return $targetPath;
}

=item existsInFileMap

check $sourcePath is entry in FileMap

    $root->existsInFileMap($sourcePath);

=cut
sub existsInFileMap {
	my ($self, $path) = @_;
	return exists($self->{fileMapRef}->{$path});
}

sub itemInFileMap {
	my ($self, $path) = @_;
	return $self->{'fileMapRef'}->{$path};
}

=item relForMappedFile

get relative path of copied file of $sourceFile from $base.

    $root->relForMappedFile($sourcePath, $base);

=cut
sub relForMappedFile {
  my ($self, $sourcePath, $base) = @_;
  my $targetPath = ($self->{'fileMapRef'}->{$sourcePath});
  return File::Spec->abs2rel($targetPath,$base);
}

##== accessors
sub sourceRoot{
  my ($self) = @_;
  return $self->{'sourceRoot'};
}

sub resourceFolderName {
  my ($self) = @_;
  return $self->{'resourceFolderName'};
}

sub pageFolderName {
  my ($self) = @_;
  return $self->{'pageFolderName'};
}

sub targetPath {
  my ($self) = @_;
  return $self->{'targetPath'};
}

=back

=head1 SEE ALSO

L<HTML::SiteTear>, L<HTML::SiteTear::Page>, L<HTML::SiteTear::CSS>, L<HTML::SiteTear::Root>

=head1 AUTHOR

Tetsuro KURITA <tkurita@mac.com>

=cut

##== obsolute
1;
