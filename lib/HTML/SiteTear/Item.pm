package HTML::SiteTear::Item;

use strict;
use warnings;

use File::Spec;
use File::Basename;
use File::Copy;
use File::Path;
use Cwd;
use Data::Dumper;

use base qw(Class::Accessor);
HTML::SiteTear::Item->mk_accessors(qw(linkpath
									source_path
									target_path
									kind
									parent
                                    source_root));

require HTML::SiteTear::Page;
require HTML::SiteTear::CSS;


our $VERSION = '1.30';

=head1 NAME

HTML::SiteTear::Item - treat javascript files, image files and so on.

=head1 SYMPOSIS

 use HTML::SiteTear::Item;

 $item = HTML::SiteTear::Item->new($parent, $source_path, $kind);
 $item->linkpath($path); # usually called from the mothod "change_path"
                         # of the parent object.
 $item->copy_to_linkpath;
 $item->copy_liked_files;

=head1 DESCRIPTION

This module is to treat general files liked from web pages. It's also a super class of L<HTML::SiteTear::Page>, L<HTML::SiteTear::CSS>. Internal use only.

=head1 METHODS

=head2 new

    $item = HTML::SiteTear::Item->new('parent' => $parent,
                                      'source_path' => $source_path,
                                      'kind' => $kind);

Make an instance of this moduel. $parent must be an instance of HTML::SiteTear::Root or HTML::SiteTear::Page. This method is called from $parent.

=cut

sub new {
	my $class = shift @_;
	my %args = @_;
	my $self = $class->SUPER::new(\%args);
    $self->source_root($self->parent->source_root);
    return $self;
}

=head2 copy_to_linkpath

    $item->copy_to_linkpath;

Copy $source_path into new linked path from $parent.

=cut

sub copy_to_linkpath {
	my ($self) = @_;
	my $source_path = $self->source_path;
	unless ($self->exists_in_copied_files($source_path)) {
		unless (-e $source_path) {
			die("The file \"$source_path\" does not exists.\n");
			return;
		}

		my $target_path;
		unless ($target_path = $self->item_in_filemap($source_path)) {
			my $parent_file = $self->parent->target_path;
			$target_path = File::Spec->rel2abs($self->linkpath, dirname($parent_file));
		}
		
		print "Copying asset...\n";
		print "from : $source_path\n";
		print "to : $target_path\n\n";
		mkpath(dirname($target_path));
		copy($source_path, $target_path);
		$self->add_to_copyied_files($source_path);
		$self->target_path(  Cwd::realpath($target_path) );
	}
}

=head2 add_to_linked_files

    $item->add_to_linked_files($linked_obj)

Add $linked_obj into the internal list. in $linked_obj is an instance of HTML::SiteTear::Item or subclass of HTML::SiteTear::Item for linked files from $source_path. 

=cut

sub add_to_linked_files {
	my ($self, $linked_obj) = @_;
	push (@{$self->{'linkedFiles'}}, $linked_obj);
}

=head2 change_path

    $new_linkpath = $item->change_path($linkpath, $folder_name, $kind)

make a new link path from a link path($linkpath) in $source_path. $folder_name is folder name to store, if $linkpath is not under $source_path.

=cut

sub change_path {
#	print STDERR "start change_path\n";
	my ($self, $linkpath, $folder_name, $kind) = @_;
	my $result_path;
	unless (defined($kind)){
		$kind = $folder_name;
	}

	if (File::Spec->file_name_is_absolute($linkpath)) {
		return $linkpath;
	}
    
	my $abs_src_path = File::Spec->rel2abs($linkpath, dirname($self->source_path) );
    unless (-e $abs_src_path) {
        warn("$abs_src_path is not found.\nThe link to this path is not changed.\n");
        return $linkpath;
    }
    
	$abs_src_path = Cwd::realpath($abs_src_path);

	## sourceRoot 以下にあるかどうかを判定するために sourceRoot からの相対パスを求める。
	
	my $rel_from_root = File::Spec->abs2rel($abs_src_path, dirname($self->source_root_path));
	if ($self->exists_in_filemap($abs_src_path) ) {
		$result_path = $self->rel_for_mappedfile($abs_src_path, dirname($self->target_path) );
	}
	else {
		my $new_linked_obj;
		my %args = ('parent' => $self,
					'source_path' => $abs_src_path,
					'kind' => $kind);
		if ($kind eq 'page') {
			$new_linked_obj = HTML::SiteTear::Page->new(%args);
		}
		elsif ($kind eq 'css') {
			$new_linked_obj = HTML::SiteTear::CSS->new(%args);
		}
		else {
			$new_linked_obj = HTML::SiteTear::Item->new(%args);
		}
	
		my $new_linkpath;
		my $updir_str = File::Spec->updir();
	
		if ($rel_from_root =~ /^\Q$updir_str\E/) {
			## sourceRoot 以下に無い場合
			my $file_name = basename($linkpath);
			$new_linkpath = "$folder_name/".$file_name;
	
		}
		else { # sourceRoot 以下にある場合は リンクするパスを変更しない。
			$new_linkpath = $linkpath;
		}
	
		$new_linked_obj->linkpath( $new_linkpath );
		$self->add_to_linked_files($new_linked_obj);
		my $target_path = File::Spec->rel2abs($new_linkpath, dirname($self->target_path));
		$self->add_to_filemap($abs_src_path, $target_path);
		$result_path = $new_linkpath;
	}
	#print "end of change_path\n";
	return $result_path
}

