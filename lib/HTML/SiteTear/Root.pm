package HTML::SiteTear::Root;

use strict;
use warnings;
use File::Spec;
use File::Basename;
use Cwd;
#use Data::Dumper;

use base qw(Class::Accessor);
HTML::SiteTear::Root->mk_accessors(qw(source_root
									resource_folder_name
									page_folder_name
									target_path));

our $VERSION = '1.3';

=head1 NAME

HTML::SiteTear::Root - a root object in a parent chain.

=head1 SYMPOSIS

 use HTML::SiteTear::Root;

 $root = HTML::SiteTear::Root->new();

=head1 DESCRIPTION

An instanece of this module is for a root object in a parent chain and manage a relation tabel of all source pathes and target pathes. Also gives default folder names.

=cut

our $defaultpage_folder_name = 'pages';
our $defaultresource_folder_name = 'assets';

=head1 METHODS

=over 2

=item new

make a new instance.

    $root = HTML::SiteTear::Root->new($source_root, $destination_path);

=cut
sub new{
	my ($class, $source_root, $destination_path) =  @_;

	my $self = bless {'source_root'=>$source_root,
					'target_path'=>$destination_path,
					'fileMapRef'=>{},
					'copiedFiles'=>[]}, $class;
	$self->set_default_folder_names();
	return $self;
}

sub set_default_folder_names {
  my ($self) = @_;
  $self->resource_folder_name($defaultresource_folder_name);
  $self->page_folder_name($defaultpage_folder_name);
}

=item add_to_copyied_files

Add a file path already copied to the copiedFiles table of the root object of the parent chain.

	$item->add_to_copyied_files($source_path)

=cut
sub add_to_copyied_files {
	my ($self, $path) = @_;
	#$path = Cwd::realpath($path);
	push @{$self->{'copiedFiles'}}, $path;
	return 1;
}

=item exists_in_copied_files

Check existance of $source_path in the copiedFiles entry.

	$item->exists_in_copied_files($source_path)
=cut
sub exists_in_copied_files {
	my ($self, $path) = @_;
	return grep(/^$path$/, @{$self->{'copiedFiles'}});
}

=item add_to_filemap

add to copyied file information into the internal table "filemap".

    $root->add_to_filemap($source_path, $destination_path);

=cut
sub add_to_filemap {
  my ($self, $source_path, $destination_path) = @_;
  #$destination_path = Cwd::realpath($destination_path);
  $self->{'fileMapRef'}->{$source_path} = $destination_path;
  return $destination_path;
}

=item exists_in_filemap

check $source_path is entry in FileMap

    $root->exists_in_filemap($source_path);

=cut
sub exists_in_filemap {
	my ($self, $path) = @_;
	return exists($self->{fileMapRef}->{$path});
}

sub item_in_filemap {
	my ($self, $path) = @_;
	return $self->{'fileMapRef'}->{$path};
}

=item rel_for_mappedfile

get relative path of copied file of $sourceFile from $base.

    $root->rel_for_mappedfile($source_path, $base);

=cut
sub rel_for_mappedfile {
  my ($self, $source_path, $base) = @_;
  my $destination_path = ($self->{'fileMapRef'}->{$source_path});
  return File::Spec->abs2rel($destination_path, $base);
}


=back

=head1 SEE ALSO

L<HTML::SiteTear>, L<HTML::SiteTear::Page>, L<HTML::SiteTear::CSS>, L<HTML::SiteTear::Root>

=head1 AUTHOR

Tetsuro KURITA <tkurita@mac.com>

=cut

##== obsolute
1;