=head2 copy_linked_files

    $item->copy_linked_files();

Call method "copy_to_linkpath()" of every object added by "addToLikedFiles($linked_obj)".

=cut

sub copy_linked_files {
	my ($self) = @_;
	my @page_list = (); 

	foreach my $linked_file (@{$self->{'linkedFiles'}}) {
		if ($linked_file->kind eq 'page') {
			push @page_list, $linked_file; 
		}
		else {
			$linked_file->copy_to_linkpath();
		}
	}
  
	#HTML file must be copied after other assets.
	unless (@page_list) {return};
	foreach my $linked_file (@page_list) {
		$linked_file->copy_to_linkpath();
	}
}


##== methods to access root object

=head2 add_to_copyied_files

    $item->add_to_copyied_files($source_path);

Add a file path already copied to the copiedFiles table of the root object of the parent chain.

=cut

sub add_to_copyied_files {
	my ($self, $path) = @_;
	$self->parent->add_to_copyied_files($path);
}

=head2 exists_in_copied_files

    $item->exists_in_copied_files($source_path);

Check existance of $source_path in the copiedFiles entry.

=cut

sub exists_in_copied_files {
	my ($self, $path) = @_;
	return $self->parent->exists_in_copied_files($path);
}

=head2 add_to_filemap

    $item->add_to_filemap($source_path, $target_path);

Add a relation between $source_path and $target_path to the internal table of the root object of the parent chain.

=cut

sub add_to_filemap {
	my ($self, $source_path, $target_path) = @_;
	$self->parent->add_to_filemap($source_path, $target_path);
}

=head2 exists_in_filemap

    $bool = $item->exists_in_filemap($source_path);

Check existance of $source_path in the internal table the root object of parent chain.

=cut

sub exists_in_filemap{
	my ($self, $path) = @_;
	#return $self->parent->exists_in_filemap($path);
    return $self->source_root->exists_in_filemap($path);
}


sub item_in_filemap {
	my ($self, $path) = @_;
	#return $self->parent->item_in_filemap($path);
    return $self->source_root->item_in_filemap($path);
}

=head2 source_root_path

    $source_root_path = $item->source_root_path;

Get the root source path which is an argument of HTML::SiteTear::CopyTo.

=cut

sub source_root_path {
	my ($self) = @_;
	return $self->source_root->source_path;
}

=head2 rel_for_mappedfile

    $relativePath = $item->rel_for_mappedfile($source_path, $base);

Get a relative path of the target path corresponding to $sourcePash based from $base.

=cut

sub rel_for_mappedfile {
  my ($self, $source_path, $base) = @_;
  return $self->parent->rel_for_mappedfile($source_path, $base);
}

##== accessors

=head2 source_path

    $item->source_path;
    $item->source_path($path);

Get ang set the source path of this objcet.

=head2 target_path

    $item->taget_path;
    $item->target_path($path);

Get and set the target path which is the copy destination of $source_path. This method is called from "copy_to_linkpath()".

=head2 linkpath

    $item->linkpath;
    $item->linkpath($path);

Get and set the new link path from $parent. Usually called from the method "change_path" of the parent object.

=head2 page_folder_name

    $item->page_folder_name;
    $item->page_folder_name('pages');

Get and set name of a folder to store HTML files linked from $source_path. If $item does not have the name, $parent give the name.

=cut

sub page_folder_name {
	my $self =  shift @_;
	
	if (@_) {
		return $self->{'page_folder_name'} = shift @_;
	}
	
	if (exists $self->{'page_folder_name'}) {
		return $self->{'page_folder_name'};
	}
	else {
		return $self->parent->page_folder_name;
	}
}

=head2 resource_folder_name

    $item->resource_folder_name;
    $item->resource_folder_name('assets');

Get and set name of a folder to store not HTML files(javascript, image, CSS) linked from $source_path. If $item does not have the name, $parent gives the name.

=cut

sub resource_folder_name {
	my $self = shift @_;
	
	if (@_) {
		return $self->{'resource_folder_name'} = shift @_;
	}
	
	if (exists $self->{'resource_folder_name'}) {
		return $self->{'resource_folder_name'};
	}
	else {
		return $self->parent->resource_folder_name;
	}
}

=head1 SEE ALSO

L<HTML::SiteTear>, L<HTML::SiteTear::Page>, L<HTML::SiteTear::CSS>, L<HTML::SiteTear::Root>

=head1 AUTHOR

Tetsuro KURITA <tkurita@mac.com>

=cut

1;
